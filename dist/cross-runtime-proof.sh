#!/bin/sh
# cross-runtime-proof.sh -- run the shipped CROSS compilers end to end from
# PUBLISHED BYTES ONLY, and prove the documented REASON as well as the cure.
#
# dist/arm-runtime-proof.sh covers the NATIVE arm-linux and aarch64-linux
# compilers.  Neither CROSS compiler had ever been exercised by a committed
# script, and the first i386-linux unit set (cy1124) shipped with no proof
# following it at all -- only two pages of prose cautions, and a caution
# nobody can EXECUTE is not a check.  This is that check.
#
#   sudo apt-get install -y qemu-user-static binutils-arm-linux-gnueabihf
#   sh dist/cross-runtime-proof.sh [workdir]
#
# Exit 0 = every stage passed, 1 = a stage failed, 2 = the host is missing a
# tool so nothing was measured.  Run it from a vibepascal checkout: the
# i386 RTL-only negative control SELECTS its subset using rtl/units/i386-linux
# as the list of RTL basenames (the BYTES it copies still come out of the
# published tarball, so the A/B stays single-axis).
#
# WHAT A PASS PROVES, AND THE TWO THINGS IT DOES NOT:
#   * arm-linux-cross: qemu-user executes the real ARM encodings we emit, so
#     codegen and RTL defects DO surface -- but it is an emulator, not a Pi.
#   * i386-linux-cross: the OUTPUT runs natively on this x86_64 kernel, so
#     that half is not emulated at all -- but nobody has run it on a real
#     32-bit i386 userland, and the COMPILER is an x86_64 binary either way.
#   Neither half is a hardware sign-off.  Say so wherever you quote a pass.

VP=$(cd "$(dirname "$0")/.." && pwd)
# NOT ${TMPDIR:-/tmp} like the sibling script: the two full unit sets extract to
# ~740 MB and /tmp here is a 2 GB tmpfs shared with three other agents.  A prefix
# that fills a tmpfs fails in ways that look like a defect in the artifact
# (measured once already with the wine prefix, cy1101).
W=${1:-$HOME/.vp-cross-proof}
pass=0

die()  { echo "  FAIL $*"; exit 1; }
okay() { echo "  ok  $*"; pass=$((pass+1)); }

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING: $1"; miss=1; }; }
miss=0
need qemu-arm-static
need arm-linux-gnueabihf-ld
need file
need md5sum
[ -d "$VP/rtl/units/i386-linux" ] || { echo "MISSING: $VP/rtl/units/i386-linux (needed to select the RTL-only control subset)"; miss=1; }
[ $miss -eq 0 ] || { echo "PROOF ABORTED -- nothing was measured."; exit 2; }

avail=$(df -Pk "$(dirname "$W")" | awk 'NR==2{print $4}')
[ "${avail:-0}" -ge 1200000 ] || { echo "PROOF ABORTED -- $(dirname "$W") has ${avail}KB free, need ~1.2GB (two full unit sets extract to ~740MB)."; exit 2; }

rm -rf "$W"; mkdir -p "$W/arm" "$W/i386"

# ---- artifact resolvers ------------------------------------------------------
# NEVER name a published artifact literally in a gate script: arm-runtime-proof.sh
# already had latest_bin() for exactly this reason and STILL hardcoded the units
# name on the next line, so publishing a better unit set would have left it
# printing PASS over superseded bytes forever.
latest_bin() { # $1 = dist subdir (which for a cross compiler IS the filename token)
    find "$VP/dist/$1" -maxdepth 1 -type f -name "vibepascal-v*-$1-bin.tar.gz" 2>/dev/null |
    while IFS= read -r t; do
        b=$(basename "$t"); v=${b#vibepascal-v}; v=${v%%-*}
        case "$v" in ''|*[!0-9]*) continue ;; esac
        printf '%08d %s\n' "$v" "$t"
    done | sort -n | tail -1 | cut -d' ' -f2-
}

