#!/bin/bash
# linux-bin-layout.sh -- put the Linux compilers in a directory with no .pas in it.
#
# cy1115, reported by Lars (LazarusDeveloper) with the cost already paid on his
# side: three cycles, and `lazbuild --build-ide` unable to build the Lazarus IDE
# for x86_64-linux/gtk2 at all.
#
# THIS IS NOT A COMPILER BUG AND THE FIX IS NOT IN THE COMPILER.  FPC appends
# the running binary's own directory to the unit search path -- documented,
# long-standing, and the right thing for a compiler building its own RTL.  The
# defect is purely WHERE WE LEAVE THE BINARY: `make -C compiler` writes ppcx64
# into compiler/, which also holds 207 .pas files, so every consumer who invokes
# $VP_DIR/compiler/ppcx64 by that path silently gets 207 of OUR units prepended
# to their search path.  Nothing in the output says they are there.
#
# Measured collision surface against a Lazarus tree: 3 of our 207 names collide
# with its 4017 -- `compiler`, `macho`, `tokens`.  One of them fires.  Lazarus
# has components/fpdebug/macho.pas (2101 lines); we have compiler/macho.pas
# (2106 lines).  LazDebuggerFp gets fpdebug's OUTPUT dir on its unit path but
# not fpdebug's SOURCE dir, so during that package's compile the only macho.pas
# FPC can see is OURS.  It recompiles unit `macho` into LazDebuggerFp's output
# dir with a different CRC (62128 B vs 62168 B), which invalidates
# fpimgreadermachofile.ppu, and the IDE build dies with
#
#     Fatal: (10022) Can't find unit FpImgReaderMachoFile used by FpImgReaderMacho
#
# which names a LAZARUS unit and reads like a Lazarus problem from end to end.
# That is why this is worth a gate rather than a note: the symptom points at the
# wrong repo, so the next person also spends cycles in the wrong place.
#
# THE SHIPPED TARBALLS WERE NEVER AFFECTED and still are not -- every Linux
# dist tarball (linux64, aarch64-linux, arm-linux, the two -cross ones) has
# shipped bin/ppc* with ZERO .pas members since v54, exactly like win64.  The
# exposure is the GIT CHECKOUT used as $VP_DIR, where the binary sits in
# compiler/ next to its own sources.  So this script closes the gap for the
# checkout; it does not change what we publish.
#
#   usage: linux-bin-layout.sh [--check] [<tree>]
#          <tree> defaults to the repo this script lives in.
#          default mode INSTALLS (copies, then verifies); --check only verifies
#          and touches nothing, so a consumer or a release gate can call it.
#
# exit 0 = <tree>/bin holds the consumer compilers, has no .pas in it, and a
#          compile driven through it does NOT put compiler/ on the unit path;
# exit 1 = the tree is bad (bin/ missing, a binary stale, or the hazard live);
# exit 2 = the harness could not run -- says NOTHING about the tree.
#
# A SYMLINK DOES NOT WORK AND THIS IS MEASURED, NOT ASSUMED.  FPC resolves the
# executable to its target before computing exepath, so bin/ppcx64 -> ../
# compiler/ppcx64 prints "Using unit path: .../vibepascal/compiler/" and
# reproduces the hazard in full (20 hits, identical to running the original).
# A real copy gives 0.  Hard links are no better in the other direction: a
# rebuild writes a NEW inode, so the link silently stops tracking.  Copies it
# is -- which is exactly why this script exists instead of a one-line mkdir:
# copies go STALE, so re-running this after every build is part of the deal.
#
# bin/ is in .gitignore (upstream FPC's, e381889ee3, twice: `bin` and `bin/`),
# so its contents CANNOT be committed and this script is the durable half.

set -u

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TREE=""
MODE=install

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check; shift;;
    -h|--help) sed -n '2,60p' "$0"; exit 0;;
    -*) echo "FATAL: unknown option $1"; exit 2;;
    *) TREE="$1"; shift;;
  esac
