#!/bin/sh
# unit-set-loadcheck.sh -- prove a compiled unit set is USABLE by a given compiler,
# not merely that its timestamps look new.
#
# WHY THIS EXISTS: an mtime sweep ("every ppu here is older than system.ppu") answers a
# question nobody asks. What breaks a release roll is a unit whose recorded dependency
# CRCs no longer match the RTL it is about to be compiled against -- FPC then either
# silently RECOMPILES it or dies with "Can't find unit X used by Y". mtime and ABI
# validity are independent: a unit set 16 days behind the RTL can load perfectly, and a
# unit set built this minute can be broken. This script measures the thing that matters.
#
# It loads every unit of every package in one program per package with -Cn (no link, so
# missing .so files cannot produce a false failure), and directs ALL unit output to a
# scratch dir with -FU so a silent recompile (a) cannot touch the tree and (b) is
# DETECTED -- any ppu appearing in the scratch dir means that package was not loadable
# as-is.
#
# HONEST LIMIT: only UNIT dirs go on -Fu, so FPC can never find a .pas to fall back to.
# A genuinely stale unit therefore surfaces as FAILED ("Can't find unit X used by Y"),
# which is exactly the shape a release roll hits. The RECOMPILED branch below is
# defensive and has NOT been observed firing -- do not read it as a tested path.
#
# SECOND HONEST LIMIT: this proves a unit set LOADS, i.e. its recorded dependency CRCs
# still match. It does NOT prove the objects inside those ppus assemble, link or run --
# -Cn skips the link and -s skips the assembler on purpose (see the -s comment below).
# A wrong-arch or truncated .o would pass here. Runtime proof is a separate artifact
# (dist/arm-runtime-proof.sh, dist/win64-runtime-proof.sh).
#
# NEGATIVE CONTROL (a harness that cannot fail proves nothing) lives at
# ~/src/vibepascal-slices/linux-pkg-freshness/negative-control-tree/ -- see its README.
# It must report 123/146 clean, 23 problems, exit 1.
#
# Usage: unit-set-loadcheck.sh <target> [compiler] [vpdir]
#   e.g. unit-set-loadcheck.sh x86_64-linux
#   [compiler] defaults FROM THE TARGET'S CPU (ppcx64 / ppcrossa64 / ppcrossarm /
#   ppcross386) -- pass it only to test a specific binary. Whatever is used, it must first
#   build an empty program for <target> or the run aborts with exit 2 (see PREFLIGHT).
# Exit: 0 = every package loaded clean; 1 = at least one package failed or recompiled.
#
# Measured 2026-09-10 (cy1109): x86_64-linux 146/146 clean, x86_64-darwin 118/118 clean.
# Swept all six targets 2026-09-10 by BuildMaster (cy1110), and re-measured here after -s:
#   x86_64-linux 146/146 rc=0   arm-linux 142/142 rc=0   x86_64-darwin 118/118 rc=0
#   aarch64-darwin 115/115 rc=0   aarch64-linux 143/143 rc=0 (0/143 before -s)
#   x86_64-win64 108/109 rc=1 -- SUPERSEDED, and the diagnosis above it was WRONG. Kept
#   verbatim as the lesson: this file used to say the win64 librsvg miss was "NOT a defect
#   and NOT fixable by rebuilding" because "glib2 ... has no win64 build in this tree" and
#   "the win64 roll simply never produced the gtk2/glib2 units, only the buildgtk2 driver",
#   and it told the reader to "Leave the package sources alone and allowlist librsvg".
#   Every clause of that is a correct MEASUREMENT with a false conclusion bolted on.
#
#   MEASURED cy1112, x86_64-win64 is now 111/111 rc=0. What was actually wrong: a FAILED
#   win64 gtk2 build on 2026-08-18 15:42 left buildgtk2.ppu behind as an ORPHAN. fpmake
#   treats the driver as the package's only explicit target (gtk2's other 12 units are all
#   AddImplicitUnit), so with that one ppu present it reported "[100%] Compiled package
#   gtk2" and built NOTHING, on every run, forever. Deleting the orphan and re-running the
#   unchanged make line built all 12 units in seconds. librsvg's rsvg.ppu then loaded, and
#   gstreamer -- which needs glib2 and nothing else -- built for win64 too.
#   NOTHING in the package sources needed changing, and nothing needed allowlisting.
#
#   THE GENERAL SHAPE, which is why the skip branch below now FLAGS instead of absolving:
#   "the package is simply not built for that target" is a description, never a cause. A
#   unit dir that EXISTS and holds ONLY a build driver means a build ran there and produced
#   only the driver -- so the next build will skip the package on the strength of the
#   wreckage the last one left. Swept all 921 packages/*/units/<target> dirs in this tree
#   cy1112: gtk2/x86_64-win64 was the ONLY one, so flagging costs nothing today and catches
#   the next one.
#
# ALL SIX TARGETS re-measured cy1112 (2026-09-11) after the orphan was cleared, each run
# with NO compiler argument so the new CPU-aware default is what is being tested:
#   x86_64-linux   147/147 rc=0   (was 146/146 -- gstreamer joins the denominator)
#   aarch64-linux  144/144 rc=0   (was 143/143)
#   arm-linux      143/143 rc=0   (was 142/142)
#   x86_64-darwin  119/119 rc=0   (was 118/118)
#   aarch64-darwin 116/116 rc=0   (was 115/115)
#   x86_64-win64   111/111 rc=0   (was 108/109 rc=1 -- +gtk2 +gstreamer, librsvg fixed)
# gstreamer accounts for the +1 everywhere: an UNCOMMITTED edit had sat in packages/
# fpmake_add.inc since 2026-08-18 16:04 commenting out add_gstreamer with the reason
# "gst needs glib2 (absent from VP tree)". glib2 is not absent and is not a package -- it
# is a unit of gtk2, built for every target -- so a one-target problem was being worked
# around on all seven, in a change no clone had and any checkout would have silently
# reverted. Reverted to the committed state; gst.pp builds everywhere it is asked to.
#
# WHY arm-linux PASSED BEFORE THIS FIX AND aarch64-linux DID NOT (measured cy1110, from
# the artifacts, not reasoned): the arm-linux target writes its object with FPC's INTERNAL
# assembler -- one probe compile leaves t.o and no t.s, and its ppas.sh holds only a link
# step, no as(1) line. aarch64-linux uses external GAS: it leaves t.s and its ppas.sh
# calls /usr/bin/as -march=armv8-a. So arm never needed binutils and aarch64 always did.
# The host as(1) rejects BOTH argument sets (it does not know -mfloat-abi either); arm
# simply never asks it.

