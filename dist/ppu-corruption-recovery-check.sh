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

# ADDRESS-SPACE CAP FOR THE COMPILER UNDER TEST -- HOST SAFETY, NOT TIDINESS.
# Measured cy1127 with /usr/bin/time -v: on the pre-fix compiler a truncated unit
# does not merely spin, it allocates about 54 MB/s and never frees (3.0 GB in
# 55 s), and this gate's truncated arm gives it a SIXTY second window -- ~3.2 GB
# in one arm, on a host where the OOM killer really did fire on 2026-09-11 and
# took a 13.5 GB compiler with it.  A killed build and a compiler defect look
# identical in a log, so a gate that can cause one is worse than no gate.
# 1 GB is ~60x the measured peak of a healthy run (17 MB; every arm here
# compiles the same three-line program), so it cannot fail a legitimate compile.
VMCAP=${RECOVERYCHECK_VMCAP_KB:-1048576}
if ( ulimit -v "$VMCAP" ) 2>/dev/null; then
  CAPPED=yes
else
  CAPPED=no
  echo "recoverycheck: WARNING cannot set a ${VMCAP} kB address-space cap on this host -- the compiler under test runs UNBOUNDED, and a leaking compiler can OOM this box" >&2
fi

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
  out=$(cd "$SCRATCH" || exit 2
        [ "$CAPPED" = yes ] && ulimit -v "$VMCAP"
        timeout 60 "$PPC" -n -s -T"$OS" -P"$CPU" -Cn \
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
# WHAT THIS ARM EXPECTS CHANGED UNDER US, AND THE GATE WAS THE LAST TO HEAR
# (cy1127).  It was written for v57, where a short read was a STICKY error: a
# truncated unit hard-failed even with the source right there, and this arm
# scored anything else as a problem.  v58's whole-file length check
# (dedf242c69, tppufile.readheader) compares the physical length against the one
# the header declares, which lands BEFORE the sticky-error path -- so the unit
# is now treated as unusable rather than unreadable, and the compiler falls
# through to the source exactly as it does for a zero-byte one.
# Measured here, three arms, single axis (is the source reachable):
#   unit absent                      -> rc=0, rebuilt, md5 a07199db..(55291 B)
#   truncated 120 B, source on path  -> rc=0, SELF-HEALS to that same md5
#   truncated 120 B, source hidden   -> rc=1, file left at 120 B, hard stop
# So the hard stop is real but it is now the NO-SOURCE case only.  Left alone,
# this arm reported the healthy shipped compiler as two problems and exited 1 --
# a gate that fails on a good tree gets switched off, and then it is not a gate.
# The heal is still verified against $CLEAN: "it rebuilt something" is not the
# same as "it rebuilt the right thing".
total=$((total+1))
seed_and_run truncated
hung=no
# THE LEAK IS SCORED ON THE MESSAGE, NOT ON rc, AND THAT ORDER IS LOAD-BEARING.
# Under the cap, running out of address space ends the SAME defect two ways
# (measured cy1127 on the sibling gate): rc=217 with ZERO output, or rc=1 with
# "Fatal: No memory left" -- and rc=1-with-a-message is exactly what a CORRECT
# refusal looks like here, so scoring on rc alone reads a leak as a clean pass.
# Before this, check 4 scored ONLY 124 and 0, so every leak that ended either of
# those two ways counted as clean.  Only "No memory left" is matched, not the
# "raised exception internally" line that sometimes accompanies it: that one is
# emitted for any internal exception and would relabel unrelated defects.
leaked=no
case "$out" in *"No memory left"*) leaked=yes ;; esac
case "$rc" in 203|217) leaked=yes ;; esac
if [ "$leaked" = yes ]; then
  echo "LEAK $TARGET $UNIT.ppu truncated -- rc=$rc, the compiler exhausted the ${VMCAP} kB address-space cap instead of refusing the unit (UNCAPPED this is the 13.5 GB shape that gets a build OOM-killed)"
  hung=yes; bad=$((bad+1)); rc_final=1
else
case "$rc" in
  124) echo "HANG $TARGET $UNIT.ppu truncated -- killed at 60s (pre-v57 behaviour)"
       hung=yes; bad=$((bad+1)); rc_final=1 ;;
    0) if [ "$md5" = "$CLEAN" ]; then
         echo "  (truncated: self-healed from source to the clean md5 $md5 -- v58 behaviour, and it prints Error: lines while exiting 0, so do not gate on log text)"
       else
         echo "HEALDIFFERS $TARGET $UNIT.ppu truncated -- healed to ${md5:-<no unit>} but a clean build gives $CLEAN"
         bad=$((bad+1)); rc_final=1
       fi ;;
    *) echo "NOHEAL $TARGET $UNIT.ppu truncated -- rc=$rc with the source on the path and size=$size; that is the pre-v58 sticky hard stop, so either the length check is gone or the source fallback is"
       bad=$((bad+1)); rc_final=1 ;;
esac
fi

# ------------------------------------------- 5. is the heal REPEATABLE, not luck
# THIS CHECK USED TO ASK THE OPPOSITE QUESTION AND IT HAD TO BE RE-AIMED, NOT
# JUST RE-WORDED (cy1127).  Under v57 it ran three more compiles WITHOUT
# re-seeding, because a truncated unit stayed truncated: any green run meant "a
# plain retry cleared it" and the documented delete-it-first advice was wrong.
# Under v58 check 4 heals the unit, so the file on disk is already GOOD by the
# time this runs -- three more compiles against a healthy unit assert nothing,
# and the old scoring turned the intended heal into a RETRYHEALED problem.
# The question worth asking now is whether the heal is STABLE: seed the damage
# again each time and require the same clean md5 every time, so a heal that
# works once and flaps is caught.
#
# A compiler that HUNG or LEAKED in check 4 has already answered this -- neither
# is a recovery -- so re-running only buys three more 60s windows.  Measured:
# judging the pre-fix compiler took 4m02s with the loop and ~1m without it,
# against 0.7s for a healthy one.  A check that costs 350x more on a bad tree
# than a good one is a check people switch off.  The assertion still HOLDS in
# that case and still counts toward $total; it is not a problem, so it gets a
# lowercase note and no ALL-CAPS token.
total=$((total+1))
if [ "$hung" = yes ]; then
  echo "  (repeat check: not re-run -- check 4 hung or leaked, and neither is a recovery)"
else
  flapped=no
  for i in 1 2 3; do
    seed_and_run truncated
    { [ "$rc" = 0 ] && [ "$md5" = "$CLEAN" ]; } || flapped="run $i: rc=$rc md5=${md5:-<no unit>}"
  done
  if [ "$flapped" != no ]; then
    echo "RETRYFLAPS $TARGET $UNIT.ppu truncated -- the self-heal is not repeatable ($flapped), and an intermittent recovery is not one you can document"
    bad=$((bad+1)); rc_final=1
  else
    echo "  (repeat check: seeded and healed 3/3 times, same md5 each time)"
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
