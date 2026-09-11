#!/bin/sh
# arm-runtime-proof.sh -- execute the shipped ARM artifacts and prove they work.
#
# Background: the v54 release text originally said this build host "has no qemu"
# and that the arm-linux / aarch64-linux binaries had "never been executed".
# That was an unchecked assumption.  qemu-user-static is a stock Ubuntu package;
# installing it takes one command and both ARM compilers then run fine.  This
# script is that measurement, made repeatable so nobody has to take it on faith.
#
#   sudo apt-get install -y qemu-user-static
#   sudo apt-get install -y binutils-arm-linux-gnueabihf binutils-aarch64-linux-gnu
#   sh dist/arm-runtime-proof.sh [workdir]
#
# Exit 0 = every stage passed.  Run it from a vibepascal checkout.
#
# LIMIT, stated up front: qemu-user is an emulator.  It runs the real shipped
# bytes and real ARM instruction encodings, so codegen and RTL defects DO
# surface -- but it is not a Raspberry Pi.  Silicon-specific behaviour (caches,
# real kernel/libc versions, timing) is outside what this can show.  Do not
# quote a pass here as a hardware sign-off.
set -e

VP=$(cd "$(dirname "$0")/.." && pwd)
W=${1:-${TMPDIR:-/tmp}/vp-arm-proof}
fail=0

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING: $1"; fail=1; }; }
need qemu-arm-static
need qemu-aarch64-static
need arm-linux-gnueabihf-as
need aarch64-linux-gnu-as
[ $fail -eq 0 ] || { echo "PROOF ABORTED -- install the tools above."; exit 2; }

rm -rf "$W"; mkdir -p "$W/arm" "$W/a64"

# Pick the HIGHEST-numbered vN bin tarball for a target, the same rule Lars's
# build-release.sh get_latest_vp_bin_tarball uses.  Hardcoding v54 here meant
# that shipping v55 for a target left this proof silently measuring the OLD
# bytes -- a proof that cannot follow the release is not a proof.
latest_bin() { # $1 = dist subdir / target token
    find "$VP/dist/$1" -maxdepth 1 -type f -name "vibepascal-v*-$1-bin.tar.gz" 2>/dev/null |
    while IFS= read -r t; do
        b=$(basename "$t"); v=${b#vibepascal-v}; v=${v%%-*}
        case "$v" in ''|*[!0-9]*) continue ;; esac
        printf '%08d %s\n' "$v" "$t"
    done | sort -n | tail -1 | cut -d' ' -f2-
}

# Same rule for the UNITS tarball, and for the same reason: this line used to name
# vibepascal-v54-arm-linux-units.tar.gz literally, so when arm-linux gained a FULL
# RTL+packages set (cy1123) the proof would have gone on measuring the RTL-only one
# forever.  A "-full" set WINS over a plain one at the same version -- it is a proven
# strict superset, so preferring it can never lose coverage -- and above that it is
# highest-vN-first, matching latest_bin.
latest_units() { # $1 = dist subdir / target token
    for suffix in units-full units; do
        found=$(find "$VP/dist/$1" -maxdepth 1 -type f \
                     -name "vibepascal-v*-$1-$suffix.tar.gz" 2>/dev/null |
        while IFS= read -r t; do
            b=$(basename "$t"); v=${b#vibepascal-v}; v=${v%%-*}
            case "$v" in ''|*[!0-9]*) continue ;; esac
            printf '%08d %s\n' "$v" "$t"
        done | sort -n | tail -1 | cut -d' ' -f2-)
        [ -n "$found" ] && { echo "$found"; return 0; }
    done
    return 1
}

# -FU/-FE OUTPUT-DIR AUTOCREATE (compiler fix 4d10b26fe7, first shipped as v55).
# Deliberately VERSION-AWARE, so this stays a real assertion on every target
# rather than a check that has to be edited as each one catches up:
#   >= v55  the compiler must CREATE the missing directory and the binary runs
#   <  v55  the compiler must REFUSE, non-zero, with no internal error
# An unconditional "must pass" would start failing every target still on v54;
# an unconditional "must fail" would rot the moment one ships.  Both directions
# are asserted, so neither answer can be reached by accident.
check_outputdir() { # $1 qemu  $2 compiler  $3 flags  $4 sysroot  $5 version
  q=$1; cc=$2; fl=$3; sr=$4; ver=$5
  d=od_probe; rm -rf $d; mkdir $d; cd $d
  printf 'program odp;\nbegin\n  writeln(42);\nend.\n' > odp.pas
  $q "$cc" $fl -FUmissing/deep -FEout odp.pas >odp.clog 2>&1; rc=$?
  if [ "$ver" -ge 55 ] 2>/dev/null; then
    [ $rc -eq 0 ] && [ -x ./out/odp ] || { echo "  FAIL v$ver should create -FU/-FE dirs (rc=$rc)"; tail -3 odp.clog; cd ..; return 1; }
    [ "$($q -L "$sr" ./out/odp 2>&1)" = 42 ] || { echo "  FAIL -FU/-FE binary did not run"; cd ..; return 1; }
    echo "  ok  v$ver CREATES missing -FU/-FE dirs and the binary runs"
  else
    if [ $rc -eq 0 ]; then echo "  FAIL v$ver predates the fix but accepted a missing -FU dir"; cd ..; return 1; fi
    grep -qi 'internal error' odp.clog && { echo "  FAIL v$ver ICEd on a missing -FU dir"; cd ..; return 1; }
    echo "  ok  v$ver predates the fix and correctly refuses (rc=$rc)"
  fi
  cd ..
}

