#!/bin/sh
# published-compiler-check.sh -- answer "which VibePascal compiler is inside the
# artifact a USER actually downloads", from the published bytes, not from the
# local file of the same name.
#
# WHY THIS EXISTS (cy1111).  cy1108 read the compiler out of
# ~/src/lazarus/releases/lazarus-4.99-vp-aarch64-darwin-20260910.tar.gz, found the
# predicted v56 digest, and recorded "the Apple Silicon bundle ships v56".  That
# local file was a 20:31 RE-ROLL that was never uploaded.  The asset on the
# release was uploaded at 19:35 and carries v55.  A release directory is a
# STAGING directory: the newest local file with a name is not the file with that
# name on the release.  Ask the API which bytes are published, then read THOSE.
#
# Needs no credentials: api.github.com serves public release metadata
# unauthenticated, and `gh` being logged out says nothing about that.
#
# Usage:
#   dist/published-compiler-check.sh <owner/repo> <release-tag> <asset-name> [candidate-dir ...]
#
# Prints the published asset's size/digest/upload time, extracts ONLY the
# compiler member (streamed -- a 350 MB asset costs ~7 s and no disk), hashes it,
# and if candidate staging dirs are given, ad-hoc signs each candidate under the
# SHIPPED FILENAME and reports which one the published bytes are.  Every
# candidate is printed whether it matches or not, so a match is a match against a
# field, not an unopposed guess.
#
# Example:
#   dist/published-compiler-check.sh adaloveless/lazarus \
#     lazarus-4.99-vp-20260818-r25 lazarus-4.99-vp-aarch64-darwin-20260910.tar.gz \
#     dist/darwin-native/vibepascal-native-aarch64-darwin-*
set -u

REPO="${1:?owner/repo}"; TAG="${2:?release tag}"; ASSET="${3:?asset name}"; shift 3

API="https://api.github.com/repos/$REPO/releases/tags/$TAG"

# Parse with python3, not sed.  A GitHub asset record embeds an "uploader": {...}
# OBJECT between "name" and "size", so any split-on-brace scheme reads the name
# from one fragment and the size from the next and silently returns nothing
# (measured cy1111 -- it printed blank fields and a wrong local-vs-published
# verdict, which is worse than failing).
META=$(curl -s -m 60 "$API" | ASSET="$ASSET" python3 -c '
import json,os,sys
try: rel=json.load(sys.stdin)
except Exception: sys.exit(2)
for a in rel.get("assets",[]):
    if a["name"]==os.environ["ASSET"]:
        print(a["size"]); print(a.get("digest","(none)")); print(a["updated_at"]); sys.exit(0)
sys.exit(3)')
case $? in
  2) echo "FAIL: API unreachable or not JSON"; exit 2;;
  3) echo "FAIL: no published asset named $ASSET on $TAG"; exit 2;;
esac
P_SIZE=$(printf '%s\n' "$META" | sed -n 1p)
P_DIG=$(printf  '%s\n' "$META" | sed -n 2p)
P_UPD=$(printf  '%s\n' "$META" | sed -n 3p)
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

echo "PUBLISHED  $ASSET"
echo "  size     $P_SIZE"
echo "  digest   $P_DIG"
echo "  uploaded $P_UPD   <-- anything staged AFTER this cannot be inside it"

LOCAL=$(ls -l "$HOME/src/lazarus/releases/$ASSET" 2>/dev/null | awk '{print $5}')
if [ -n "$LOCAL" ]; then
  if [ "$LOCAL" = "$P_SIZE" ]; then
    echo "  local    $HOME/src/lazarus/releases/$ASSET is $LOCAL B -- SAME SIZE, plausibly the published file"
  else
    echo "  local    $HOME/src/lazarus/releases/$ASSET is $LOCAL B -- DIFFERENT SIZE, it is NOT what shipped"
  fi
fi

# Which compiler binary this target's bundle carries.  Name it exactly: a bare
# '*/compiler/ppc*' also matches a ppcgen DIRECTORY and extracts zero bytes.
case "$ASSET" in
  *aarch64*)  MEMBER=ppca64;;
  *x86_64*)   MEMBER=ppcx64;;
  *-arm-*)    MEMBER=ppcarm;;
  *i386*)     MEMBER=ppc386;;
  *) echo "FAIL: cannot infer compiler name from $ASSET"; exit 2;;
esac

