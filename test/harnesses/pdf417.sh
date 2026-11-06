#!/bin/bash
# PDF417 (55) and Compact PDF417 (56) against vendored zint 2.16.0.
# SVG and stderr are compared only when both sides write a file.
# Exit codes are not compared. A case both refuse counts as a pass.
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

t hello       --barcode 55 --data PDF417
t name        --barcode pdf417 --data PDF417
t annex       --barcode 55 --secure=1 --cols=2 --data PDF417
t compact     --barcode 56 --data Hello
t compname    --barcode pdf417comp --data Hello
t truncname   --barcode pdf417trunc --data Hello
t cols1       --barcode 55 --cols=1 --data PDF417
t cols4       --barcode 55 --cols=4 --data 'The quick brown fox'
t rows5       --barcode 55 --rows=5 --data PDF417
t rows90      --barcode 55 --rows=6 --cols=2 --data PDF417
t secure0     --barcode 55 --secure=0 --data PDF417
t secure8     --barcode 55 --secure=8 --data PDF417
t fast        --barcode 55 --fast --data 'The quick brown fox jumps over the lazy dog'
t cafe        --barcode 55 --data $'caf\xc3\xa9'
t cjk         --barcode 55 --data '日本語'
t bytes       --barcode 55 --data $'ABC\x00DEF' --esc
t qz          --barcode 55 --data PDF417 --quietzones
t noqz        --barcode 55 --data PDF417 --noquietzones
t qz-no       --barcode 55 --data PDF417 --quietzones --noquietzones
t scale       --barcode 55 --data PDF417 --scale=1.5
t ws          --barcode 55 --data PDF417 --whitesp=3 --vwhitesp=2
t rev         --barcode 55 --data PDF417 --reverse
t box         --barcode 55 --data PDF417 --box --border=2
t bind        --barcode 55 --data PDF417 --bind --border=1
t notext      --barcode 55 --data PDF417 --notext
t small       --barcode 55 --data PDF417 --small --bold
t xdim        --barcode 55 --data PDF417 --scalexdimdp=0.33
t comp-qz     --barcode 56 --data Hello --quietzones
t comp-scale  --barcode 56 --data Hello --scale=1.5
t comp-sec    --barcode 56 --secure=2 --cols=3 --data Hello

for r in 0 90 180 270; do
  t "rot-$r"  --barcode 55 --data PDF417 --rotate "$r"
  t "crot-$r" --barcode 56 --data Hello --rotate "$r"
done

t w-rows99    --barcode 55 --data PDF417 --rows=99
t w-secure9   --barcode 55 --data PDF417 --secure=9
t w-cols31    --barcode 55 --data PDF417 --cols=31
t w-cols0     --barcode 55 --data PDF417 --cols=0

t e-rows2     --barcode 55 --data PDF417 --rows=2
t e-empty     --barcode 55 --data ''
t e-gs1       --barcode 55 --gs1 --data '[01]09501101530003'
t e-dotty     --barcode 55 --data PDF417 --dotty
t e-prod      --barcode 55 --cols=30 --rows=40 --data PDF417

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
