#!/bin/bash
# ppu-reload-check.sh -- when a unit is RESET for recompilation in the middle of a build,
# does this compiler RECOMPILE the source units that already resolved symbols out of it,
# or does it "reload" them and leave dangling pointers?
#
# cy1168/cy1169 (2026-09-22), from Lars's incremental Lazarus IDE builds: after a Lazarus
# source pull, "lazbuild --build-ide" died with EAccessViolation in
#   tderef.build <- tabstractpointerdef.buildderef <- tprocdef.buildderefimpl <- writeppu
# on every published compiler since the ctask scheduler came in (v59, v60, v61 measured).
# Mechanism, read off the scheduler trace (-dDEBUG_PPU_CYCLES): unit U was loaded from its
# .ppu, unit X was compiled from source against it, and only then did the scheduler learn
# that U's IMPLEMENTATION uses a unit whose checksum changed (a cycle through an
# implementation uses clause defers that check).  U is reset and recompiled;
# tmodule.flagdependent flagged X for a RELOAD, and tppumodule.re_resolve can only re-resolve
# deref tables -- a source unit has none for its implementation side (local symtables of its
# routines, inline bodies, generated code), so X kept pointers into U's freed symtable and
# writeppu walked them.  The fix (compiler/fmodule.pas, tmodule.flagdependent) marks a
# source-compiled dependent for a full RECOMPILE instead, exactly as
# dependent_module_crc_mismatch already did for the checksum case.
#
# This gate builds the five units under dist/ppu-reload-check/ twice: a clean build, then a
# rebuild after c_changed's interface changed.  The chain P -> S -> D -> X -> U(.impl -> S) is the
# smallest shape that makes the scheduler reset U after X compiled against it.  The defect does
# NOT crash on this small shape (the freed defs are usually still intact, so the stale derefs
# come out right by luck), which is why it is scored on the compiler's own -vu messages and not
# on rc alone:
#
#   PASS (exit 0): rebuild rc=0, the program prints 14, and the log says
#                  "Recompiling X_SRC, checksum changed for U_PPU"  (the dependent was recompiled)
#   FAIL (exit 1): the log says "Flag for reload: X_SRC"  (the dependent was reloaded -- the defect),
#                  or the rebuild failed / crashed / printed the wrong value
#   exit 2:        the harness could not run, or the shape was not exercised (neither message);
#                  says nothing about the compiler
#
#   usage: ppu-reload-check.sh <compiler> <rtl-unit-dir> [scratch-dir]
#   e.g.   ppu-reload-check.sh compiler/ppcx64 rtl/units/x86_64-linux
#
# Measured 2026-09-22: published v59 (12220bfd...) and v61 (7775a119...) -> FAIL (reload line, rc=0,
# right output -- the silent form); the fixed build -> PASS.  The full-size proof is the Lazarus
# two-step rig under ~/src/vibepascal-slices/ppu-av-cy1168/ (snapshot 30d1cbd292 -> 9d49ba95ff):
# EAccessViolation exit 217 on v59 and v61, clean build with the fix.
set -u
here=$(cd "$(dirname "$0")" && pwd)
cc=${1:-}; rtl=${2:-}; scratch=${3:-}
if [ -z "$cc" ] || [ -z "$rtl" ]; then sed -n '2,40p' "$0"; exit 2; fi
cc=$(cd "$(dirname "$cc")" && pwd)/$(basename "$cc")
rtl=$(cd "$rtl" 2>/dev/null && pwd) || { echo "ppu-reload-check: no such rtl unit dir"; exit 2; }
[ -x "$cc" ] || { echo "ppu-reload-check: $cc is not executable"; exit 2; }
[ -f "$rtl/system.ppu" ] || { echo "ppu-reload-check: $rtl has no system.ppu"; exit 2; }
if [ -z "$scratch" ]; then scratch=$(mktemp -d "${TMPDIR:-$HOME}/ppu-reload-check.XXXXXX") || exit 2; keep=0; else mkdir -p "$scratch" || exit 2; keep=1; fi
cp "$here"/ppu-reload-check/*.pas "$scratch"/ || exit 2
cd "$scratch" || exit 2
ulimit -v ${PPURELOAD_VMCAP_KB:-4194304}
"$cc" -n -vu -Fu"$rtl" -Fu. -FE. p.pas > step1.log 2>&1; rc1=$?
out1=$(./p 2>/dev/null); r1=$?
if [ $rc1 -ne 0 ] || [ $r1 -ne 0 ] || [ "$out1" != "13" ]; then
  echo "ppu-reload-check: clean build did not work (rc=$rc1 run=$r1 out='$out1') -- harness"; tail -5 step1.log; exit 2
fi
sleep 1.1   # one-second source timestamps
sed -i 's/CVal = 1;/CVal = 2;/' c_changed.pas
"$cc" -n -vu -Fu"$rtl" -Fu. -FE. p.pas > step2.log 2>&1; rc2=$?
out2=$(./p 2>/dev/null); r2=$?
reload=$(grep -c 'Flag for reload: X_SRC' step2.log)
recomp=$(grep -c 'Recompiling X_SRC, checksum changed for U_PPU' step2.log)
av=$(grep -c 'Access violation\|Internal error\|unhandled exception' step2.log)
echo "ppu-reload-check: $cc rebuild rc=$rc2 run=$r2 out='$out2' reload_lines=$reload recompile_lines=$recomp crash_lines=$av"
[ $keep -eq 0 ] && rm -rf "$scratch"
if [ $reload -gt 0 ] || [ $av -gt 0 ] || [ $rc2 -ne 0 ] || [ $r2 -ne 0 ] || [ "$out2" != "14" ]; then
  echo "RESULT: FAIL -- a source-compiled dependent was reloaded instead of recompiled (or the rebuild broke)"; exit 1
fi
if [ $recomp -eq 0 ]; then echo "RESULT: UNDECIDED -- neither message seen, the shape was not exercised"; exit 2; fi
echo "RESULT: PASS -- the dependent was recompiled from source after its used unit was reset"; exit 0
