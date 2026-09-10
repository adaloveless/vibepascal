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
# NEGATIVE CONTROL (a harness that cannot fail proves nothing) lives at
# ~/src/vibepascal-slices/linux-pkg-freshness/negative-control-tree/ -- see its README.
# It must report 123/146 clean, 23 problems, exit 1.
#
# Usage: unit-set-loadcheck.sh <target> [compiler] [vpdir]
#   e.g. unit-set-loadcheck.sh x86_64-linux
# Exit: 0 = every package loaded clean; 1 = at least one package failed or recompiled.
#
# Measured 2026-09-10 (cy1109): x86_64-linux 146/146 clean, x86_64-darwin 118/118 clean.

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
            # BuildUnit_* are fpmake build drivers, not consumable units
            case "$b" in BuildUnit_*|buildunit_*) continue;; esac
            echo "$b"
          done | tr '\n' ',' | sed 's/,$//')
  [ -n "$units" ] || continue
  total=$((total+1))
  src="$SCRATCH/work/lcheck.pp"
  printf 'program lcheck;\nuses %s;\nbegin\nend.\n' "$units" > "$src"
  rm -rf "$SCRATCH/out"; mkdir -p "$SCRATCH/out"
  log="$SCRATCH/work/$pkg.log"
  # -n is MANDATORY: ~/.fpc.cfg on this host adds every dir of an INSTALLED
  # /home/jason/fpc/lib/fpc/3.3.1/units/<target>/ unit set to the search path, so without
  # it the sweep silently resolves units from OUTSIDE the tree and cannot fail. Measured
  # cy1109: the first two negative-control runs both PASSED for exactly this reason.
  if "$PPC" -n $TARGS -Cn -Fu"$d" -Fu"$RTL" $FURest -FU"$SCRATCH/out" -FE"$SCRATCH/work" "$src" > "$log" 2>&1; then
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
