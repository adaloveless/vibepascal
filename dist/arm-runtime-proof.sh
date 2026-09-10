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

# ---------------------------------------------------------------- arm-linux --
echo "== arm-linux (32-bit ARM, ARMHF) =="
cd "$W/arm"
tar xzf "$VP"/dist/arm-linux/vibepascal-v54-*-arm-linux-bin.tar.gz
tar xzf "$VP"/dist/arm-linux/vibepascal-v54-arm-linux-units.tar.gz

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

# --------------------------------------------------------- aarch64-linux --
echo "== aarch64-linux =="
cd "$W/a64"
tar xzf "$VP"/dist/aarch64-linux/vibepascal-v54-*-aarch64-linux-bin.tar.gz
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

echo
echo "ARM RUNTIME PROOF: PASS  (emulated -- see the LIMIT note at the top of this file)"