set -u
TARGET="${1:-x86_64-linux}"
VPDIR="${3:-/home/jason/src/vibepascal}"
RTL="$VPDIR/rtl/units/$TARGET"

# DEFAULT THE COMPILER FROM THE TARGET'S CPU, never to ppcx64 (cy1112). One FPC binary
# serves every OS of one CPU but no other CPU at all, so `unit-set-loadcheck.sh
# aarch64-linux` with the x86_64 compiler makes EVERY package fail identically with
# "Unsupported target architecture -Paarch64, invoke the fpc compiler driver instead" --
# 144/144 problems, from a tree that is perfectly fine. Measured today, by me, knowing
# the rule and walking into it anyway, which is why this is now code and not a comment.
# The cross binaries (host-executable, foreign codegen) are the right default: ppca64 and
# ppcarm are NATIVE binaries for those CPUs and cannot run on this host at all.
case "${TARGET%%-*}" in
  x86_64)  DEFPPC="$VPDIR/compiler/ppcx64"     ;;
  aarch64) DEFPPC="$VPDIR/compiler/ppcrossa64" ;;
  arm)     DEFPPC="$VPDIR/compiler/ppcrossarm" ;;
  i386)    DEFPPC="$VPDIR/compiler/ppcross386" ;;
  *)       DEFPPC="$VPDIR/compiler/ppcx64"     ;;
esac
PPC="${2:-$DEFPPC}"

[ -x "$PPC" ] || { echo "FATAL: no compiler at $PPC"; exit 2; }
[ -d "$RTL" ] || { echo "FATAL: no RTL units at $RTL"; exit 2; }

