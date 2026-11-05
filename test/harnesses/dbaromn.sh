#!/bin/bash
# GS1 DataBar Omnidirectional (29) and Stacked Omnidirectional (80)
# against vendored zint 2.16.0.
# Stderr is compared only when both sides write an SVG. Exit codes are not compared.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ZINT:=$ROOT/vendor/zint/build/frontend/zint}"
: "${LUA_ZINT:=$ROOT/bin/lua-zint}"
export LC_ALL=C
pass=0; fail=0; failed=()

t() {
  local name="$1"; shift
  rm -f /tmp/l.svg /tmp/z.svg /tmp/l.err /tmp/z.err
  "$LUA_ZINT" "$@" --output /tmp/l.svg >/tmp/l.out 2>/tmp/l.err; lrc=$?
  "$ZINT" "$@" --output /tmp/z.svg >/tmp/z.out 2>/tmp/z.err; zrc=$?

  local lhas=0 zhas=0
  [ -f /tmp/l.svg ] && lhas=1
  [ -f /tmp/z.svg ] && zhas=1

  if [ "$lhas" != "$zhas" ]; then
    fail=$((fail+1)); failed+=("$name  [file: lua=$lhas zint=$zhas rc=$lrc/$zrc]"); return
  fi
  if [ "$lhas" = 1 ]; then
    if ! cmp -s /tmp/l.svg /tmp/z.svg; then
      fail=$((fail+1)); failed+=("$name  [svg bytes differ]"); return
    fi
    if ! diff -q /tmp/l.err /tmp/z.err >/dev/null; then
      fail=$((fail+1))
      failed+=("$name  [warning differs: '$(head -c 220 /tmp/l.err)' vs '$(head -c 220 /tmp/z.err)']")
      return
    fi
  fi
  pass=$((pass+1))
}

GTIN='09501101530003'
BODY='1234567890123'

t l-13        --barcode 29 --data "$BODY"
t l-14        --barcode 29 --data "$GTIN"
t l-1         --barcode 29 --data 1
t l-4         --barcode 29 --data 1234
t l-zero      --barcode 29 --data 0000000000000
t l-nine      --barcode 29 --data 9999999999999
t l-lead      --barcode 29 --data 0123456789012
t l-paren     --barcode 29 --data "(01)$GTIN"
t l-brack     --barcode 29 --data "[01]$GTIN"
t l-01-15     --barcode 29 --data "01${BODY}"
t l-01-16     --barcode 29 --data "01$GTIN"
t l-paren13   --barcode 29 --data "(01)$BODY"
t l-name      --barcode dbaromn --data "$BODY"
t l-name2     --barcode dbaromni --data "$BODY"
t l-name3     --barcode rss14 --data "$BODY"
t l-name4     --barcode databaromni --data "$BODY"
t l-notext    --barcode 29 --data "$BODY" --notext
t l-small     --barcode 29 --data "$BODY" --small
t l-bold      --barcode 29 --data 1234 --bold
t l-height    --barcode 29 --data "$BODY" --height 20
t l-comp      --barcode 29 --data "$BODY" --compliantheight
t l-comp-low  --barcode 29 --data "$BODY" --compliantheight --height 10
t l-scale     --barcode 29 --data "$BODY" --scale 1.5
t l-xdim      --barcode 29 --data "$BODY" --scalexdimdp 0.33
t l-qz        --barcode 29 --data "$BODY" --quietzones
t l-noqz      --barcode 29 --data "$BODY" --noquietzones
t l-box       --barcode 29 --data "$BODY" --box --border 2
t l-bind      --barcode 29 --data "$BODY" --bind --border 2
t l-ws        --barcode 29 --data "$BODY" --whitesp 3 --vwhitesp 2
t l-rev       --barcode 29 --data "$BODY" --reverse
t l-embed     --barcode 29 --data "$BODY" --embedfont
t l-init      --barcode 29 --data "$BODY" --init
t l-parens    --barcode 29 --data "$BODY" --gs1parens
t l-dotty     --barcode 29 --data "$BODY" --dotty

t s-13        --barcode 80 --data "$BODY"
t s-14        --barcode 80 --data "$GTIN"
t s-paren     --barcode 80 --data "(01)$GTIN"
t s-01        --barcode 80 --data "01$GTIN"
t s-name      --barcode dbaromnstk --data "$BODY"
t s-name2     --barcode rss14stackomni --data "$BODY"
t s-name3     --barcode databarstackedomni --data "$BODY"
t s-notext    --barcode 80 --data "$BODY" --notext
t s-height    --barcode 80 --data "$BODY" --height 80
t s-hpr       --barcode 80 --data "$BODY" --heightperrow --height 40
t s-comp      --barcode 80 --data "$BODY" --compliantheight
t s-comp-low  --barcode 80 --data "$BODY" --compliantheight --height 20
t s-bind      --barcode 80 --data "$BODY" --bind --border 1
t s-rev       --barcode 80 --data "$BODY" --reverse
t s-embed     --barcode 80 --data "$BODY" --embedfont
t s-qz        --barcode 80 --data "$BODY" --quietzones

for r in 0 90 180 270; do
  t "l-r-$r"  --barcode 29 --data "$BODY" --rotate "$r"
  t "s-r-$r"  --barcode 80 --data "$BODY" --rotate "$r"
done

# Spread of values so the finder-value-3 separator is in the suite.
for i in 0 3 7 11 18 24 33 41 55 72 80; do
  d=$(printf '%013d' $((i * 1234567)))
  t "sweep-$i" --barcode 80 --data "$d"
done

# Both sides refuse. The message text is not compared.
t e-empty     --barcode 29 --data ""
t e-long      --barcode 29 --data 123456789012345
t e-alpha     --barcode 29 --data 12A456
t e-space     --barcode 29 --data "12345 7890123"
t e-bad14     --barcode 29 --data 09501101530000
t e-paren-bad --barcode 80 --data '(01)09501101530000'
t e-gs1       --barcode 29 --data "$BODY" --gs1
t e-stk-empty --barcode 80 --data ""

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
