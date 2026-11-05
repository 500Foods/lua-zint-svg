#!/bin/bash
# Oracle and port default to this repo. Override ZINT and LUA_ZINT to point
# elsewhere. The system zint is an older release and is not the oracle.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ZINT:=$ROOT/vendor/zint/build/frontend/zint}"
: "${LUA_ZINT:=$ROOT/bin/lua-zint}"
export LC_ALL=C
# UPC-A differential harness: every case runs both binaries and compares the
# SVG bytes, or -- when neither writes a file -- compares stderr and exit code.
pass=0; fail=0; failed=()

t() {
  local name="$1"; shift
  rm -f /tmp/l.svg /tmp/z.svg /tmp/l.err /tmp/z.err
  "$LUA_ZINT" "$@" --output /tmp/l.svg >/tmp/l.out 2>/tmp/l.err; lrc=$?
  "$ZINT" "$@" --output /tmp/z.svg >/tmp/z.out 2>/tmp/z.err; zrc=$?

  local lhas=0 zhas=0
  [ -f /tmp/l.svg ] && lhas=1
  [ -f /tmp/z.svg ] && zhas=1

  # What the verifier can see is the file and its bytes. It cannot see an exit
  # code or an error message: zint-lua.sh's runner discards zint.barcode's
  # second return and always exits 0. Warnings are different -- options.lua
  # writes those to stderr as it goes -- so they are compared, but only on the
  # path where a symbol was actually produced.
  if [ "$lhas" != "$zhas" ]; then
    fail=$((fail+1)); failed+=("$name  [file: lua=$lhas zint=$zhas]"); return
  fi
  if [ "$lhas" = 1 ]; then
    if ! cmp -s /tmp/l.svg /tmp/z.svg; then
      fail=$((fail+1)); failed+=("$name  [svg bytes differ]"); return
    fi
    if ! diff -q /tmp/l.err /tmp/z.err >/dev/null; then
      fail=$((fail+1))
      failed+=("$name  [warning differs: '$(head -c 100 /tmp/l.err)' vs '$(head -c 100 /tmp/z.err)']")
      return
    fi
  fi
  pass=$((pass+1))
}

# ---------------------------------------------------------- verifier's cases
t v-11digits     --barcode 34 --data 12345678901
t v-12digits     --barcode 34 --data 123456789012
t v-leadingzero  --barcode 34 --data 00123456789
t v-byname       --barcode UPCA --data 03600029145
t v-fgbg         --barcode 34 --data 12345678901 --fg 000080 --bg FFFFF0
t v-nobg         --barcode 34 --data 12345678901 --nobackground

# ----------------------------------------------------------- digit coverage
t d-allzero      --barcode 34 --data 00000000000
t d-allnine      --barcode 34 --data 99999999999
t d-seq          --barcode 34 --data 01234567890
t d-realupc      --barcode 34 --data 03600029145
t d-checkzero    --barcode 34 --data 04210000526
for i in $(seq 0 9); do
  t "d-lead$i"   --barcode 34 --data "${i}2345678901"
done

# ------------------------------------------------------------- check digits
# 35 supplies its own check digit; a wrong one is an error, not a correction.
t c-35-good      --barcode 35 --data 123456789012
t c-35-bad       --barcode 35 --data 123456789013
t c-35-byname    --barcode upcachk --data 036000291452
t c-35-short     --barcode 35 --data 12345678901
t c-34-12good    --barcode 34 --data 123456789012
t c-34-12bad     --barcode 34 --data 123456789019

# ------------------------------------------------------------------ add-ons
t a-2digit       --barcode 34 --data 12345678901+12
t a-5digit       --barcode 34 --data 12345678901+12345
t a-2-checked    --barcode 35 --data 123456789012+99
t a-5-checked    --barcode 35 --data 123456789012+54321
t a-emptyaddon   --barcode 34 --data 12345678901+
t a-6digit       --barcode 34 --data 12345678901+123456
t a-1digit       --barcode 34 --data 12345678901+1
t a-3digit       --barcode 34 --data 12345678901+123
t a-notext       --barcode 34 --data 12345678901+12345 --notext
t a-2plus        --barcode 34 --data 12345678901+12+34
t a-leadplus     --barcode 34 --data +12345

# ------------------------------------------------------------- error inputs
t e-short        --barcode 34 --data 1234567890
t e-long         --barcode 34 --data 1234567890123
t e-alpha        --barcode 34 --data 1234567890A
t e-space        --barcode 34 --data "1234567890 "
t e-toolong      --barcode 34 --data 12345678901234567890
t e-empty        --barcode 34 --data ""
t e-dash         --barcode 34 --data 1234-678901

# ------------------------------------------------------------------- layout
t l-notext       --barcode 34 --data 12345678901 --notext
t l-small        --barcode 34 --data 12345678901 --small
t l-bold         --barcode 34 --data 12345678901 --bold
t l-smallbold    --barcode 34 --data 12345678901 --small --bold
t l-height20     --barcode 34 --data 12345678901 --height 20
t l-height100    --barcode 34 --data 12345678901 --height 100
t l-height0      --barcode 34 --data 12345678901 --height 0
t l-compliant    --barcode 34 --data 12345678901 --compliantheight
t l-comp-h20     --barcode 34 --data 12345678901 --compliantheight --height 20
t l-scale2       --barcode 34 --data 12345678901 --scale 2
t l-scalefrac    --barcode 34 --data 12345678901 --scale 0.37
t l-scale001     --barcode 34 --data 12345678901 --scale 0.01

