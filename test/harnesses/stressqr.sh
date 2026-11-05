#!/bin/bash
# Oracle and port default to this repo. Override ZINT and LUA_ZINT to point
# elsewhere. The system zint is an older release and is not the oracle.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ZINT:=$ROOT/vendor/zint/build/frontend/zint}"
: "${LUA_ZINT:=$ROOT/bin/lua-zint}"
export LC_ALL=C
# QR Code stress. Unlike the linear symbologies, QR has four places it can be
# subtly wrong without failing loudly, so the axes here are chosen to hit each:
#
#   mode optimiser  -- transitions between N/A/B, and the run lengths that make
#                      the DP prefer one segment over two
#   version choice  -- the CCI width steps at versions 10 and 27, the shrink
#                      loop, and the ECC auto-boost from L up to H
#   Reed-Solomon    -- block counts from 1 to 81, and the short/long block split
#   mask selection  -- all eight patterns, especially 7 (the grid-reuse path)
#
# plus GS1 mode, which threads through all four.
set -uo pipefail
export LC_ALL=C
ROUNDS="${1:-1}"

UP=ABCDEFGHIJKLMNOPQRSTUVWXYZ
LO=abcdefghijklmnopqrstuvwxyz
AN=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
DI=0123456789
# QR's alphanumeric set is exactly these 45 characters.
AL='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 $%*+-./:'

rnd() { local set="$1" n="$2" out="" i
  for ((i=0;i<n;i++)); do out+="${set:RANDOM%${#set}:1}"; done; printf '%s' "$out"; }

