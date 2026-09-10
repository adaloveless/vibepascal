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
rm -rf "$W"; mkdir -p "$W/vp" "$W/build"
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
# There is deliberately NO mkdir of ./units/$FPCTARGET here.  bin/fpc.cfg ends
# with -FU./units/$FPCTARGET, and up to v54 the compiler did not create that
# directory, so this very step used to need a hand-made mkdir to get going.
# v55 creates it; stage 2b below asserts that, so if the fix ever regresses
# this script fails here rather than quietly papering over it.
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

say "stage 2b: a FRESH directory needs no mkdir (the v55 -FU fix)"
# The v54-and-earlier failure this replaced, verbatim:
#   hello.pas(4,1) Error: Can't create object file: .\units\x86_64-win64\hello.o (error code: 3)
#   hello.pas(4,1) Fatal: Can't create object .\units\x86_64-win64\hello.o
# Anchored on a directory that has never existed, with the SHIPPED fpc.cfg.
mkdir -p "$W/fresh"
cat > "$W/fresh/hello.pas" <<'PAS'
program hello;
begin
  writeln('hello from vibepascal');
end.
PAS
( cd "$W/fresh" && $WINE "$PPC" hello.pas ) >"$W/fresh/compile.log" 2>&1 && frc=0 || frc=$?
ck "fresh-dir compile exit code" "$frc" "0"
[ -f "$W/fresh/units/x86_64-win64/hello.o" ] && got=yes || got=no
ck "compiler created units/x86_64-win64" "$got" "yes"
ck "fresh-dir exe output" "$($WINE "$W/fresh/hello.exe" 2>/dev/null | tr -d '\r\n')" "hello from vibepascal"

# Negative control for THIS stage: the preserved pre-fix v54 compiler must
# still fail in the same directory shape, or the stage above proves nothing.
PRE=$HOME/src/vibepascal-slices/cy1102_outputdir/ppcx64.exe.pre-outputdir-v54
if [ ! -f "$PRE" ]; then
  echo "  SKIP pre-v55 -FU control -- needs the preserved v54 exe at"
  echo "       $PRE (lazdev-local)"
else
  cp "$PRE" "$W/vp/bin/ppcx64.pre.exe"
  mkdir -p "$W/freshctl"; cp "$W/fresh/hello.pas" "$W/freshctl/"
  ( cd "$W/freshctl" && $WINE "$W/vp/bin/ppcx64.pre.exe" hello.pas ) \
      >"$W/freshctl/compile.log" 2>&1 && crc2=0 || crc2=$?
  ck "pre-v55 control fresh-dir exit code" "$crc2" "1"
  if grep -q "Can't create object file" "$W/freshctl/compile.log"; then got=yes; else got=no; fi
  ck "pre-v55 control failed for the -FU reason" "$got" "yes"

  # The CWD is the axis under test, and this corner is here to prove it.
  # -FU./units/$FPCTARGET writes relative to the USER'S current directory, so the
  # PRE-fix compiler passes anywhere ./units/x86_64-win64 already exists -- the
  # install root being the obvious such place, because the units tarball just
  # made one.  Asserting exit 0 here is not a test of the fix; it is a guard
  # against mistaking this shape FOR one.  Measured cy1103 under wine64 on the
  # published bytes: v54 in the install root exits 0 and builds hello.exe, same
  # as v55, so a check run there cannot tell the two apart.  Anyone verifying
  # v55 on real Windows hardware must stand in an EMPTY directory -- not the
  # install root, and not a built lazarus tree, which also carries
  # units/x86_64-win64 at its top level.
  cp "$W/fresh/hello.pas" "$W/vp/hello.pas"
  ( cd "$W/vp" && $WINE "$W/vp/bin/ppcx64.pre.exe" hello.pas ) \
      >"$W/vp/compile-inroot.log" 2>&1 && irc=0 || irc=$?
  ck "pre-v55 in the INSTALL ROOT exits 0 (shape that cannot discriminate)" "$irc" "0"
fi

say "stage 2c: an inferred real inline var is a Double (the v56 fix)"
# v55 and earlier typed `var x := <real constant>` from the constant itself, so
# the width moved with the VALUE: 1.0 gave a Single, 0.1 gave an Extended.  v56
# infers the default real type instead.  The control is the PUBLISHED v55 exe
# out of the tarball next door -- no lazdev-local artifact needed, so this stage
# never degrades to a SKIP.
# Counts are 52 / 49 rather than the 57 / 54 the same test reports on Linux,
# and that difference is the point rather than a wart: five of its corners live
# behind {$if SizeOf(Extended) > SizeOf(Double)}, and on Win64 Extended IS
# Double (8 bytes), exactly as Delphi has it.  So on Win64 the only width this
# fix moves is the Single one -- var a := 1.0 -- which is precisely why the
# published v55 exe below still fails the matrix here.
cp "$VP/tests/test/tinlinevarrealinfer1.pp" "$W/build/"
ck "real inference -Munleashed" \
   "$( cd "$W/build" && $WINE "$PPC" -Munleashed -oreal-u.exe tinlinevarrealinfer1.pp >/dev/null 2>&1; \
       $WINE "$W/build/real-u.exe" 2>/dev/null | tr -d '\r' | tail -2 | head -1 )" \
   "checks=52 fails=0 Double=8 folded=8"
ck "real inference -Mdelphi" \
   "$( cd "$W/build" && $WINE "$PPC" -Mdelphi -dDELPHI_MODE -oreal-d.exe tinlinevarrealinfer1.pp >/dev/null 2>&1; \
       $WINE "$W/build/real-d.exe" 2>/dev/null | tr -d '\r' | tail -2 | head -1 )" \
   "checks=49 fails=0 Double=8 folded=8"

V55BIN=$VP/dist/win64/vibepascal-v55-eae5d3e919-win64-bin.tar.gz
if [ ! -f "$V55BIN" ]; then
  echo "  SKIP pre-v56 real-inference control -- $V55BIN is gone"
else
  mkdir -p "$W/v55"; tar xzf "$V55BIN" -C "$W/v55" bin/ppcx64.exe
  cp "$VP/tests/test/tinlinevarrealinfer1.pp" "$W/v55/"
  ( cd "$W/v55" && $WINE bin/ppcx64.exe -Munleashed -Fu"$W/vp/units/x86_64-win64" \
        -oreal-ctl.exe tinlinevarrealinfer1.pp ) >"$W/v55/compile.log" 2>&1
  $WINE "$W/v55/real-ctl.exe" >/dev/null 2>&1 && vrc=0 || vrc=$?
  ck "pre-v56 control FAILS the real-inference matrix" "$vrc" "1"
fi

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
