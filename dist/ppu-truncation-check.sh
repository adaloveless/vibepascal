#!/bin/bash
# ppu-truncation-check.sh -- does this compiler survive a HALF-WRITTEN .ppu?
#
# cy1114, after BuildMaster found ppcx64 spinning at 99% CPU forever on a
# truncated-but-nonempty unit file (a killed build, a full disk or an
# interrupted copy all leave one behind).  The bug was never about ONE file
# size: nine of the twenty offsets below hung on the pre-fix compiler, so a
# harness that checks only the reported one under-measures it.
#
#   usage: ppu-truncation-check.sh <compiler> <target> <a-real.ppu> <rtl-unit-dir>
#   e.g.   ppu-truncation-check.sh compiler/ppcx64 x86_64-linux \
#             packages/aspell/units/x86_64-linux/aspelldyn.ppu \
#             rtl/units/x86_64-linux
#
# exit 0 = every truncation offset terminated with a message and a nonzero rc,
#          and the intact .ppu still compiled;
# exit 1 = the compiler HUNG, silently failed, or accepted a truncated .ppu
#          (i.e. the tree is bad);
# exit 2 = the harness could not run -- says nothing about the compiler.
#
# DELIBERATELY NOT SCORED: an offset inside the last ~11 bytes of the file.
# Nothing an interface load reads lives there, so the reader cannot notice
# those bytes are gone and a .ppu missing them is still accepted with rc=0.
# Catching that needs a whole-file length check against the size recorded in
# the header, which must also cope with .ppu data read from a nonzero offset
# inside a stream.  It is a real gap and it is open, not covered by this gate;
# scoring it here would only make the gate red forever and teach people to
# ignore it.
#
# -n is mandatory: without it ~/.fpc.cfg puts the INSTALLED unit dirs on the
# path and the deliberately-corrupted unit is resolved from outside the test.
# -Cn is mandatory too: a link step would fail for its own reasons and mask
# the result.  Loading a .ppu happens at COMPILE time, so neither a linker nor
# an assembler is needed to judge this.

PPC="$1"; TARGET="$2"; REALPPU="$3"; RTL="$4"
[ -n "$PPC" ] && [ -n "$TARGET" ] && [ -n "$REALPPU" ] && [ -n "$RTL" ] || {
  echo "TRUNCCHECK FATAL: usage: $0 <compiler> <target> <a-real.ppu> <rtl-unit-dir>" >&2
  echo "trunccheck: 0/0 offsets clean, 1 problem(s)"; exit 2; }
[ -x "$PPC" ]      || { echo "TRUNCCHECK FATAL: no compiler at $PPC" >&2;        echo "trunccheck: 0/0 offsets clean, 1 problem(s)"; exit 2; }
[ -f "$REALPPU" ]  || { echo "TRUNCCHECK FATAL: no .ppu at $REALPPU" >&2;        echo "trunccheck: 0/0 offsets clean, 1 problem(s)"; exit 2; }
[ -d "$RTL" ]      || { echo "TRUNCCHECK FATAL: no rtl unit dir at $RTL" >&2;    echo "trunccheck: 0/0 offsets clean, 1 problem(s)"; exit 2; }

CPU=${TARGET%%-*}; OS=${TARGET#*-}
UNIT=$(basename "$REALPPU" .ppu)
FULL=$(stat -c%s "$REALPPU") || { echo "TRUNCCHECK FATAL: cannot stat $REALPPU" >&2; echo "trunccheck: 0/0 offsets clean, 1 problem(s)"; exit 2; }

SCRATCH=$(mktemp -d) || { echo "TRUNCCHECK FATAL: mktemp failed" >&2; echo "trunccheck: 0/0 offsets clean, 1 problem(s)"; exit 2; }
total=0; bad=0; rc_final=0
# The summary line is owed on EVERY exit path, including a signal (cy1113):
# a gate that reconciles a count against it cannot score a run that printed
# a header and no number.
finish() {
  [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
  echo "trunccheck $TARGET: $((total-bad))/$total offsets clean, $bad problem(s)"
}
trap finish EXIT
trap 'echo "ABORTED $TARGET -- killed after $total of the offsets were judged"; bad=$((bad+1)); exit 130' HUP INT TERM

printf 'program p;\nuses %s;\nbegin end.\n' "$UNIT" > "$SCRATCH/p.pp"

for n in 0 1 20 39 40 41 45 54 70 77 83 100 119 120 121 200 1000 $((FULL/2)) $FULL; do
  total=$((total+1))
  U="$SCRATCH/u"; W="$SCRATCH/w"; rm -rf "$U" "$W"; mkdir -p "$U" "$W" || { echo "TRUNCCHECK FATAL: cannot make scratch dirs" >&2; exit 2; }
  head -c "$n" "$REALPPU" > "$U/$UNIT.ppu"
  out=$(timeout 30 "$PPC" -n -s -T"$OS" -P"$CPU" -Cn -Fu"$U" -Fu"$RTL" -FU"$W" "$SCRATCH/p.pp" 2>&1)
  rc=$?
  if [ "$n" = "$FULL" ]; then
    [ "$rc" = 0 ] && continue
    echo "BROKEN $TARGET $UNIT.ppu intact ($n bytes) -- rc=$rc, the compiler rejects a GOOD unit"
    bad=$((bad+1)); rc_final=1; continue
  fi
  case "$rc" in
    124) echo "HANG $TARGET $UNIT.ppu truncated to $n bytes -- no output, killed at 30s"
         bad=$((bad+1)); rc_final=1 ;;
      0) echo "ACCEPTED $TARGET $UNIT.ppu truncated to $n bytes -- rc=0, a corrupt unit was taken as valid"
         bad=$((bad+1)); rc_final=1 ;;
      *) if [ -z "$out" ]; then
           echo "SILENT $TARGET $UNIT.ppu truncated to $n bytes -- rc=$rc with no message to grep for"
           bad=$((bad+1)); rc_final=1
         fi ;;
  esac
done
exit $rc_final
