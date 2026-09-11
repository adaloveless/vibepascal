#!/bin/bash
# ppu-corruption-recovery-check.sh -- once a .ppu IS corrupt, what gets you back?
#
# cy1116.  Companion to ppu-truncation-check.sh, which asks whether the
# compiler SURVIVES a half-written unit.  This asks the next question, the one
# an operator actually has in front of them at 3am: the roll died with a full
# disk, there is a bad unit on the floor, the sources are sitting right beside
# it -- do I re-run the build, or is this a stop?
#
# BuildMaster hit this by accident (his zero-byte control read rc=0 because the
# default fpc.cfg had put the package SOURCE on the path, so the compiler just
# rebuilt the unit and exited clean).  That "broken" control was measuring the
# shape a REAL ROLL has -- units and sources side by side -- and the answer
# differs per corruption shape, which is worth an executable check rather than
# a sentence in a release note.
#
#   usage: ppu-corruption-recovery-check.sh <compiler> <target> <a-real.ppu> \
#             <unit-source-dir> <rtl-unit-dir>
#   e.g.   ppu-corruption-recovery-check.sh compiler/ppcx64 x86_64-linux \
#             packages/aspell/units/x86_64-linux/aspelldyn.ppu \
#             packages/aspell/src rtl/units/x86_64-linux
#
# exit 0 = recovery behaves as documented in dist/linux-consumer-notes.txt;
# exit 1 = it does not (the tree is bad);
# exit 2 = the harness could not run, or the source fallback it depends on is
#          not reachable -- says NOTHING about the compiler.
#
# -n is mandatory (~/.fpc.cfg would put the INSTALLED unit dirs on the path and
# resolve the corrupted unit from outside the test).  The source dir is then put
# back deliberately with -Fu, which is the whole point: this check needs source
# ON the path, where ppu-truncation-check.sh needs it OFF.
# -s and -Cn keep it to a COMPILE: loading and rebuilding a unit both happen at
# compile time, so neither an assembler nor a linker needs to exist -- which is
# what makes a cross target measurable at all.

PPC="$1"; TARGET="$2"; REALPPU="$3"; USRC="$4"; RTL="$5"

total=0; bad=0; rc_final=0
SCRATCH=""
# Owed on EVERY exit path including a signal (cy1113): a gate that reconciles a
# count against this line cannot score a run that printed a header and no number.
finish() {
  [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
  echo "recoverycheck ${TARGET:-?}: $((total-bad))/$total checks clean, $bad problem(s)"
}
trap finish EXIT
trap 'echo "ABORTED ${TARGET:-?} -- killed after $total of the checks were judged"; bad=$((bad+1)); exit 130' HUP INT TERM

die2() { echo "RECOVERYCHECK FATAL: $1" >&2; bad=$((bad+1)); total=$((total+1)); exit 2; }

[ -n "$PPC" ] && [ -n "$TARGET" ] && [ -n "$REALPPU" ] && [ -n "$USRC" ] && [ -n "$RTL" ] \
  || die2 "usage: $0 <compiler> <target> <a-real.ppu> <unit-source-dir> <rtl-unit-dir>"
[ -x "$PPC" ]     || die2 "no compiler at $PPC"
[ -f "$REALPPU" ] || die2 "no .ppu at $REALPPU"
[ -d "$USRC" ]    || die2 "no unit source dir at $USRC"
[ -d "$RTL" ]     || die2 "no rtl unit dir at $RTL"

# Resolve every path before the first cd: compile_once runs from a neutral
# scratch CWD so the caller's directory cannot leak units onto the path, which
# would silently break a relative "compiler/ppcx64" the way the sibling script
# accepts it.
PPC=$(readlink -f "$PPC")     || die2 "cannot resolve compiler path"
REALPPU=$(readlink -f "$REALPPU") || die2 "cannot resolve .ppu path"
USRC=$(readlink -f "$USRC")   || die2 "cannot resolve unit source dir"
RTL=$(readlink -f "$RTL")     || die2 "cannot resolve rtl unit dir"

CPU=${TARGET%%-*}; OS=${TARGET#*-}
UNIT=$(basename "$REALPPU" .ppu)
SCRATCH=$(mktemp -d) || { SCRATCH=""; die2 "mktemp failed"; }
printf 'program p;\nuses %s;\nbegin end.\n' "$UNIT" > "$SCRATCH/p.pp" || die2 "cannot write the probe program"

U="$SCRATCH/u"; W="$SCRATCH/w"

# $1 = one of: intact deleted zerobyte truncated  (how to seed $U/$UNIT.ppu)
# leaves $rc and $md5 set; $md5 is EMPTY if no .ppu survived the run
seed_and_run() {
  rm -rf "$U" "$W"; mkdir -p "$U" "$W" || die2 "cannot make scratch dirs"
  case "$1" in
    intact)    cp "$REALPPU" "$U/$UNIT.ppu" ;;
    deleted)   : ;;
    zerobyte)  : > "$U/$UNIT.ppu" ;;
    truncated) head -c 120 "$REALPPU" > "$U/$UNIT.ppu" ;;
  esac
  compile_once
}
compile_once() {
  out=$(cd "$SCRATCH" && timeout 60 "$PPC" -n -s -T"$OS" -P"$CPU" -Cn \
          -Fu"$U" -Fu"$USRC" -Fu"$RTL" -FU"$U" "$SCRATCH/p.pp" 2>&1)
  rc=$?
  if [ -f "$U/$UNIT.ppu" ]; then md5=$(md5sum "$U/$UNIT.ppu" | cut -d' ' -f1)
                                 size=$(stat -c%s "$U/$UNIT.ppu")
  else md5=""; size=MISSING; fi
}

