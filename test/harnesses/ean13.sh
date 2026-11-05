#!/bin/bash
# EAN-13 against vendored zint 2.16.0. Same contract as upca.sh: SVG bytes
# when both write a file, stderr when a file was written (warnings). A case
# both refuse counts as a pass. The system zint is not the oracle.
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
      failed+=("$name  [warning differs: '$(head -c 120 /tmp/l.err)' vs '$(head -c 120 /tmp/z.err)']")
      return
    fi
  fi
  pass=$((pass+1))
}

# ---------------------------------------------------------------- basic shapes
t v-12           --barcode 15 --data 123456789012
t v-13good       --barcode 15 --data 1234567890128
t v-13bad        --barcode 15 --data 1234567890123
t v-byname       --barcode EAN13 --data 501234567890
t v-short        --barcode 15 --data 12345678901
t v-shorter      --barcode 15 --data 12345678
t v-one          --barcode 15 --data 7
t v-padzero      --barcode 15 --data 000000000000
t v-allnine      --barcode 15 --data 999999999999
t v-fgbg         --barcode 15 --data 123456789012 --fg 000080 --bg FFFFF0
t v-nobg         --barcode 15 --data 123456789012 --nobackground

# First digit selects the left-half parity. One symbol per digit.
for i in $(seq 0 9); do
  t "p-lead$i"   --barcode 15 --data "${i}23456789012"
done

# ------------------------------------------------------------------ add-ons
t a-2            --barcode 15 --data 123456789012+12
t a-5            --barcode 15 --data 123456789012+12345
t a-2checked     --barcode 15 --data 1234567890128+99
t a-5checked     --barcode 15 --data 1234567890128+54321
t a-space        --barcode 15 --data "123456789012 12"
t a-pad2         --barcode 15 --data 123456789012+1
t a-pad5         --barcode 15 --data 123456789012+123
t a-empty        --barcode 15 --data 123456789012+
t a-6            --barcode 15 --data 123456789012+123456
t a-twoplus      --barcode 15 --data 123456789012+12+34
t a-notext       --barcode 15 --data 123456789012+12345 --notext
# GTIN-13 with the add-on concatenated and no separator. Check digit is 8.
t a-concat2      --barcode 15 --data 123456789012801
t a-concat5      --barcode 15 --data 123456789012812345
t a-concatbad    --barcode 15 --data 123456789012301

# ------------------------------------------------------------- error inputs
t e-alpha        --barcode 15 --data 12345678901A
t e-toolong      --barcode 15 --data 12345678901234567890
t e-body14       --barcode 15 --data 12345678901234
t e-dash         --barcode 15 --data 1234-6789012
t e-empty        --barcode 15 --data ""

# ------------------------------------------------------------------- layout
t l-notext       --barcode 15 --data 123456789012 --notext
t l-small        --barcode 15 --data 123456789012 --small
t l-bold         --barcode 15 --data 123456789012 --bold
t l-smallbold    --barcode 15 --data 123456789012 --small --bold
t l-height20     --barcode 15 --data 123456789012 --height 20
t l-height100    --barcode 15 --data 123456789012 --height 100
t l-compliant    --barcode 15 --data 123456789012 --compliantheight
t l-comp-h20     --barcode 15 --data 123456789012 --compliantheight --height 20
t l-scale2       --barcode 15 --data 123456789012 --scale 2
t l-scalefrac    --barcode 15 --data 123456789012 --scale 0.37
t g-descent0     --barcode 15 --data 123456789012 --guarddescent 0
t g-descent20    --barcode 15 --data 123456789012 --guarddescent 20
t g-desc-notext  --barcode 15 --data 123456789012 --guarddescent 20 --notext
t g-textgap0     --barcode 15 --data 123456789012 --textgap 0
t g-textgapneg   --barcode 15 --data 123456789012 --textgap -5
t g-gap-descent  --barcode 15 --data 123456789012 --textgap -5 --guarddescent 20
t b-box          --barcode 15 --data 123456789012 --box --border 3
t b-bind         --barcode 15 --data 123456789012 --bind --border 3
t b-bindtop      --barcode 15 --data 123456789012 --bindtop --border 3
t b-box-notext   --barcode 15 --data 123456789012 --box --border 3 --notext
t b-whitesp      --barcode 15 --data 123456789012 --whitesp 5
t b-vwhitesp     --barcode 15 --data 123456789012 --vwhitesp 5
t b-quiet        --barcode 15 --data 123456789012 --quietzones
t b-noquiet      --barcode 15 --data 123456789012 --noquietzones
t b-noquiet-nt   --barcode 15 --data 123456789012 --noquietzones --notext
t b-noquiet-add  --barcode 15 --data 123456789012+12 --noquietzones
t b-quiet-add    --barcode 15 --data 123456789012+12345 --quietzones

for r in 0 90 180 270; do
  t "r-$r"       --barcode 15 --data 123456789012 --rotate "$r"
done
t r-90-addon     --barcode 15 --data 123456789012+12345 --rotate 90
t r-180-box      --barcode 15 --data 123456789012 --rotate 180 --box --border 2

t k-cmyk         --barcode 15 --data 123456789012 --fg "0,0,0,100" --bg "0,0,0,0"
t k-embed        --barcode 15 --data 123456789012 --embedfont
t k-embed-add    --barcode 15 --data 123456789012+12 --embedfont
t x-dotty        --barcode 15 --data 123456789012 --dotty
t x-gs1          --barcode 15 --data 123456789012 --gs1
t w-reverse      --barcode 15 --data 123456789012 --reverse
t w-xdim         --barcode 15 --data 123456789012 --scalexdimdp 0.33
t w-xdim-dpi     --barcode 15 --data 123456789012 --scalexdimdp 0.264,300
t w-everything   --barcode 15 --data 123456789012+12345 --small --box --border 2 \
                 --whitesp 3 --vwhitesp 2 --guarddescent 7 --textgap 2 --scale 1.5 \
                 --fg 102030 --bg E0E0E0 --quietzones --rotate 180 --compliantheight

for i in $(seq 1 30); do
  d=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 12)
  t "rnd12-$i"   --barcode 15 --data "$d"
done
for i in $(seq 1 20); do
  d=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 12)
  a=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 5)
  t "rnd5-$i"    --barcode 15 --data "$d+$a"
done

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