done
[ -n "$TREE" ] || TREE=$(dirname "$SELF_DIR")

# The consumer-facing set: host-executable entry points a caller would invoke by
# path.  Everything else in compiler/ppc* is deliberately NOT copied, and the
# skips are PRINTED below rather than dropped silently:
#   ppc ppc1 ppc2 ppc3   bootstrap stages; sub-makes reach them as ../compiler/ppc
#   ppca64 ppcarm        NATIVE ARM binaries -- they cannot execute on this host
#   ppcwpo1              whole-program-optimisation stage, not an entry point
#   *.v55 *.v56 *.native *.darwin*   preserved A/B baselines and cross-OS builds
#   ppcx64.exe           PE32+, belongs to the win64 dist
WANTED="ppcx64 ppcross386 ppcrossa64 ppcrossarm"
# ppcrossaarch64 is a symlink to ppcrossa64 in compiler/; Lars invokes it by that
# name, and since FPC resolves symlinks it lands in compiler/ just like the rest.
# Carry the alias into bin/ as a REAL COPY of the resolved target.
ALIASES="ppcrossaarch64:ppcrossa64"

total=0; ok=0; bad=0
SCRATCH=""
summary_done=0

emit_summary() {
  summary_done=1
  echo "linux-bin-layout $(basename "$TREE"): $1/$2 binaries clean, $3 problem(s)"
}