tarball_version() { b=$(basename "$1"); b=${b#vibepascal-v}; echo "${b%%-*}"; }

# ---------------------------------------------------------------- arm-linux --
echo "== arm-linux (32-bit ARM, ARMHF) =="
cd "$W/arm"
ARMTB=$(latest_bin arm-linux); echo "  using $(basename "$ARMTB")"; tar xzf "$ARMTB"
ARMUNITS=$(latest_units arm-linux) || { echo "  FAIL no arm-linux units tarball published"; exit 1; }
echo "  using $(basename "$ARMUNITS")"; tar xzf "$ARMUNITS"

# The md5 the tarball declares about itself must match the bytes we just got.
want=$(sed -n 's/.*bin\/ppcarm  *md5 \([0-9a-f]*\).*/\1/p' VERSION.txt | head -1)
got=$(md5sum bin/ppcarm | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "  FAIL md5 $got != declared $want"; exit 1; }
echo "  ok  ppcarm md5 matches its own VERSION.txt"

v=$(qemu-arm-static ./bin/ppcarm -iV)
p=$(qemu-arm-static ./bin/ppcarm -iTP)
echo "  ok  ppcarm EXECUTES on ARM: version $v, target cpu $p"

ARMC="-Fu$W/arm/units/arm-linux -Fl/usr/arm-linux-gnueabihf/lib -XParm-linux-gnueabihf-"
run_arm() {  # <src> <extra opts> ; compiles on ARM, then runs the ARM result
  s=$1; shift
  cp "$s" .
  b=$(basename "$s" .pp); b=$(basename "$b" .pas)
  qemu-arm-static ./bin/ppcarm $ARMC "$@" "$(basename "$s")" >"$b.clog" 2>&1 \
    || { echo "  FAIL $b did not compile"; tail -3 "$b.clog"; return 1; }
  qemu-arm-static -L /usr/arm-linux-gnueabihf "./$b" >"$b.out" 2>&1 \
    || { echo "  FAIL $b compiled but exited nonzero"; cat "$b.out"; return 1; }
  echo "  ok  $b ran on ARM: $(tail -1 "$b.out")"
}
run_arm "$VP/tests/test/tinlinevarnativeint1.pp" -Munleashed   # expect NativeInt=4
run_arm "$VP/tests/test/tinlinevarstrinfer1.pp"  -Munleashed
run_arm "$VP/tests/test/tblockscopefinal1.pp"

# The two { %FAIL } tests must be REJECTED -- accepting them is the real bug.
for t in tinlinevar2 tinlinevar3; do
  cp "$VP/tests/test/$t.pp" .
  if qemu-arm-static ./bin/ppcarm $ARMC "$t.pp" >"$t.clog" 2>&1; then
    echo "  FAIL $t is a %FAIL test but ARM ACCEPTED it"; exit 1
  fi
  echo "  ok  $t correctly rejected (block scoping enforced on ARM)"
done

check_outputdir qemu-arm-static "$W/arm/bin/ppcarm" "$ARMC" /usr/arm-linux-gnueabihf "$(tarball_version "$ARMTB")" || exit 1
cd "$W/arm"

# --------------------------------------------------------- aarch64-linux --
echo "== aarch64-linux =="
cd "$W/a64"
A64TB=$(latest_bin aarch64-linux); echo "  using $(basename "$A64TB")"; tar xzf "$A64TB"
want=$(sed -n 's/.*bin\/ppca64  *md5 \([0-9a-f]*\).*/\1/p' VERSION.txt | head -1)
got=$(md5sum bin/ppca64 | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "  FAIL md5 $got != declared $want"; exit 1; }
echo "  ok  ppca64 md5 matches its own VERSION.txt"
echo "  ok  ppca64 EXECUTES on aarch64: version $(qemu-aarch64-static ./bin/ppca64 -iV)"

A64C="-Fu$VP/rtl/units/aarch64-linux -Fl/usr/aarch64-linux-gnu/lib -XPaarch64-linux-gnu-"
cp "$VP/tests/test/tinlinevarnativeint1.pp" .
qemu-aarch64-static ./bin/ppca64 $A64C -Munleashed tinlinevarnativeint1.pp >c.log 2>&1 \
  || { echo "  FAIL aarch64 compile"; tail -3 c.log; exit 1; }
qemu-aarch64-static -L /usr/aarch64-linux-gnu ./tinlinevarnativeint1 >r.out 2>&1 \
  || { echo "  FAIL aarch64 run"; cat r.out; exit 1; }
echo "  ok  tinlinevarnativeint1 ran on aarch64: $(head -1 r.out)"   # expect NativeInt=8

cp "$VP/tests/test/tblockscopefinal1.pp" .
qemu-aarch64-static ./bin/ppca64 $A64C tblockscopefinal1.pp >b.log 2>&1 \
  || { echo "  FAIL aarch64 block-scope matrix compile"; tail -3 b.log; exit 1; }
qemu-aarch64-static -L /usr/aarch64-linux-gnu ./tblockscopefinal1 >b.out 2>&1 \
  || { echo "  FAIL aarch64 block-scope matrix run"; cat b.out; exit 1; }
echo "  ok  tblockscopefinal1 ran on aarch64: $(tail -1 b.out)"

check_outputdir qemu-aarch64-static "$W/a64/bin/ppca64" "$A64C" /usr/aarch64-linux-gnu "$(tarball_version "$A64TB")" || exit 1
cd "$W/a64"

echo
echo "ARM RUNTIME PROOF: PASS  (emulated -- see the LIMIT note at the top of this file)"