mod10() { local body="$1" total=0 i d w
  for ((i=0;i<${#body};i++)); do d=${body:i:1}; (( w = (i % 2 == 0) ? 3 : 1 )); (( total += d * w )); done
  printf '%s' $(( (10 - total % 10) % 10 )); }
gtin14() { local b; b=$(rnd "$DI" 13); printf '%s%s' "$b" "$(mod10 "$b")"; }
sscc18() { local b; b=$(rnd "$DI" 17); printf '%s%s' "$b" "$(mod10 "$b")"; }
date6()  { printf '%02d%02d%02d' $((26 + RANDOM % 4)) $((1 + RANDOM % 12)) $((1 + RANDOM % 28)); }

pass=0; fail=0; skip=0
declare -A MASKSEEN VERSEEN ECCSEEN

check() { # check <label> <data> [extra args...]
  local label="$1" data="$2"; shift 2
  rm -f /tmp/a.svg /tmp/b.svg
  "$ZINT" -b 58 -d "$data" --filetype=SVG -o /tmp/a.svg "$@" >/dev/null 2>&1
  # zint refuses some inputs (too long, bad GS1). Not our problem: skip.
  if [ ! -s /tmp/a.svg ]; then skip=$((skip+1)); return; fi

  # Record which version / ECC level / mask this case actually exercised, so
  # the run can report its own coverage rather than being trusted blind.
  local vinfo
  vinfo=$("$ZINT" -b 58 -d "$data" --filetype=SVG -o /dev/null --verbose "$@" 2>&1 \
          | grep -E "^Selected version:|^Mask:" || true)
  local sv ms
  sv=$(sed -n 's/^Selected version: \([0-9]*\)-\([LMQH]\).*/\1 \2/p' <<<"$vinfo")
  ms=$(sed -n 's/^Mask: \([0-9]\).*/\1/p' <<<"$vinfo")
  [ -n "$sv" ] && { VERSEEN[${sv% *}]=1; ECCSEEN[${sv#* }]=1; }
  [ -n "$ms" ] && MASKSEEN[$ms]=1

  "$LUA_ZINT" -b 58 -d "$data" --filetype=SVG -o /tmp/b.svg "$@" >/tmp/err.txt 2>&1
  if cmp -s /tmp/a.svg /tmp/b.svg; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL $label  data=[${data:0:60}] $*"
    [ -s /tmp/err.txt ] && sed 's/^/      lua: /' /tmp/err.txt | head -3
    diff <(fold -w110 /tmp/a.svg) <(fold -w110 /tmp/b.svg) | head -6 | sed 's/^/      /'
  fi
}

for ((round=1; round<=ROUNDS; round++)); do

  # ---- the verifier's own shapes, so a regression there shows up here first
  check v-tiny       "$(rnd "$AN" 4)"
  check v-url        "https://example.invalid/$(rnd "$AN" 6)"
  check v-numeric    "$(rnd "$DI" 40)"
  c=$(rnd "$AN" 10)
  check v-alnum      "${c:0:3} ${c:3:3}-${c:6:2}.${c:8:1}/${c:9:1}:00"
  check v-byte-mixed "$(rnd "$LO" 40) $(rnd "$AN" 20) $(rnd "$DI" 20)"
  large=""; for i in $(seq 44); do large+="$(rnd "$LO" 8) "; done
  check v-large      "${large% }"
  xlarge=""; for i in $(seq 100); do xlarge+="$(rnd "$AN" 11) "; done
  check v-xlarge     "${xlarge% }"

  # ---- version walk. Numeric data of growing length steps through every
  # version, and with it every CCI width, every block count, and both sides of
  # the short/long block split.
  # The step sizes are deliberately uneven at the low end (where one digit
  # changes the version) and coarser at the top (where it takes dozens).
  for n in 1 2 3 4 5 6 7 8 9 10 11 15 16 17 26 27 28 34 35 40 41 42 50 60 \
           64 65 76 77 78 90 100 110 122 150 178 200 216 250 260 300 310 350 \
           365 400 425 450 490 500 560 600 640 700 720 800 810 900 910 1000 \
           1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 2200 2400 2600 \
           2800 3000 3200 3400 3600 3800 4000 4100 4200 4290 4295 4296 \
           4420 4700 4980 5260 5540 5860 6180 6500 6780 7080 7089 7090; do
    check "num-$n" "$(rnd "$DI" "$n")"
  done

  # ---- alphanumeric walk. Different CCI widths and a different cost model, so
  # the version boundaries land at different lengths than the numeric ones.
  for n in 1 2 3 4 5 9 10 11 20 25 26 27 47 48 49 100 200 400 800 1600 2000 \
           2300 2330 2335; do
    check "alnum-$n" "$(rnd "$AL" "$n")"
  done

  # ---- byte mode walk, including the CCI jump from 8 to 16 bits at version 10.
  for n in 1 2 3 16 17 18 100 200 500 1000 1500 2000 2800 2950 2953; do
    check "byte-$n" "$(rnd "$LO" "$n")"
  done

  # ---- mode transitions. The DP has to decide whether a short run is worth a
  # mode switch; these sit either side of the break-even point.
  for k in 1 2 3 4 5 6 7 8 9 10 12 15 20; do
    check "n-in-a-$k"  "ABC$(rnd "$DI" $k)DEF"
    check "a-in-n-$k"  "$(rnd "$DI" 20)$(rnd "$UP" $k)$(rnd "$DI" 20)"
    check "b-in-a-$k"  "ABCDEF$(rnd "$LO" $k)GHIJKL"
    check "b-in-n-$k"  "$(rnd "$DI" 20)$(rnd "$LO" $k)$(rnd "$DI" 20)"
    check "n-in-b-$k"  "$(rnd "$LO" 12)$(rnd "$DI" $k)$(rnd "$LO" 12)"
    check "a-in-b-$k"  "$(rnd "$LO" 12)$(rnd "$UP" $k)$(rnd "$LO" 12)"
  done

  # ---- alternating modes, which make the DP's read-after-write in the
  # mode-switch loop observable.
  check alt-2  "1a2b3c4d5e6f7g8h9i0j"
  check alt-3  "12a34b56c78d90e12f34g"
  check alt-an "1A2A3A4A5A6A7A8A9A0A"
  check alt-na "A1A1A1A1A1A1A1A1A1A1A1A1"
  check alt-mix "aA1 bB2 cC3 dD4 eE5 fF6 gG7 hH8"

  # ---- every character of the alphanumeric set, and the punctuation that is
  # NOT in it (which must therefore fall to byte mode).
  check alpha-all   "$AL"
  check alpha-punct ' $%*+-./:'
  check byte-punct  '!"#&(),;<=>?@[]^_`{|}~'
  check pct-1       'AB%CD'
  check pct-2       'AB%%CD'
  check pct-3       '%%%%%%'
  check pct-lead    '%ABCDEF'
  check pct-trail   'ABCDEF%'

  # ---- Latin-1. One byte after the fold, so still byte mode, but a different
  # byte than the UTF-8 that was typed.
  check latin1-1 "café"
  check latin1-2 "naïve résumé $(rnd "$LO" 10)"
  check latin1-3 "£100 ± 5° ÷ 2 × ½"
  check latin1-hi "$(printf '\xc3\xbf\xc3\xbe\xc3\xbd')"

  # ---- GS1 mode. The reduction runs in the driver for QR (unlike GS1-128),
  # and then threads through the cost model, the CCIs and the bit packing.
  check gs1-single   "[01]$(gtin14)"                                        --gs1
  check gs1-two      "[01]$(gtin14)[10]$(rnd "$AN" 5)"                      --gs1
  check gs1-three    "[01]$(gtin14)[10]$(rnd "$AN" 5)[21]$(rnd "$AN" 6)"    --gs1
  check gs1-fixed    "[01]$(gtin14)[17]$(date6)"                            --gs1
  check gs1-varonly  "[10]$(rnd "$AN" 8)"                                   --gs1
  check gs1-sscc     "[00]$(sscc18)"                                        --gs1
  check gs1-numeric  "[01]$(gtin14)[30]$(rnd "$DI" 6)"                      --gs1
  check gs1-lower    "[01]$(gtin14)[10]$(rnd "$LO" 8)"                      --gs1
  check gs1-parens   "(01)$(gtin14)(10)$(rnd "$AN" 5)"                      --gs1 --gs1parens
  check gs1-long     "[01]$(gtin14)[10]$(rnd "$AN" 20)[21]$(rnd "$AN" 20)[240]$(rnd "$AN" 30)" --gs1
  # The percent path: a literal % must be doubled in alphanumeric mode, which
  # flips the pairing parity of everything after it. Nothing in the verifier
  # reaches this, and it is the single most intricate branch in the encoder.
  check gs1-pct-1    "[01]$(gtin14)[10]AB%CD"                               --gs1
  check gs1-pct-2    "[01]$(gtin14)[10]AB%%CD"                              --gs1
  check gs1-pct-3    "[01]$(gtin14)[10]%%%%"                                --gs1
  check gs1-pct-4    "[01]$(gtin14)[10]A%B%C%D%"                            --gs1
  check gs1-pct-5    "[01]$(gtin14)[10]%A%B%C%"                             --gs1
  check gs1-pct-6    "[10]%"                                                --gs1
  check gs1-pct-7    "[10]%%"                                               --gs1
  check gs1-pct-8    "[10]$(rnd "$AN" 3)%$(rnd "$AN" 3)%$(rnd "$AN" 3)"     --gs1
  # Growing GS1 payloads, to push the version up while GS1 mode is on.
  for n in 4 8 12 16 20 24 30 40 60 80; do
    check "gs1-grow-$n" "[01]$(gtin14)[10]$(rnd "$AN" 8)[240]$(rnd "$AN" $n)" --gs1
  done

  # ---- output flags, which sit downstream of the encoder but read its grid.
  url="https://example.invalid/$(rnd "$AN" 6)"
  check f-fg-rgba     "$url" --fg=11223380
  check f-bg-rgba     "$url" --bg=CCDDEE40
  check f-nobg        "$url" --nobackground
  check f-scale       "$url" --scale=2.5
  check f-border      "$url" --border=4 --box
  check f-bind        "$url" --bind --borderwidth=3
  check f-whitesp     "$url" --whitesp=3 --vwhitesp=2
  check f-quiet       "$url" --quietzones
  check f-noquiet     "$url" --noquietzones
  check f-dotty       "$url" --dotty
  check f-dotty2      "$url" --dotty --dotsize=0.6
  check f-reverse     "$url" --reverse
  check f-rotate      "$url" --rotate=90
  check f-rotate2     "$url" --rotate=180
  check f-rotate3     "$url" --rotate=270
  check f-height      "$url" --height=40
  check f-compliant   "$url" --compliantheight
  check f-combo       "$url" --scale=3 --border=2 --box --fg=102030 --bg=ABCDEF --quietzones

  # ---- the by-name spelling, and the check-digit-free alias
  check name-1 "$url" -b QRCODE 2>/dev/null
  check name-2 "$url"

done

echo "stressqr    pass=$pass fail=$fail skip=$skip"
printf 'coverage    masks:'; for m in 0 1 2 3 4 5 6 7; do
  [ -n "${MASKSEEN[$m]:-}" ] && printf ' %s' "$m" || printf ' -'; done
printf '  ecc:'; for e in L M Q H; do
  [ -n "${ECCSEEN[$e]:-}" ] && printf ' %s' "$e" || printf ' -'; done
printf '  versions: %d/40' "${#VERSEEN[@]}"
missed=""; for v in $(seq 1 40); do [ -z "${VERSEEN[$v]:-}" ] && missed+=" $v"; done
[ -n "$missed" ] && printf ' (missed:%s)' "$missed"
printf '\n'
[ "$fail" -eq 0 ]
