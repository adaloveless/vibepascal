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
# Exit: 0 = every package loaded clean; 1 = at least one package failed or recompiled.
#
# Measured 2026-09-10 (cy1109): x86_64-linux 146/146 clean, x86_64-darwin 118/118 clean.
# Swept all six targets 2026-09-10 by BuildMaster (cy1110), and re-measured here after -s:
#   x86_64-linux 146/146 rc=0   arm-linux 142/142 rc=0   x86_64-darwin 118/118 rc=0
#   aarch64-darwin 115/115 rc=0   aarch64-linux 143/143 rc=0 (0/143 before -s)
#   x86_64-win64 108/109 rc=1 -- one problem, NOT a defect and NOT fixable by rebuilding:
#   packages/librsvg/units/x86_64-win64/ ships rsvg.ppu, which uses glib2, and glib2 (which
#   lives in the gtk2 package) has no win64 build in this tree. gtk2's fpmake.pp DOES
#   declare Win32/Win64 (P.OSes:=AllUnixOSes+[Win32,Win64]-[darwin,...]), so nothing is
#   mis-declared -- the win64 roll simply never produced the gtk2/glib2 units, only the
#   buildgtk2 driver. Leave the package sources alone and allowlist librsvg. r25's shipped
#   win64 asset was cut from this same unit set, so this is the state of every win64
#   release so far, not a regression. gtk2 itself is no longer reported at all: see the
#   build-driver skip below (it now prints SKIPPED and leaves the denominator at 109).
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
PPC="${2:-$VPDIR/compiler/ppcx64}"
RTL="$VPDIR/rtl/units/$TARGET"

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
            # It removes a real FALSE ALARM: packages/gtk2/units/x86_64-win64/ contains
            # buildgtk2.ppu and NOTHING ELSE (gtk2 has 13 units on linux, none on win64),
            # so the driver was the sole "unit" of the package and reported
            # "Can't find unit gtk2 used by buildgtk2" -- which reads as a broken unit set
            # when the truth is the package is simply not built for that target.
            case "$b" in BuildUnit_*|buildunit_*|build*|Build*|BUILD*) continue;; esac
            echo "$b"
          done | tr '\n' ',' | sed 's/,$//')
  if [ -z "$units" ]; then
    # never let a package vanish from the denominator silently -- if a dir held only
    # drivers, say so, so a future real unit named build* cannot hide by shrinking $total
    drivers=$(ls "$d"/*.ppu 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')
    [ -n "$drivers" ] && echo "SKIPPED $pkg -- no consumable units for $TARGET (build driver only: $drivers)"
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
