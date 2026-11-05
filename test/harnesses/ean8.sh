#!/bin/bash
# EAN-8 against vendored zint 2.16.0. Same contract as ean13.sh.
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
      failed+=("$name  [warning differs: '$(head -c 160 /tmp/l.err)' vs '$(head -c 160 /tmp/z.err)']")
      return
    fi
  fi
  pass=$((pass+1))
}

t v-7            --barcode 10 --data 1234567
t v-8good        --barcode 10 --data 12345670
t v-8bad         --barcode 10 --data 12345671
t v-byname       --barcode EAN8 --data 5512345
t v-short        --barcode 10 --data 1234
t v-one          --barcode 10 --data 7
t v-zero         --barcode 10 --data 0000000
t v-nines        --barcode 10 --data 9999999
t v-fgbg         --barcode 10 --data 1234567 --fg 000080 --bg FFFFF0

for i in $(seq 0 9); do
  t "d-lead$i"   --barcode 10 --data "${i}234567"
done

t a-2            --barcode 10 --data 1234567+12
t a-5            --barcode 10 --data 1234567+12345
t a-space        --barcode 10 --data "1234567 12"
t a-8plus        --barcode 10 --data 12345670+99
t a-pad          --barcode 10 --data 1234567+1
t a-empty        --barcode 10 --data 1234567+
t a-6            --barcode 10 --data 1234567+123456
t a-twoplus      --barcode 10 --data 1234567+12+34
t a-notext       --barcode 10 --data 1234567+12 --notext
t a-concat2      --barcode 10 --data 000001234567012
t a-concat5      --barcode 10 --data 000001234567012345
t a-comp         --barcode 10 --data 1234567+12 --compliantheight
t a-comp-small   --barcode 10 --data 1234567+12 --compliantheight --height 20

t e-alpha        --barcode 10 --data 123456A
t e-toolong      --barcode 10 --data 12345678901234567890
t e-body9        --barcode 10 --data 123456789
t e-dash         --barcode 10 --data 1234-567
t e-empty        --barcode 10 --data ""

t l-notext       --barcode 10 --data 1234567 --notext
t l-small        --barcode 10 --data 1234567 --small
t l-bold         --barcode 10 --data 1234567 --bold
t l-height20     --barcode 10 --data 1234567 --height 20
t l-compliant    --barcode 10 --data 1234567 --compliantheight
t l-comp-h20     --barcode 10 --data 1234567 --compliantheight --height 20
t l-scale        --barcode 10 --data 1234567 --scale 0.37
t g-descent20    --barcode 10 --data 1234567 --guarddescent 20
t g-textgapneg   --barcode 10 --data 1234567 --textgap -5
t g-gap-descent  --barcode 10 --data 1234567 --textgap -5 --guarddescent 20
t b-box          --barcode 10 --data 1234567 --box --border 3
t b-bind         --barcode 10 --data 1234567 --bind --border 3
t b-bindtop      --barcode 10 --data 1234567 --bindtop --border 3
t b-noquiet      --barcode 10 --data 1234567 --noquietzones
t b-noquiet-nt   --barcode 10 --data 1234567 --noquietzones --notext
t b-noquiet-add  --barcode 10 --data 1234567+12 --noquietzones
t b-quiet-add    --barcode 10 --data 1234567+12345 --quietzones
t b-whitesp      --barcode 10 --data 1234567 --whitesp 4 --vwhitesp 3

for r in 0 90 180 270; do
  t "r-$r"       --barcode 10 --data 1234567 --rotate "$r"
done
t r-90-addon     --barcode 10 --data 1234567+12345 --rotate 90

t k-embed        --barcode 10 --data 1234567 --embedfont
t k-embed-add    --barcode 10 --data 1234567+12 --embedfont
t x-dotty        --barcode 10 --data 1234567 --dotty
t x-gs1          --barcode 10 --data 1234567 --gs1
t w-reverse      --barcode 10 --data 1234567 --reverse
t w-xdim         --barcode 10 --data 1234567 --scalexdimdp 0.33
t w-everything   --barcode 10 --data 1234567+12 --small --box --border 2 \
                 --whitesp 3 --guarddescent 7 --textgap 2 --scale 1.5 \
                 --fg 102030 --bg E0E0E0 --rotate 90 --compliantheight

for i in $(seq 1 20); do
  d=$(head -c 80 /dev/urandom | tr -dc '0-9' | head -c 7)
  t "rnd7-$i"    --barcode 10 --data "$d"
done

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
