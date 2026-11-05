#!/bin/bash
# UPC-E (37) and UPC-E with check digit (38) against vendored zint 2.16.0.
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
    fail=$((fail+1)); failed+=("$name  [file: lua=$lhas zint=$zhas]"); return
  fi
  if [ "$lhas" = 1 ]; then
    if ! cmp -s /tmp/l.svg /tmp/z.svg; then
      fail=$((fail+1)); failed+=("$name  [svg bytes differ]"); return
    fi
    if ! diff -q /tmp/l.err /tmp/z.err >/dev/null; then
      fail=$((fail+1))
      failed+=("$name  [warning differs: '$(head -c 180 /tmp/l.err)' vs '$(head -c 180 /tmp/z.err)']")
      return
    fi
  fi
  pass=$((pass+1))
}

# Six digits, number system inserted as 0. Seven digits carry the system.
t v-6            --barcode 37 --data 123456
t v-5            --barcode 37 --data 12345
t v-7ns0         --barcode 37 --data 0123456
t v-7ns1         --barcode 37 --data 1234567
t v-8check       --barcode 37 --data 12345670
t v-byname       --barcode UPCE --data 0123456
t v-chk-name     --barcode upcechk --data 12345670
t v-chk6         --barcode 38 --data 123457
t v-chk5         --barcode 38 --data 12344
t v-rules        --barcode 37 --data 123455
t v-rule4        --barcode 37 --data 456784
t v-rule3        --barcode 37 --data 345670
t v-zero         --barcode 37 --data 000000
t v-gtin         --barcode 37 --data 0001234000057
t v-gtin2        --barcode 37 --data 012345600007012
t v-gtin5        --barcode 37 --data 012345600007012345
t v-ignore       --barcode 37 --data 2345678
t v-ignore-chk   --barcode 38 --data 23456781
t v-ignore-h     --barcode 37 --data 2345678 --compliantheight --height 20

t a-2            --barcode 37 --data 123456+12
t a-5            --barcode 37 --data 0123456+12345
t a-space        --barcode 37 --data "123456 99"
t a-notext       --barcode 37 --data 123456+12 --notext
t a-empty        --barcode 37 --data 123456+
t a-6            --barcode 37 --data 123456+123456

t e-bad3         --barcode 37 --data 120453
t e-bad4         --barcode 37 --data 123054
t e-bad5         --barcode 37 --data 123405
t e-chk          --barcode 38 --data 12345678
t e-long         --barcode 37 --data 123456789
t e-alpha        --barcode 37 --data 12345A
t e-twoplus      --barcode 37 --data 123456+12+3
t e-empty        --barcode 37 --data ""

t l-notext       --barcode 37 --data 123456 --notext
t l-small        --barcode 37 --data 123456 --small
t l-bold         --barcode 37 --data 123456 --bold
t l-height20     --barcode 37 --data 123456 --height 20
t l-compliant    --barcode 37 --data 123456 --compliantheight
t l-comp-h20     --barcode 37 --data 123456 --compliantheight --height 20
t l-scale        --barcode 37 --data 123456 --scale 1.5
t g-descent      --barcode 37 --data 123456 --guarddescent 12
t g-textgap      --barcode 37 --data 123456 --textgap -5 --guarddescent 8
t b-box          --barcode 37 --data 123456 --box --border 2
t b-bind         --barcode 37 --data 123456 --bind --border 2
t b-noquiet      --barcode 37 --data 123456 --noquietzones
t b-noquiet-nt   --barcode 37 --data 123456 --noquietzones --notext
t b-noquiet-add  --barcode 37 --data 123456+12 --noquietzones
t b-whitesp      --barcode 37 --data 123456 --whitesp 3 --vwhitesp 2

for r in 0 90 180 270; do
  t "r-$r"       --barcode 37 --data 123456 --rotate "$r"
done
t r-addon        --barcode 37 --data 123456+12345 --rotate 270

t k-embed        --barcode 37 --data 123456 --embedfont
t k-ns1          --barcode 37 --data 1234567 --embedfont
t x-dotty        --barcode 37 --data 123456 --dotty
t w-reverse      --barcode 37 --data 123456 --reverse
t w-xdim         --barcode 37 --data 123456 --scalexdimdp 0.33
t w-both         --barcode 38 --data 12345670 --small --box --border 1 --rotate 90

for i in $(seq 1 15); do
  d=$(head -c 40 /dev/urandom | tr -dc '0-9' | head -c 6)
  t "rnd-$i"     --barcode 37 --data "$d"
done

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
