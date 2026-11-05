#!/bin/bash
# Oracle and port default to this repo. Override ZINT and LUA_ZINT to point
# elsewhere. The system zint is an older release and is not the oracle.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ZINT:=$ROOT/vendor/zint/build/frontend/zint}"
: "${LUA_ZINT:=$ROOT/bin/lua-zint}"
export LC_ALL=C
# Differential test for the colour-option ordering fix in zint-lua-run.lua.
#
# Every ordering of the four options that write fgcolour/bgcolour is driven
# through both real zint and "$LUA_ZINT", and the SVGs are compared byte
# for byte. The point is the ORDER: before the fix, zint-lua-run.lua folded arg
# into a keyed table and the port applied a fixed precedence, so the two members
# of each reversed pair produced identical output where zint's differ.
set -uo pipefail
export LC_ALL=C

FG=--fg=00ff00
BG=--bg=FFEEDD
NB=--nobackground
RV=--reverse

run_case() { # id, then the option list
  local id="$1"; shift
  "$ZINT" -b 20 -d "TEST123" --filetype=SVG -o /tmp/a.svg "$@" >/dev/null 2>&1
  local rc_z=$?
  "$LUA_ZINT" -b 20 -d "TEST123" --filetype=SVG -o /tmp/b.svg "$@" >/dev/null 2>&1
  local rc_l=$?
  if [ "$rc_z" -ne "$rc_l" ]; then
    printf 'FAIL  %-52s exit %s vs %s\n' "$id" "$rc_z" "$rc_l"; return 1
  fi
  if [ "$rc_z" -ne 0 ]; then
    printf 'skip  %-52s both refused (%s)\n' "$id" "$rc_z"; return 0
  fi
  if cmp -s /tmp/a.svg /tmp/b.svg; then
    # report the colours actually produced, so a pair that matches for the
    # wrong reason (both wrong, identically) is still visible
    local fg bg
    fg=$(grep -o 'fill="#[0-9A-Fa-f]*"' /tmp/a.svg | sed -n 2p)
    bg=$(sed -n 's/.*<rect[^>]*fill="\([^"]*\)".*/\1/p' /tmp/a.svg | head -1)
    printf 'ok    %-52s bg=%-9s bar%s\n' "$id" "${bg:-none}" "${fg#fill=}"
    return 0
  fi
  printf 'FAIL  %-52s SVGs differ\n' "$id"
  diff <(head -8 /tmp/a.svg) <(head -8 /tmp/b.svg) | head -6
  return 1
}

bad=0; n=0
pairs=(
  "$FG $RV"          "$RV $FG"
  "$BG $NB"          "$NB $BG"
  "$FG $NB"          "$NB $FG"
  "$BG $RV"          "$RV $BG"
  "$RV $NB"          "$NB $RV"
  "$FG $BG"          "$BG $FG"
)
for c in "${pairs[@]}"; do
  n=$((n+1)); run_case "$c" $c || bad=$((bad+1))
done

echo
# all 24 permutations of the four
perm() {
  local a=("$@")
  if [ ${#a[@]} -eq 0 ]; then return; fi
}
for p in \
  "$RV $FG $BG $NB" "$RV $FG $NB $BG" "$RV $BG $FG $NB" "$RV $BG $NB $FG" \
  "$RV $NB $FG $BG" "$RV $NB $BG $FG" "$FG $RV $BG $NB" "$FG $RV $NB $BG" \
  "$FG $BG $RV $NB" "$FG $BG $NB $RV" "$FG $NB $RV $BG" "$FG $NB $BG $RV" \
  "$BG $RV $FG $NB" "$BG $RV $NB $FG" "$BG $FG $RV $NB" "$BG $FG $NB $RV" \
  "$BG $NB $RV $FG" "$BG $NB $FG $RV" "$NB $RV $FG $BG" "$NB $RV $BG $FG" \
  "$NB $FG $RV $BG" "$NB $FG $BG $RV" "$NB $BG $RV $FG" "$NB $BG $FG $RV" ; do
  n=$((n+1)); run_case "$p" $p || bad=$((bad+1))
done

echo
# repeats of the same option, and the verifier's own three-flag case
for p in "--fg=112233 --fg=445566" "--bg=112233 --bg=445566" \
         "--fg=203040 --bg=FAFAFA $NB" "$NB --bg=FAFAFA --fg=203040" \
         "$RV --fg=112233 $RV" "--bg=AABBCC $RV --bg=DDEEFF" ; do
  n=$((n+1)); run_case "$p" $p || bad=$((bad+1))
done

echo
printf '%d/%d byte-identical\n' "$((n-bad))" "$n"
exit $((bad > 0 ? 1 : 0))