WORK=$(mktemp -d "${TMPDIR:-/tmp}/pubchk.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

# The .app copy always exists and is the hard-link TARGET; naming the top-level
# compiler/ppc* member can die with "Cannot hard link" when the .app came first.
# -v names the member on stderr while -O streams it to stdout, so ONE download
# answers both "what is it called" and "what is in it".  The name is load-bearing:
# rcodesign derives the Mach-O identifier from it when the binary embeds none.
# Take the FIRST occurrence of the name anywhere in the archive.  compiler/ppc*
# is a HARD LINK to the .app copy and only ONE of the two carries data; which one
# comes first differs per arch (x86_64 top-level first, aarch64 .app first), so
# naming a fixed path extracts 0 bytes on one of them (measured cy1111).
curl -sL -m 900 "$URL" 2>/dev/null \
  | tar xzOv --wildcards --occurrence=1 "*/compiler/$MEMBER" \
  > "$WORK/shipped" 2>"$WORK/name"

S_SIZE=$(ls -l "$WORK/shipped" | awk '{print $5}')
[ "${S_SIZE:-0}" -gt 0 ] || { echo "FAIL: no compiler member extracted"; exit 2; }
S_MD5=$(md5sum "$WORK/shipped" | awk '{print $1}')
S_NAME="$MEMBER"
echo "COMPILER INSIDE THE PUBLISHED ASSET"
echo "  member   ${S_NAME:-ppc?}"
echo "  size     $S_SIZE"
echo "  md5      $S_MD5"

[ $# -gt 0 ] || exit 0

echo "IDENTIFY -- ad-hoc signing each candidate under the shipped filename '${S_NAME:-ppc?}'"
# A MISSING TOOL IS NOT A PASS (cy1127).  This used to print a note and exit 0,
# which reads as "identification done" to anything checking the exit code, when
# in fact the step never ran.  Candidate dirs were asked for, so not being able
# to judge them is a harness failure -- exit 2, the code this script already uses
# for "could not measure", never 0 and never 1.
command -v rcodesign >/dev/null 2>&1 || {
  echo "  NOTHING WAS TESTED: rcodesign is not on PATH, so no candidate could be signed under the shipped filename and none was compared -- this says nothing about the published compiler"
  exit 2; }
rc=1
judged=0
for d in "$@"; do
  # Name a bad path rather than letting it vanish into an unmatched glob: a
  # staging dir here is named with a date AND a git sha, so a typo or a stale
  # glob is the likeliest way this script is ever pointed at nothing.
  [ -d "$d" ] || echo "  MISSING  $d -- not a directory, nothing in it could be judged"
  for cand in "$d"/bin/ppc* "$d"/ppc*; do
    [ -f "$cand" ] || continue
    case "$cand" in *.ppu|*.o) continue;; esac
    judged=$((judged+1))
    s=$(mktemp -d "${TMPDIR:-/tmp}/sign.XXXXXX")
    cp "$cand" "$s/${S_NAME:-$(basename "$cand")}" 2>/dev/null || { rm -rf "$s"; continue; }
    rcodesign sign "$s/${S_NAME:-$(basename "$cand")}" >/dev/null 2>&1
    m=$(md5sum "$s/${S_NAME:-$(basename "$cand")}" | awk '{print $1}')
    z=$(ls -l "$s/${S_NAME:-$(basename "$cand")}" | awk '{print $5}')
    if [ "$m" = "$S_MD5" ]; then
      echo "  MATCH    $cand  ($z B, $m)"
      rc=0
    else
      echo "  no       $cand  ($z B, $m)"
    fi
    rm -rf "$s"
  done
done
# A LOOP THAT JUDGED NOTHING MUST NOT REPORT A MISMATCH (cy1127, measured).
# Before this, an existing-but-empty candidate dir AND a candidate dir that does
# not exist at all both produced the SAME line -- "the published compiler came
# from bytes not in these dirs" at rc=1 -- which is a provenance alarm worth
# holding a release over, asserted after testing zero candidates.  A wrong path
# is the common case, not the rare one.  Distinct exit code, because rc=1 has to
# keep meaning "candidates were compared and none of them is it".
if [ "$judged" -eq 0 ]; then
  echo "  NOTHING WAS TESTED: no ppc* candidate file was found under any of the $# dir(s) given -- looked for '<dir>/bin/ppc*' and '<dir>/ppc*' in: $*"
  echo "  This says NOTHING about the published compiler.  Check the paths; a staging dir here is named with both a date and a git sha."
  exit 2
fi
[ $rc -eq 0 ] || echo "  NO CANDIDATE MATCHED ($judged candidate(s) signed and compared) -- the published compiler came from bytes not in these dirs"
exit $rc