# a ppu is refused outright by a compiler aimed at another target, so derive -T/-P from
# the target triple rather than relying on the compiler's native default
TCPU="${TARGET%%-*}"
TOS="${TARGET#*-}"
TARGS="-T$TOS -P$TCPU"

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/loadcheck-$TARGET-XXXXXX") || exit 2
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/out" "$SCRATCH/work"

# PREFLIGHT: prove the harness can compile ANYTHING for this target before judging 144
# package unit sets with it. BuildMaster's rule (cy1110) is that an ALL-FAIL result means
# an unusable harness rather than a rotten tree -- a unit set does not rot all at once, a
# toolchain does. That rule saved 143 healthy dirs when it was a human reading output;
# here it is enforced before the sweep runs, so a wrong compiler costs one compile and a
# clear sentence instead of a screenful of identical failures that read like a disaster.
printf 'program preflight;\nbegin\nend.\n' > "$SCRATCH/work/preflight.pp"
if ! "$PPC" $TARGS -n -s -Cn -Fu"$RTL" -FU"$SCRATCH/out" "$SCRATCH/work/preflight.pp" \
     > "$SCRATCH/work/preflight.log" 2>&1; then
  echo "FATAL: $PPC cannot build an empty program for $TARGET -- the harness is unusable,"
  echo "       which says nothing about the unit set. First error:"
  grep -E 'Fatal|Error' "$SCRATCH/work/preflight.log" | head -3 | sed 's/^/       /'
  echo "       pass a compiler that targets ${TARGET%%-*} as argument 2, e.g. $DEFPPC"
  exit 2
fi
rm -f "$SCRATCH/out"/*

# every package unit dir goes on the search path, so cross-package uses resolve.
# NOTE: the package under test must be searched FIRST. Several packages ship their own
# copy of a widely-used unit name (packages/ide embeds a whole compiler: aasmbase,
# aasmcnst, ...), and a global path in directory order lets a foreign copy shadow the
# package's own -- which surfaces as a bogus "Can't find unit X used by Y" for a unit
# that is sitting right there. Measured cy1109: packages/ide FAILED under a flat path
# and loads clean, 609 units, zero recompiles, when its own dir leads.
FURest=""
for d in "$VPDIR"/packages/*/units/"$TARGET"; do
  [ -d "$d" ] && FURest="$FURest -Fu$d"
done

total=0; ok=0; bad=0
echo "loadcheck $TARGET"
echo "  compiler : $PPC ($("$PPC" -iV 2>/dev/null))"
echo "  rtl      : $RTL (system.ppu $(date -r "$RTL/system.ppu" +%Y-%m-%d_%H:%M 2>/dev/null))"
echo

