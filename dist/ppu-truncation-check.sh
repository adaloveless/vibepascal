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
# THE TAIL OFFSETS ARE NOW SCORED (cy1117).  They used to be excluded on
# purpose: nothing an interface load READS lives in the last handful of bytes,
# so the reader could not notice they were gone and a .ppu missing them was
# accepted with rc=0 -- on the 55291-byte unit this gate is normally pointed
# at, every truncation from 55271 up passed.  Closing it needed a whole-file
# length check, comparing the physical length against the one the ppu header
# declares, which is what v58 added in tppufile.readheader.  A truncated unit
# whose source is available is now RECOMPILED and the build goes green; only a
# unit with no source left to rebuild from stops the compile.
#
# COMPANION CHECK, different question: this script asks whether the compiler
# SURVIVES a half-written unit.  dist/ppu-corruption-recovery-check.sh asks what
# RECOVERS one, which is what an operator needs after a roll dies.  Short
# version, measured cy1116 and written up in dist/linux-consumer-notes.txt: a
# zero-byte unit self-heals from source and the build goes green (while printing
# "Error:" and still exiting 0 -- do not gate on log text), a truncated one hard-
# fails no matter how many times you re-run it, and deleting the partial unit
# recovers completely.  Nothing about the scoring or the output tokens below
# changed when that was added.
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

# The tail offsets only mean something on a file big enough for them to sit
# past the fixed list above; below that they would duplicate offsets already
# scored and quietly inflate the denominator.  Say so rather than skip silently.
OFFSETS="0 1 20 39 40 41 45 54 70 77 83 100 119 120 121 200 1000 $((FULL/2))"
if [ "$FULL" -gt 1200 ]; then
  OFFSETS="$OFFSETS $((FULL-40)) $((FULL-20)) $((FULL-11)) $((FULL-5)) $((FULL-2)) $((FULL-1))"
else
  echo "trunccheck: $REALPPU is only $FULL bytes -- tail offsets not scored on a file this small"
fi
OFFSETS="$OFFSETS $FULL"

for n in $OFFSETS; do
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