# DIRECTORY AND TARGET ARE TWO DIFFERENT THINGS HERE, which is why this takes two
# arguments while the arm-runtime-proof.sh version takes one.  The i386 unit
# tarball lives in dist/i386-linux-CROSS/ (host-oriented: it ships beside the
# compiler that runs on x86_64) but is named for its TARGET, i386-linux, because
# the PPUs are not cross-specific -- a native i386 compiler would use the identical
# set.  A rename would claim otherwise, so the resolver gets the explicit case
# instead.  arm is the other shape again: the cross compiler is in
# dist/arm-linux-cross/ and reuses the units published under dist/arm-linux/.
latest_units() { # $1 = dist subdir   $2 = target token in the filename
    for suffix in units-full units; do
        found=$(find "$VP/dist/$1" -maxdepth 1 -type f \
                     -name "vibepascal-v*-$2-$suffix.tar.gz" 2>/dev/null |
        while IFS= read -r t; do
            b=$(basename "$t"); v=${b#vibepascal-v}; v=${v%%-*}
            case "$v" in ''|*[!0-9]*) continue ;; esac
            printf '%08d %s\n' "$v" "$t"
        done | sort -n | tail -1 | cut -d' ' -f2-)
        [ -n "$found" ] && { echo "$found"; return 0; }
    done
    return 1
}

# ---- the programs ------------------------------------------------------------
# pkgtest deliberately uses a PACKAGE unit (fpjson, packages/fcl-json) and not
# just SysUtils+Classes: an RTL-only unit set passes a hello-world AND passes
# "uses SysUtils, Classes" because that resolves entirely inside the RTL, which
# is exactly how the arm-linux RTL-only tarball stayed invisible for a day.
write_srcs() { # $1 = tag printed by pkgtest
cat > pkgtest.pas <<EOF
program pkgtest;
{\$mode objfpc}{\$H+}
uses SysUtils, Classes, fpjson;
var
  L: TStringList;
  O: TJSONObject;
begin
  L := TStringList.Create;
  O := TJSONObject.Create;
  try
    L.Add('vibepascal'); L.Add('$1');
    O.Add('target', L[1]);
    O.Add('nativeint', SizeOf(NativeInt));
    WriteLn('HELLO ', L[0], ' ', L[1], ' ', IntToStr(L.Count), ' ', O.AsJSON);
  finally
    O.Free; L.Free;
  end;
end.
EOF
cat > hello.pas <<'EOF'
program hello;
begin
  WriteLn(1);
end.
EOF
cat > rtltest.pas <<'EOF'
program rtltest;
{$mode objfpc}{$H+}
uses SysUtils, Classes;
begin WriteLn(IntToStr(SizeOf(NativeInt))); end.
EOF
cat > pkgonly.pas <<'EOF'
program pkgonly;
{$mode objfpc}{$H+}
uses SysUtils, fpjson;
begin WriteLn(SizeOf(NativeInt)); end.
EOF
}

# A negative control is scored on its MESSAGE TEXT, never on rc.  Measured the
# hard way (cy1123): ppca64 rejects an unknown flag with rc=1 and the GENUINE
# units-hidden control also returns rc=1, so a run in which nothing at all was
# tested was indistinguishable from a control that fired.
expect_text() { # $1 log  $2 substring  $3 label
    grep -qF "$2" "$1" || { echo "  FAIL $3: expected text not in log:"; echo "        \"$2\""; tail -5 "$1"; exit 1; }
}

# ============================================================ arm-linux-cross ==
echo "== arm-linux-cross (x86_64 host binary, 32-bit ARM output) =="
cd "$W/arm" || exit 1
ARMTB=$(latest_bin arm-linux-cross)
[ -n "$ARMTB" ] || die "no arm-linux-cross bin tarball published"
echo "  using $(basename "$ARMTB")"; tar xzf "$ARMTB" || die "extract $ARMTB"
ARMUNITS=$(latest_units arm-linux arm-linux) || die "no arm-linux units tarball published"
echo "  using $(basename "$ARMUNITS")  (published under dist/arm-linux, shared with the NATIVE compiler)"
tar xzf "$ARMUNITS" || die "extract $ARMUNITS"

want=$(sed -n 's/.*ppcrossarm  *md5 \([0-9a-f]*\).*/\1/p' VERSION.txt | head -1)
got=$(md5sum bin/ppcrossarm | cut -d' ' -f1)
if [ -n "$want" ]; then
    [ "$want" = "$got" ] || die "ppcrossarm md5 $got != declared $want"
    okay "ppcrossarm md5 matches its own VERSION.txt"
else
    echo "  --  VERSION.txt declares no ppcrossarm md5; measured $got"
fi

file bin/ppcrossarm | grep -q 'ELF 64-bit.*x86-64' \
    || die "ppcrossarm is not an x86_64 host binary: $(file bin/ppcrossarm)"
okay "ppcrossarm is an x86_64 HOST binary (this is the whole reason -XP matters)"