for d in "$VPDIR"/packages/*/units/"$TARGET"; do
  [ -d "$d" ] || continue
  pkg=$(basename "$(dirname "$(dirname "$d")")")
  units=$(ls "$d"/*.ppu 2>/dev/null | while read -r f; do
            b=$(basename "$f" .ppu)
            # fpmake BUILD DRIVERS are not consumable units. Two naming conventions ship
            # here: BuildUnit_<pkg> (fpmake-generated) and build<something> (hand-written
            # "Dummy unit to compile everything in one go" aggregators -- measured cy1110,
            # 37 files / 7 distinct names across the tree: buildfv, buildgtk2, buildim,
            # buildpasjpeg, buildcollations, buildwinutilsbase, buildjwa, and every one of
            # them has a source whose interface is nothing but a uses clause over its own
            # package's units). Skipping them removes ZERO coverage, because a driver only
            # ever uses units from its own dir and this probe lists those units directly.
            # Skipping the driver stops it reporting "Can't find unit gtk2 used by
            # buildgtk2", which is a real false alarm ABOUT THE DRIVER. But a dir left
            # holding ONLY drivers is not thereby innocent -- see the DRIVER-ONLY branch
            # below, which is where cy1110 quietly excused the orphan that was blocking
            # every win64 gtk2 build. Skip the driver; do NOT skip the dir.
            case "$b" in BuildUnit_*|buildunit_*|build*|Build*|BUILD*) continue;; esac
            echo "$b"
          done | tr '\n' ',' | sed 's/,$//')
  if [ -z "$units" ]; then
    # DRIVER-ONLY IS A DEFECT SIGNATURE, NOT A BENIGN "not built here" (cy1112).
    # A dir that exists and holds only an fpmake build driver means a build ran in it and
    # produced nothing else; because the driver is usually the package's only EXPLICIT
    # fpmake target, its mere presence then makes every later fpmake run report
    # "[100%] Compiled package <pkg>" while doing no work. That is how gtk2 stayed unbuilt
    # for win64 from 2026-08-18 to cy1112 and took librsvg and gstreamer down with it.
    # The remedy is always the same and costs seconds: delete the orphan driver ppu and
    # re-run the SAME make line. A package that is genuinely not built for a target has no
    # unit dir at all and is filtered out by the [ -d ] test above, so this branch cannot
    # fire for that case. Counted in BOTH $total and $bad: the package stays in the
    # denominator (it was never vanishing-safe to drop it) and the gate exits non-zero.
    drivers=$(ls "$d"/*.ppu 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')
    if [ -n "$drivers" ]; then
      echo "DRIVER-ONLY $pkg -- $TARGET dir holds build drivers and no units: $drivers"
      echo "             a stale driver ppu makes fpmake report the package built; delete it and rebuild"
      total=$((total+1)); bad=$((bad+1))
    fi
    continue
  fi
  total=$((total+1))
  src="$SCRATCH/work/lcheck.pp"
  printf 'program lcheck;\nuses %s;\nbegin\nend.\n' "$units" > "$src"
  rm -rf "$SCRATCH/out"; mkdir -p "$SCRATCH/out"
  log="$SCRATCH/work/$pkg.log"
  # -n is MANDATORY: ~/.fpc.cfg on this host adds every dir of an INSTALLED
  # /home/jason/fpc/lib/fpc/3.3.1/units/<target>/ unit set to the search path, so without
  # it the sweep silently resolves units from OUTSIDE the tree and cannot fail. Measured
  # cy1109: the first two negative-control runs both PASSED for exactly this reason.
  #
  # -s IS EQUALLY MANDATORY, and it is what makes a CROSS target measurable at all. -Cn
  # already suppresses the link, but the compiler still ASSEMBLES, and with -n there is no
  # cfg to carry -XP<cpu>-<os>- -- so a cross compiler whose target uses external GAS
  # shells out to the HOST as(1) and the probe dies before any unit set is judged
  # ("Fatal error: invalid -march= option: `armv8-a'"), which reads as 143 broken packages
  # when the tree is fine. Reported by BuildMaster cy1110, who swept all six targets
  # before hanging a release gate on this script. -s ("do not call assembler and linker")
  # removes the dependency on binutils entirely: unit loading and dependency-CRC checking
  # both happen at COMPILE time, long before codegen, so nothing this script measures
  # needs an assembler to exist. That is strictly better than the obvious alternative of
  # appending a cfg for the -XP prefix, which would put the installed unit dirs back on
  # the search path and defeat -n above -- and it needs no cross binutils installed.
  # -s still writes the ppu of any unit it recompiles, so the RECOMPILED branch below
  # keeps working (verified cy1110); it also drops .s files in the out dir, which is why
  # that branch counts *.ppu only.
  if "$PPC" -n -s $TARGS -Cn -Fu"$d" -Fu"$RTL" $FURest -FU"$SCRATCH/out" -FE"$SCRATCH/work" "$src" > "$log" 2>&1; then
    # a PROGRAM emits no ppu of its own, so ANY ppu here is a unit FPC had to rebuild
    recomp=$(find "$SCRATCH/out" -maxdepth 1 -name '*.ppu' 2>/dev/null | wc -l)
    if [ "$recomp" -gt 0 ]; then
      bad=$((bad+1))
      echo "RECOMPILED $pkg -- $recomp unit(s) rebuilt on load:"
      ls "$SCRATCH/out"/*.ppu 2>/dev/null | xargs -r -n1 basename | sed 's/^/    /' | head -10
    else
      ok=$((ok+1))
    fi
  else
    bad=$((bad+1))
    echo "FAILED $pkg:"
    grep -E 'Fatal|Error' "$log" | head -4 | sed 's/^/    /'
  fi
done

echo
echo "loadcheck $TARGET: $ok/$total packages load clean, $bad problem(s)"
[ "$bad" -eq 0 ] || exit 1