# ---------------------------------------------------------------- 1. premise
# A clean rebuild from source with NO unit present at all.  If this cannot
# work, the source is not really on the path and every result below is
# meaningless -- that is a broken harness (exit 2), not a bad tree.
total=$((total+1))
seed_and_run deleted
[ "$rc" = 0 ] && [ -n "$md5" ] \
  || { echo "NOSOURCE $TARGET $UNIT -- no .ppu present and the source at $USRC did not rebuild it (rc=$rc)" >&2
       echo "  the source fallback this check measures is not reachable; nothing below can be judged" >&2
       bad=$((bad+1)); exit 2; }
CLEAN="$md5"   # what a from-scratch build of this unit produces, our reference

# ---------------------------------------------------------------- 2. control
# A good unit must still be USED, not rebuilt over.  Without this a compiler
# that ignored every .ppu and always rebuilt would score a perfect run.
total=$((total+1))
seed_and_run intact
if [ "$rc" != 0 ]; then
  echo "BROKEN $TARGET $UNIT.ppu intact -- rc=$rc, the compiler rejects a GOOD unit"
  bad=$((bad+1)); rc_final=1
elif [ "$md5" = "$CLEAN" ]; then
  echo "REBUILTGOOD $TARGET $UNIT.ppu intact -- the unit was rebuilt over instead of loaded, so no result below distinguishes anything"
  bad=$((bad+1)); rc_final=1
fi

# ------------------------------------------------------------- 3. zero byte
# Documented to SELF-HEAL: rebuilt from source, build green.
total=$((total+1))
seed_and_run zerobyte
if [ "$rc" != 0 ] || [ -z "$md5" ]; then
  echo "NOHEAL $TARGET $UNIT.ppu zero-byte -- rc=$rc, size=$size; a zero-byte unit is documented to rebuild from source"
  bad=$((bad+1)); rc_final=1
elif [ "$md5" != "$CLEAN" ]; then
  echo "HEALDIFFERS $TARGET $UNIT.ppu zero-byte -- healed to $md5 but a clean build gives $CLEAN"
  bad=$((bad+1)); rc_final=1
fi

# ------------------------------------------------------------- 4. truncated
# Documented to HARD-FAIL even with the source right there.  A short read is an
# error (v57) and the error is sticky, so the source fallback is never reached.
total=$((total+1))
seed_and_run truncated
hung=no
case "$rc" in
  124) echo "HANG $TARGET $UNIT.ppu truncated -- killed at 60s (pre-v57 behaviour)"
       hung=yes; bad=$((bad+1)); rc_final=1 ;;
    0) echo "SILENTACCEPT $TARGET $UNIT.ppu truncated -- rc=0, a partial unit was taken as valid or silently rebuilt over"
       bad=$((bad+1)); rc_final=1 ;;
esac

# --------------------------------------------------- 5. a plain retry is not it
# Three identical runs.  If any of them goes green, "delete the partial unit
# first" is the wrong advice and the notes must change.
#
# A compiler that HUNG in check 4 has already answered this -- a hang is not a
# recovery -- so re-running it three more times only buys three more 60s
# timeouts.  Measured: judging the pre-fix compiler took 4m02s with the loop
# and ~1m without it, against 0.7s for a healthy one.  A check that costs 350x
# more on a bad tree than a good one is a check people switch off.  The
# assertion still HOLDS in that case and still counts toward $total; it is not
# a problem, so it gets a lowercase note and no ALL-CAPS token.
total=$((total+1))
if [ "$hung" = yes ]; then
  echo "  (retry check: not re-run -- check 4 hung, and a hang is already not a recovery)"
else
  retry_went_green=no
  for i in 1 2 3; do
    compile_once
    [ "$rc" = 0 ] && retry_went_green=yes
  done
  if [ "$retry_went_green" = yes ]; then
    echo "RETRYHEALED $TARGET $UNIT.ppu truncated -- a plain re-run cleared it; the documented 'delete it first' advice is wrong"
    bad=$((bad+1)); rc_final=1
  fi
fi

# ------------------------------------------------ 6. deleting it DOES recover
# The payload of this whole check: a truncated unit is recoverable, and the
# recovery is one rm.
total=$((total+1))
rm -f "$U/$UNIT.ppu"
compile_once
if [ "$rc" != 0 ] || [ -z "$md5" ]; then
  echo "NORECOVERY $TARGET $UNIT.ppu -- deleting the partial unit did NOT let the build recover (rc=$rc, size=$size)"
  bad=$((bad+1)); rc_final=1
elif [ "$md5" != "$CLEAN" ]; then
  echo "RECOVERYDIFFERS $TARGET $UNIT.ppu -- recovered to $md5 but a clean build gives $CLEAN"
  bad=$((bad+1)); rc_final=1
fi

exit $rc_final
