#!/bin/bash
# Data Matrix ECC 200 (71) against vendored zint 2.16.0.
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

t hello       --barcode 71 --data HELLO
t name        --barcode datamatrix --data HELLO
t digits      --barcode 71 --data 123456
t lower       --barcode 71 --data hello
t alpha       --barcode 71 --data 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
t gs1         --barcode 71 --gs1 --data '[01]09501101530003'
t gs1parens   --barcode 71 --gs1 --gs1parens --data '(01)09501101530003'
t gssep       --barcode 71 --gs1 --gssep --data '[01]09501101530003'
t fast        --barcode 71 --data HELLO --fast
t fast-gs1    --barcode 71 --fast --gs1 --data '[01]09501101530003'
t x12         --barcode 71 --esc --data $'ABC*DEF>GHI 012\r'
t edi         --barcode 71 --data ABCDEFGHIJ
t b256        --barcode 71 --data 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
t cafe        --barcode 71 --data $'caf\xc3\xa9'
t cjk         --barcode 71 --data '日本語'
t macro       --barcode 71 --esc --data '[)>\x1E05\x1DHELLO\x1E\x04'
t nul         --barcode 71 --esc --data 'ABC\x00DEF'
t init        --barcode 71 --data HELLO --init
t square      --barcode 71 --data 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' --square
t dmre        --barcode 71 --data 'HELLOHELLOHELLO' --dmre
t both        --barcode 71 --data 'HELLOHELLOHELLO' --dmre --square
t vers2       --barcode 71 --data HELLO --vers=2
t vers12      --barcode 71 --data HELLO --vers=12
t vers25      --barcode 71 --data HELLO --vers=25
t vers49      --barcode 71 --data HELLO --vers=49
t cols3       --barcode 71 --data HELLO --cols=3
t rows4       --barcode 71 --data HELLO --rows=4
t rows99      --barcode 71 --data HELLO --rows=99
t vers0       --barcode 71 --data HELLO --vers=0
t vers1000    --barcode 71 --data HELLO --vers=1000
t qz          --barcode 71 --data HELLO --quietzones
t noqz        --barcode 71 --data HELLO --noquietzones
t qz-no       --barcode 71 --data HELLO --quietzones --noquietzones
t dotty       --barcode 71 --data HELLO --dotty
t dotsize     --barcode 71 --data HELLO --dotty --dotsize=0.5
t box         --barcode 71 --data HELLO --box --border=2
t bind        --barcode 71 --data HELLO --bind --border=2
t scale       --barcode 71 --data HELLO --scale=1.5
t ws          --barcode 71 --data HELLO --whitesp=3 --vwhitesp=2
t rev         --barcode 71 --data HELLO --reverse
t notext      --barcode 71 --data HELLO --notext
t small       --barcode 71 --data HELLO --small --bold
t xdim        --barcode 71 --data HELLO --scalexdimdp=0.625

FOX='The quick brown fox jumps over the lazy dog'
t d144        --barcode 71 --vers=24 --data "$FOX"
t d144iso     --barcode 71 --vers=24 --dmiso144 --data "$FOX"

for r in 0 90 180 270; do
  t "rot-$r"  --barcode 71 --data HELLO --rotate "$r"
done

# Both sides refuse. The message text is not compared.
t e-empty     --barcode 71 --data ''
t e-vers1     --barcode 71 --data HELLO --vers=1
t e-gs1       --barcode 71 --gs1 --data HELLO
t e-initgs1   --barcode 71 --gs1 --init --data '[01]09501101530003'
t e-long      --barcode 71 --data "$(printf 'A%.0s' {1..4000})"

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