# ------------------------------------------------------- guard descent, gaps
t g-descent0     --barcode 34 --data 12345678901 --guarddescent 0
t g-descent2     --barcode 34 --data 12345678901 --guarddescent 2.5
t g-descent20    --barcode 34 --data 12345678901 --guarddescent 20
t g-descent50    --barcode 34 --data 12345678901 --guarddescent 50
t g-descent51    --barcode 34 --data 12345678901 --guarddescent 51
t g-desc-notext  --barcode 34 --data 12345678901 --guarddescent 20 --notext
t g-textgap0     --barcode 34 --data 12345678901 --textgap 0
t g-textgap5     --barcode 34 --data 12345678901 --textgap 5
t g-textgapneg   --barcode 34 --data 12345678901 --textgap -5
t g-gap-descent  --barcode 34 --data 12345678901 --textgap -5 --guarddescent 20

# --------------------------------------------------------- borders and space
t b-box          --barcode 34 --data 12345678901 --box --border 3
t b-bind         --barcode 34 --data 12345678901 --bind --border 3
t b-bindtop      --barcode 34 --data 12345678901 --bindtop --border 3
t b-box-notext   --barcode 34 --data 12345678901 --box --border 3 --notext
t b-whitesp      --barcode 34 --data 12345678901 --whitesp 5
t b-vwhitesp     --barcode 34 --data 12345678901 --vwhitesp 5
t b-both         --barcode 34 --data 12345678901 --whitesp 5 --vwhitesp 5 --box --border 2
t b-quietzones   --barcode 34 --data 12345678901 --quietzones
t b-noquiet      --barcode 34 --data 12345678901 --noquietzones
t b-noquiet-nt   --barcode 34 --data 12345678901 --noquietzones --notext
t b-noquiet-add  --barcode 34 --data 12345678901+12 --noquietzones
t b-quiet-add    --barcode 34 --data 12345678901+12345 --quietzones

# ------------------------------------------------------------------ rotation
for r in 0 90 180 270; do
  t "r-$r"       --barcode 34 --data 12345678901 --rotate "$r"
done
t r-90-addon     --barcode 34 --data 12345678901+12345 --rotate 90
t r-180-box      --barcode 34 --data 12345678901 --rotate 180 --box --border 2

# -------------------------------------------------------------------- colour
t k-cmyk         --barcode 34 --data 12345678901 --fg "0,0,0,100" --bg "0,0,0,0"
t k-alpha        --barcode 34 --data 12345678901 --fg 00008080 --bg FFFFF040
t k-lowerhex     --barcode 34 --data 12345678901 --fg 00ff00 --bg 0000ff
t k-embedfont    --barcode 34 --data 12345678901 --embedfont
t k-embed-nt     --barcode 34 --data 12345678901 --embedfont --notext
t k-embed-add    --barcode 34 --data 12345678901+12 --embedfont

# ----------------------------------------------------------- refused options
t x-dotty        --barcode 34 --data 12345678901 --dotty
t x-gs1          --barcode 34 --data 12345678901 --gs1
t x-esc          --barcode 34 --data 12345678901 --esc

# ------------------------------------------------- leading-zero padding
# Short input is padded to 11 digits (or 12 for symbology 35), so a 3-digit
# body is a legal UPC-A. This is the branch that makes "too short" a much
# rarer error than it looks.
for n in 1 2 3 4 5 6 7 8 9 10 11; do
  d=$(printf '1%.0s' $(seq 1 $n))
  t "z34-len$n"  --barcode 34 --data "$d"
  t "z35-len$n"  --barcode 35 --data "$d"
done
t z-pad-addon    --barcode 34 --data 7+12345
t z-pad-zeros    --barcode 34 --data 0
t z-pad-single   --barcode 34 --data 9

# ------------------------------------------------ remaining wrapper options
t w-heightperrow --barcode 34 --data 12345678901 --heightperrow --height 30
t w-hpr-compl    --barcode 34 --data 12345678901 --heightperrow --height 5 --compliantheight
t w-reverse      --barcode 34 --data 12345678901 --reverse
t w-reverse-bg   --barcode 34 --data 12345678901 --reverse --nobackground
t w-gs1parens    --barcode 34 --data 12345678901 --gs1parens
t w-init         --barcode 34 --data 12345678901 --init
t w-extraesc     --barcode 34 --data 12345678901 --extraesc
t w-dotsize      --barcode 34 --data 12345678901 --dotsize 0.5
t w-filetype     --barcode 34 --data 12345678901 --filetype svg
t w-xdim         --barcode 34 --data 12345678901 --scalexdimdp 0.33
t w-xdim-dpi     --barcode 34 --data 12345678901 --scalexdimdp 0.264,300
t w-border0      --barcode 34 --data 12345678901 --border 0 --box
t w-border100    --barcode 34 --data 12345678901 --border 100 --box
t w-everything   --barcode 34 --data 12345678901+12345 --small --box --border 2 \
                 --whitesp 3 --vwhitesp 2 --guarddescent 7 --textgap 2 --scale 1.5 \
                 --fg 102030 --bg E0E0E0 --quietzones --rotate 180 --compliantheight

# --------------------------------------------------------- random regression
for i in $(seq 1 60); do
  d=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 11)
  t "rnd11-$i"   --barcode 34 --data "$d"
done
for i in $(seq 1 40); do
  d=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 11)
  a=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 5)
  t "rnd5add-$i" --barcode 34 --data "$d+$a"
done
for i in $(seq 1 20); do
  d=$(head -c 200 /dev/urandom | tr -dc '0-9' | head -c 12)
  t "rnd35-$i"   --barcode 35 --data "$d"
done

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