on_exit() {
  local rc=$?
  [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
  # Summary of last resort.  BuildMaster's release gate reconciles every
  # ALL-CAPS problem header against the "N problem(s)" count in this line and
  # refuses to assert a PASS over headers it cannot score -- so the line is owed
  # on EVERY exit path, including the ones that die before the sweep.  It lives
  # in the trap for that reason, and the trap owns the scratch cleanup too
  # because two EXIT traps would silently replace one another.
  [ "$summary_done" -eq 0 ] && emit_summary "$ok" "$total" "$((bad > 0 ? bad : 1))"
  exit $rc
}
on_signal() { echo "ABORTED: killed by signal $1"; bad=$((bad + 1)); exit 2; }
trap on_exit EXIT
trap 'on_signal 1'  HUP
trap 'on_signal 2'  INT
trap 'on_signal 15' TERM

[ -d "$TREE/compiler" ] || { echo "FATAL: no compiler/ under $TREE"; bad=1; emit_summary 0 0 1; exit 2; }

SCRATCH=$(mktemp -d 2>/dev/null) || { echo "FATAL: mktemp failed"; bad=1; emit_summary 0 0 1; exit 2; }

SRCDIR="$TREE/compiler"
BINDIR="$TREE/bin"

# ---------------------------------------------------------------- install ----
if [ "$MODE" = install ]; then
  mkdir -p "$BINDIR" || { echo "FATAL: cannot create $BINDIR"; bad=1; emit_summary 0 0 1; exit 2; }
fi

copy_one() {  # $1 = name in bin/, $2 = name in compiler/
  local dst="$BINDIR/$1" src="$SRCDIR/$2"
  total=$((total + 1))
  if [ ! -f "$src" ]; then
    echo "SKIP: $2 not built in compiler/ -- not an error, nothing to install as $1"
    total=$((total - 1))
    return
  fi
  local shsrc shdst
  shsrc=$(md5sum "$src" | cut -d' ' -f1)
  shdst=""
  [ -f "$dst" ] && shdst=$(md5sum "$dst" | cut -d' ' -f1)

  if [ "$shsrc" = "$shdst" ]; then
    echo "ok    $1  $shsrc"
    ok=$((ok + 1))
    return
  fi
  if [ "$MODE" = check ]; then
    if [ -z "$shdst" ]; then echo "MISSING: bin/$1 does not exist (compiler/$2 is $shsrc)"
    else echo "STALE: bin/$1 is $shdst but compiler/$2 is $shsrc -- re-run without --check"; fi
    bad=$((bad + 1))
    return
  fi
  # cp -f to a temp name then mv: never leave a half-written compiler in place.
  if cp -f "$src" "$dst.tmp$$" && chmod 755 "$dst.tmp$$" && mv -f "$dst.tmp$$" "$dst"; then
    echo "installed $1  $shsrc"
    ok=$((ok + 1))
  else
    rm -f "$dst.tmp$$"
    echo "FATAL: could not install $1 into $BINDIR"
    bad=$((bad + 1))
  fi
}

echo "=== $MODE: $SRCDIR -> $BINDIR ==="
for n in $WANTED; do copy_one "$n" "$n"; done
for a in $ALIASES; do copy_one "${a%%:*}" "${a##*:}"; done

if [ ! -d "$BINDIR" ]; then
  echo "MISSING: $BINDIR does not exist"
  bad=$((bad + 1)); emit_summary "$ok" "$total" "$bad"; exit 1
fi

# ------------------------------------------------- the point of the whole ----
# bin/ must contain no compilable source.  This is the property Lars asked for,
# stated directly rather than inferred from the copy list.
nsrc=$(find "$BINDIR" -maxdepth 1 -type f \( -name '*.pas' -o -name '*.pp' -o -name '*.inc' \) | wc -l)
if [ "$nsrc" -ne 0 ]; then
  echo "SOURCE-FILE-IN-BIN: $nsrc compilable source file(s) in $BINDIR -- that is the whole hazard, moved"
  find "$BINDIR" -maxdepth 1 -type f \( -name '*.pas' -o -name '*.pp' -o -name '*.inc' \) | head -5
  bad=$((bad + 1))
else
  echo "ok    $BINDIR holds 0 .pas/.pp/.inc"
fi

# --------------------------------------------------- discriminator + control --
# Compile a trivial program and ask the compiler ITSELF which directories it put
# on the unit path.  -n is mandatory: without it ~/.fpc.cfg contributes the
# INSTALLED unit dirs and the trace stops answering the question asked.
#
# The NEGATIVE CONTROL runs first and must FAIL (i.e. must show compiler/ on the
# path).  If the control comes back clean the discriminator is dead -- perhaps
# -vut changed, perhaps the tree moved -- and a clean result from bin/ would
# then prove nothing at all.  That is exit 2, not exit 0.
probe() {  # $1 = compiler to run; echoes the hit count for the compiler source dir
  ( cd "$SCRATCH" && "$1" -n -vut t.pp 2>&1 | grep -c -F "$SRCDIR/" )
}
printf 'begin\nend.\n' > "$SCRATCH/t.pp"

if [ -x "$SRCDIR/ppcx64" ]; then
  ctl=$(probe "$SRCDIR/ppcx64")
  if [ "${ctl:-0}" -eq 0 ]; then
    echo "FATAL: negative control is dead -- compiler/ppcx64 run from compiler/ did NOT"
    echo "       show $SRCDIR/ on its unit path, so this check cannot fail and its"
    echo "       PASS would be meaningless.  Not scoring the tree."
    bad=$((bad + 1)); emit_summary "$ok" "$total" "$bad"; exit 2
  fi
  echo "ok    negative control live: compiler/ppcx64 puts compiler/ on the path ($ctl line(s))"

  if [ -x "$BINDIR/ppcx64" ]; then
    hit=$(probe "$BINDIR/ppcx64")
    if [ "${hit:-1}" -eq 0 ]; then
      echo "ok    bin/ppcx64 does NOT put $SRCDIR/ on the unit path"
    else
      echo "HAZARD: bin/ppcx64 still puts $SRCDIR/ on the unit path ($hit line(s)) --"
      echo "        a symlink or hard link will do exactly this; bin/ppcx64 must be a real copy"
      bad=$((bad + 1))
    fi
  else
    echo "MISSING: $BINDIR/ppcx64 is not executable, cannot run the discriminator"
    bad=$((bad + 1))
  fi
else
  echo "SKIP: compiler/ppcx64 absent -- no host compiler, discriminator not run"
fi

emit_summary "$ok" "$total" "$bad"
[ "$bad" -eq 0 ] || exit 1
exit 0
