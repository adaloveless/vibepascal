#!/bin/sh
# win64-runtime-proof.sh -- execute the SHIPPED Win64 artifacts and prove they work.
#
# Background: dist/win64/LATEST.txt used to carry the line
#   "NOT verified: Win64 runtime (no wine on the build host)"
# and RELEASE-v54.txt said the same.  That was an unchecked assumption about
# this box, not a fact about the world -- exactly like the "no qemu" note that
# dist/arm-runtime-proof.sh disproved.  wine64 is a stock Ubuntu noble/universe
# package; installing it takes one command and the shipped ppcx64.exe then runs.
# This script is that measurement, made repeatable so nobody takes it on faith.
#
#   sudo apt-get install -y --no-install-recommends wine64
#   sh dist/win64-runtime-proof.sh [workdir]
#
# Exit 0 = every stage passed.  Run it from a vibepascal checkout.
#
# LIMIT, stated up front: wine is NOT Windows.  It is an independent
# reimplementation of the Win64 API running the real shipped PE bytes and real
# x86-64 instructions, so codegen, PE layout, entry point, calling convention
# and RTL-startup defects DO surface here.  What it cannot show is anything
# specific to a genuine Windows kernel, a real MSVCRT, or Windows-version
# behaviour.  Do NOT quote a pass here as a Windows sign-off.  The outstanding
# ask is still: one person, one Windows box, two exit codes.
set -e

VP=$(cd "$(dirname "$0")/.." && pwd)
W=${1:-$HOME/.cache/vp-win64-proof}
WINE=/usr/lib/wine/wine64
[ -x "$WINE" ] || WINE=$(command -v wine64 || echo /usr/lib/wine/wine64)
WINEPREFIX=${WINEPREFIX:-$HOME/.wine-vp}
export WINEPREFIX
export WINEDEBUG=-all
fail=0

say() { printf '\n=== %s ===\n' "$1"; }
ck()  { if [ "$2" = "$3" ]; then echo "  PASS $1 ($2)"; else echo "  FAIL $1: got $2 want $3"; fail=$((fail+1)); fi; }

[ -x "$WINE" ] || { echo "wine64 not found -- sudo apt-get install -y --no-install-recommends wine64"; exit 2; }

say "stage 0: unpack the PUBLISHED tarballs and hash-check the compiler"
BIN=$(sed -n 's/^versioned_tarball: *//p' "$VP/dist/win64/LATEST.txt")
UNITS=$(sed -n 's/^units_tarball: *//p'    "$VP/dist/win64/LATEST.txt")
WANT=$(sed -n 's/^ppcx64_exe_md5: *//p'    "$VP/dist/win64/LATEST.txt")
rm -rf "$W"; mkdir -p "$W/vp" "$W/build/units/x86_64-win64"
tar xzf "$VP/dist/win64/$BIN"   -C "$W/vp"
tar xzf "$VP/dist/win64/$UNITS" -C "$W/vp"
PPC="$W/vp/bin/ppcx64.exe"
GOT=$(md5sum "$PPC" | cut -d' ' -f1)
ck "shipped ppcx64.exe md5 matches LATEST.txt" "$GOT" "$WANT"
[ "$GOT" = "$WANT" ] || { echo "refusing to continue on a hash mismatch"; exit 1; }

say "stage 1: the shipped Windows compiler RUNS"
# -iD is the compiler's own build date; LATEST.txt records the release date as
# YYYY-MM-DD.  Comparing them checks that the binary in the tarball really is
# the one this pointer describes, not just that SOME compiler started.
WANTD=$(sed -n 's/^date: *//p' "$VP/dist/win64/LATEST.txt" | tr '-' '/')
ck "-iTO" "$($WINE "$PPC" -iTO 2>/dev/null | tr -d '\r\n')" "win64"
ck "-iTP" "$($WINE "$PPC" -iTP 2>/dev/null | tr -d '\r\n')" "x86_64"
ck "-iD matches LATEST.txt date" "$($WINE "$PPC" -iD 2>/dev/null | tr -d '\r\n')" "$WANTD"
echo "  info: -iV = $($WINE "$PPC" -iV 2>/dev/null | tr -d '\r\n')"

say "stage 2: it COMPILES and internally links, and the product RUNS"
# NOTE: bin/fpc.cfg ends with -FU./units/$FPCTARGET and the compiler does not
# create that directory -- hence the mkdir above.  Dist usability bug, not a
# compiler bug; documented in dist/win64/staging-v54/VERSION.txt.
cp "$VP/tests/test/tinlinevarnativeint1.pp" "$VP/tests/test/vp_win64_smoke.pp" "$W/build/"
cd "$W/build"
for mode in -Munleashed -Mdelphiunicode; do
  $WINE "$PPC" $mode -oni$mode.exe tinlinevarnativeint1.pp >/dev/null 2>&1
  out=$($WINE "./ni$mode.exe" 2>/dev/null | tr -d '\r' | tail -2 | head -1)
  ck "NativeInt matrix $mode" "$out" "checks=45 fails=0 NativeInt=8"
done
$WINE "$PPC" -Munleashed vp_win64_smoke.pp >/dev/null 2>&1
$WINE ./vp_win64_smoke.exe >/dev/null 2>&1 && rc=0 || rc=$?
ck "vp_win64_smoke exit code" "$rc" "0"

say "stage 3: negative control -- the harness must be able to FAIL"
# Same source, cross-built by the preserved pre-v54 compiler.  If this exits 0
# the whole run above is meaningless, so treat a pass here as a red flag.
CTL=$HOME/src/vibepascal-slices/cy1098_nativeint_inference/ppcx64.pre-nativeint
CFG=$VP/vibepascal-win64-x86_64.cfg
if [ ! -x "$CTL" ] || [ ! -f "$CFG" ]; then
  echo "  SKIP negative control -- needs the preserved pre-v54 compiler at"
  echo "       $CTL"
  echo "       and the host win64 unit-path config $CFG"
  echo "       (both are lazdev-local: the cfg holds absolute host paths, so it"
  echo "       is deliberately not committed).  Stages 0-2 still stand on their"
  echo "       own; you just lose the proof that this harness CAN report a"
  echo "       failure."
else
  mkdir -p "$W/build/ctl"
  "$CTL" @"$CFG" -Munleashed -Twin64 -Apecoff -Xi \
         -FE"$W/build/ctl" -FU"$W/build/ctl" "$VP/tests/test/vp_win64_smoke.pp" \
         >"$W/build/ctl.log" 2>&1 && crc=0 || crc=$?
  if [ "$crc" -ne 0 ]; then
    echo "  FAIL pre-v54 control did not build (see $W/build/ctl.log)"; fail=$((fail+1))
  else
    $WINE "$W/build/ctl/vp_win64_smoke.exe" >/dev/null 2>&1 && rc=0 || rc=$?
    ck "pre-v54 control exit code" "$rc" "1"
  fi
fi

say "result"
if [ "$fail" -eq 0 ]; then
  echo "ALL STAGES PASSED -- the shipped Win64 toolchain runs end to end under wine."
  echo "This is NOT a real-Windows sign-off.  See the LIMIT note at the top."
  exit 0
else
  echo "$fail stage(s) FAILED"
  exit 1
fi