write_srcs arm-linux-cross
ARMFU="-Fuunits/arm-linux -Flunits/arm-linux"

# --- the cure ---
./bin/ppcrossarm -n -FU. $ARMFU -XParm-linux-gnueabihf- pkgtest.pas >xp.log 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "  FAIL arm cross-compile WITH -XP failed (rc=$rc)"; tail -5 xp.log; exit 1; }
file pkgtest | grep -q 'ELF 32-bit.*ARM, EABI5.*statically linked' \
    || die "arm artifact is not a static ARM EABI5 ELF: $(file pkgtest)"
okay "WITH -XParm-linux-gnueabihf-: rc=0, $(file -b pkgtest | cut -d, -f1-4)"

qemu-arm-static -L /usr/arm-linux-gnueabihf ./pkgtest >run.out 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "  FAIL arm artifact compiled but exited $rc"; cat run.out; exit 1; }
grep -q '^HELLO vibepascal arm-linux-cross 2 ' run.out || die "arm output line wrong: $(cat run.out)"
grep -q '"nativeint" : 4' run.out || die "arm NativeInt is not 4: $(cat run.out)"
okay "RUNS under qemu-arm-static: $(cat run.out)"

# --- THE REASON.  Not a flag quietly passed: both sides asserted. ---
# Without the prefix the compiler resolves every unit correctly, gets all the way
# to LINK, and dies naming a unit .o -- so it reads exactly like a corrupt or
# incomplete unit set, and the unit set is fine.  Asserting only the cure would
# leave the next reader blaming our libraries for an intrinsic cross-link fact.
rm -f pkgtest
./bin/ppcrossarm -n -FU. $ARMFU pkgtest.pas >noxp.log 2>&1; rc=$?
[ $rc -ne 0 ] || die "WITHOUT -XP the compile SUCCEEDED -- the documented trap no longer reproduces, so this script's reason is stale"
expect_text noxp.log 'skipping incompatible' "no -XP"
expect_text noxp.log 'Error while linking'   "no -XP"
okay "WITHOUT -XP: rc=$rc, fails at LINK with 'skipping incompatible ... .o' -- blames a UNIT, cause is the HOST ld"

# -Xi (internal linker) is NOT a way around it; it fell through to the same ld.
./bin/ppcrossarm -n -FU. $ARMFU -Xi pkgtest.pas >xi.log 2>&1; rc=$?
[ $rc -ne 0 ] || die "-Xi succeeded without -XP -- update the docs, the internal linker now substitutes"
okay "-Xi is NOT a substitute for -XP either (rc=$rc)"

# --- negative control: units hidden, scored on TEXT ---
mv units units.hidden
./bin/ppcrossarm -n -FU. -Fuunits/arm-linux -Flunits/arm-linux -XParm-linux-gnueabihf- hello.pas >nounits.log 2>&1
expect_text nounits.log "Can't find unit system used by hello" "arm units-hidden control"
okay "NEGATIVE CONTROL fires: units hidden -> Can't find unit system used by hello"
mv units.hidden units

# ============================================================ i386-linux-cross ==
echo "== i386-linux-cross (x86_64 host binary, 32-bit Intel output, NO -XP) =="
cd "$W/i386" || exit 1
I386TB=$(latest_bin i386-linux-cross)
[ -n "$I386TB" ] || die "no i386-linux-cross bin tarball published"
echo "  using $(basename "$I386TB")"; tar xzf "$I386TB" || die "extract $I386TB"
I386UNITS=$(latest_units i386-linux-cross i386-linux) || die "no i386-linux units tarball published"
echo "  using $(basename "$I386UNITS")  (dir names the HOST, file names the TARGET -- see UNITS.txt)"
tar xzf "$I386UNITS" || die "extract $I386UNITS"

want=$(sed -n 's/.*ppcross386  *md5 \([0-9a-f]*\).*/\1/p' VERSION.txt | head -1)
got=$(md5sum bin/ppcross386 | cut -d' ' -f1)
if [ -n "$want" ]; then
    [ "$want" = "$got" ] || die "ppcross386 md5 $got != declared $want"
    okay "ppcross386 md5 matches its own VERSION.txt"
else
    echo "  --  VERSION.txt declares no ppcross386 md5; measured $got"
fi

write_srcs i386-linux
I386FU="-Fuunits/i386-linux -Flunits/i386-linux"

