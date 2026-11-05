#!/bin/bash
# Oracle and port default to this repo. Override ZINT and LUA_ZINT to point
# elsewhere. The system zint is an older release and is not the oracle.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ZINT:=$ROOT/vendor/zint/build/frontend/zint}"
: "${LUA_ZINT:=$ROOT/bin/lua-zint}"
export LC_ALL=C
# Compare real zint against the Lua port over the verifier's case shapes.
# Usage: fuzz.sh <rounds> <case-glob>
set -uo pipefail
export LC_ALL=C
ROUNDS="${1:-5}"
FILTER="${2:-*}"

UP=ABCDEFGHIJKLMNOPQRSTUVWXYZ
LO=abcdefghijklmnopqrstuvwxyz
DI=0123456789

rnd() { # rnd <charset> <n>
  local set="$1" n="$2" out="" i
  for ((i=0;i<n;i++)); do out+="${set:RANDOM%${#set}:1}"; done
  printf '%s' "$out"
}

mod10() { # GS1 mod-10 over an odd-length body
  local body="$1" total=0 i d w
  for ((i=0;i<${#body};i++)); do
    d=${body:i:1}; (( w = (i % 2 == 0) ? 3 : 1 )); (( total += d * w ))
  done
  printf '%s' $(( (10 - total % 10) % 10 ))
}
gtin14() { local b; b=$(rnd "$DI" 13); printf '%s%s' "$b" "$(mod10 "$b")"; }

gen() { # gen <shape>
  local c
  case "$1" in
    code39_alnum)    printf '%s-%s' "$(rnd "$UP$DI" 4)" "$(rnd "$UP$DI" 3)" ;;
    code39_digits)   rnd "$DI" 12 ;;
    code39_letters)  rnd "$UP" 10 ;;
    code39_symbols)  c=$(rnd "$UP" 7)
                     printf '%s %s.%s$%s/%s+%s%%%s' \
                       "${c:0:1}" "${c:1:1}" "${c:2:1}" "${c:3:1}" \
                       "${c:4:1}" "${c:5:1}" "${c:6:1}" ;;
    code39_single)   rnd "$UP" 1 ;;
    code39_long)     rnd "$UP$DI" 30 ;;
    code128_mixed)   printf '%s-%s%s' "$(rnd "$UP$DI" 3)" "$(rnd "$LO" 3)" "$(rnd "$DI" 2)" ;;
    code128_deven)   rnd "$DI" 20 ;;
    code128_dodd)    rnd "$DI" 15 ;;
    code128_lower)   rnd "$LO" 12 ;;
    code128_upper)   rnd "$UP" 12 ;;
    code128_punct)   printf '%s!%s#%s&*+,.:;=?@%s' \
                       "$(rnd "$UP" 2)" "$(rnd "$LO" 2)" "$(rnd "$DI" 2)" "$(rnd "$UP" 2)" ;;
    code128_d2text)  printf '%s%s%s' "$(rnd "$DI" 10)" "$(rnd "$UP" 2)" "$(rnd "$LO" 2)" ;;
    code128_long)    printf '%s-%s-%s' "$(rnd "$UP$DI" 12)" "$(rnd "$LO" 12)" "$(rnd "$DI" 12)" ;;
    gs1_two)         printf '[01]%s[10]%s' "$(gtin14)" "$(rnd "$UP$DI" 5)" ;;
    gs1_single)      printf '[01]%s' "$(gtin14)" ;;
    gs1_three)       printf '[01]%s[10]%s[21]%s' "$(gtin14)" "$(rnd "$UP$DI" 5)" "$(rnd "$UP$DI" 6)" ;;
    gs1_fixed)       printf '[01]%s[17]%02d%02d%02d' "$(gtin14)" \
                       $((26 + RANDOM % 4)) $((1 + RANDOM % 12)) $((1 + RANDOM % 28)) ;;
    gs1_varonly)     printf '[10]%s' "$(rnd "$UP$DI" 8)" ;;
    gs1_parens)      printf '(01)%s(10)%s' "$(gtin14)" "$(rnd "$UP$DI" 5)" ;;
    *) echo "unknown shape $1" >&2; exit 2 ;;
  esac
}

# id|shape|barcode ("-" omits -b entirely)|extra args (space separated, "-" for none)
CASES='
code39-plain|code39_alnum|8|-
code39-digits|code39_digits|8|-
code39-letters|code39_letters|8|-
code39-symbols|code39_symbols|8|-
code39-single-char|code39_single|8|-
code39-long|code39_long|8|-
code39-by-name|code39_alnum|CODE39|-
code39-fg-rgb|code39_alnum|8|--fg=112233
code39-fg-cmyk|code39_alnum|8|--fg=0,0,0,100
code39-fg-bg|code39_letters|8|--fg=003366 --bg=FFFFCC
code128-plain|code128_mixed|20|-
code128-digits-even|code128_deven|20|-
code128-digits-odd|code128_dodd|20|-
code128-lower|code128_lower|20|-
code128-upper|code128_upper|20|-
code128-punctuation|code128_punct|20|-
code128-digits-to-text|code128_d2text|20|-
code128-long|code128_long|20|-
code128-by-name|code128_mixed|CODE128|-
code128-default|code128_mixed|-|-
code128-bg-rgb|code128_mixed|20|--bg=EEDDCC
code128-bg-cmyk|code128_mixed|20|--bg=0,0,20,0
code128-fg-bg|code128_mixed|20|--fg=203040 --bg=FAFAFA
code128-fg-nobg|code128_mixed|20|--fg=203040 --nobackground
gs1_128-plain|gs1_two|16|-
gs1_128-single-ai|gs1_single|16|-
gs1_128-three-ais|gs1_three|16|-
gs1_128-fixed-ais|gs1_fixed|16|-
gs1_128-variable-ai|gs1_varonly|16|-
gs1_128-by-name|gs1_two|GS1_128|-
gs1_128-parens|gs1_parens|16|--gs1parens
gs1_128-fg-bg|gs1_two|16|--fg=1A2B3C --bg=F0F0F0
gs1_128-nobackground|gs1_three|16|--fg=330000 --nobackground
'

pass=0; fail=0
for ((r=0;r<ROUNDS;r++)); do
  while IFS='|' read -r id shape bc extra; do
    [ -z "$id" ] && continue
    case "$id" in $FILTER) ;; *) continue ;; esac
    data=$(gen "$shape")
    args=(); [ "$extra" != "-" ] && read -ra args <<< "$extra"
    bcargs=(); [ "$bc" != "-" ] && bcargs=(-b "$bc")
    rm -f /tmp/a.svg /tmp/b.svg
    "$ZINT" "${bcargs[@]}" -d "$data" --filetype=SVG -o /tmp/a.svg "${args[@]}" >/dev/null 2>&1
    "$LUA_ZINT" "${bcargs[@]}" -d "$data" --filetype=SVG -o /tmp/b.svg "${args[@]}" >/tmp/err.txt 2>&1
    if cmp -s /tmp/a.svg /tmp/b.svg; then
      pass=$((pass+1))
    else
      fail=$((fail+1))
      echo "FAIL $id  data=[$data] ${args[*]}"
      [ -s /tmp/err.txt ] && sed 's/^/      lua: /' /tmp/err.txt | head -5
      diff <(fold -w110 /tmp/a.svg) <(fold -w110 /tmp/b.svg) | head -8 | sed 's/^/      /'
    fi
  done <<< "$CASES"
done
echo "pass=$pass fail=$fail"
exit $((fail > 0 ? 1 : 0))