# The OPPOSITE case to arm, and it has to be MEASURED rather than assumed from
# "it is a cross compiler": stock x86_64 binutils links elf_i386 and a stock
# x86_64 kernel runs the result, so there is no -XP and nothing to install.
./bin/ppcross386 -n -FU. $I386FU pkgtest.pas >c.log 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "  FAIL i386 cross-compile failed (rc=$rc)"; tail -5 c.log; exit 1; }
file pkgtest | grep -q 'ELF 32-bit.*Intel 80386.*statically linked' \
    || die "i386 artifact is not a static i386 ELF: $(file pkgtest)"
okay "NO -XP needed: rc=0, $(file -b pkgtest | cut -d, -f1-4)"

./pkgtest >run.out 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "  FAIL i386 artifact compiled but exited $rc"; cat run.out; exit 1; }
grep -q '^HELLO vibepascal i386-linux 2 ' run.out || die "i386 output line wrong: $(cat run.out)"
grep -q '"nativeint" : 4' run.out || die "i386 NativeInt is not 4: $(cat run.out)"
okay "RUNS NATIVELY on this x86_64 kernel (not emulated): $(cat run.out)"

# --- negative control A: units hidden, scored on TEXT ---
mv units units.hidden
./bin/ppcross386 -n -FU. $I386FU hello.pas >nounits.log 2>&1
expect_text nounits.log "Can't find unit system used by hello" "i386 units-hidden control"
okay "NEGATIVE CONTROL A fires: units hidden -> Can't find unit system used by hello"
mv units.hidden units

# --- negative control B: RTL-only vs full, SINGLE AXIS ---
# The subset is selected by BASENAME from rtl/units/i386-linux and copied out of
# the published tarball we already extracted, so the only thing that differs
# between the two arms is which units are visible -- not the compiler, not the
# command, not the bytes.
mkdir -p rtlonly/i386-linux
n=0
for f in "$VP"/rtl/units/i386-linux/*; do
    b=$(basename "$f")
    [ -f "units/i386-linux/$b" ] && { cp "units/i386-linux/$b" "rtlonly/i386-linux/$b"; n=$((n+1)); }
done
[ "$n" -gt 100 ] || die "RTL-only control set is only $n files -- selector is broken, control would be void"
tot=$(ls units/i386-linux | wc -l)
[ "$n" -lt "$tot" ] || die "RTL-only set ($n) is not smaller than the full set ($tot) -- no axis to vary"
echo "  --  control sets: RTL-only $n files vs full $tot files"

RTLFU="-Furtlonly/i386-linux -Flrtlonly/i386-linux"
# Arm 1: uses SysUtils, Classes -- resolves inside the RTL, so BOTH must pass.
# This is the arm that proves the control is about fpjson and not about the
# RTL-only set being broken in general.
./bin/ppcross386 -n -FUrtlonly $RTLFU rtltest.pas >r1.log 2>&1 || { echo "  FAIL rtltest should build against the RTL-only set"; tail -3 r1.log; exit 1; }
./bin/ppcross386 -n -FU. $I386FU rtltest.pas >r2.log 2>&1 || { echo "  FAIL rtltest should build against the full set"; tail -3 r2.log; exit 1; }
okay "uses SysUtils, Classes: rc=0 against BOTH sets (an RTL-only tarball passes this -- that is the trap)"

# Arm 2: uses a PACKAGE unit -- the single axis.
./bin/ppcross386 -n -FUrtlonly $RTLFU pkgonly.pas >p1.log 2>&1; rc=$?
[ $rc -ne 0 ] || die "pkgonly built against the RTL-ONLY set -- fpjson is not a package unit here, control is void"
expect_text p1.log "Can't find unit fpjson used by pkgonly" "i386 RTL-only A/B"
./bin/ppcross386 -n -FU. $I386FU pkgonly.pas >p2.log 2>&1 || { echo "  FAIL pkgonly should build against the FULL set"; tail -3 p2.log; exit 1; }
./pkgonly >p2.out 2>&1 || { echo "  FAIL pkgonly built against the full set but did not run"; cat p2.out; exit 1; }
[ "$(cat p2.out)" = 4 ] || die "pkgonly printed '$(cat p2.out)', expected 4"
okay "NEGATIVE CONTROL B fires: uses fpjson -> RTL-only \"Can't find unit fpjson\", full set rc=0 and RUNS (printed 4)"

echo
echo "CROSS RUNTIME PROOF: PASS  ($pass assertions; arm half is qemu-emulated, i386 output ran natively -- see the LIMIT note at the top)"
