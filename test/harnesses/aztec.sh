#!/bin/bash
# Aztec (92) against vendored zint 2.16.0.
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

t hello       --barcode 92 --data Hello
t name        --barcode aztec --data Hello
t synonym     --barcode azteccode --data Hello
t iso         --barcode 92 --vers=1 --data 123456789012
t vers5       --barcode 92 --vers=5 --data Hello
t vers4       --barcode 92 --vers=4 --data 123456789012
t secure1     --barcode 92 --secure=1 --data Hello
t secure4     --barcode 92 --secure=4 --data 'The quick brown fox jumps over the lazy dog'
t gs1         --barcode 92 --gs1 --data '[01]09501101530003'
t gs1parens   --barcode 92 --gs1 --gs1parens --data '(01)09501101530003'
t init        --barcode 92 --init --data Hello
t dotty       --barcode 92 --dotty --data Hello
t dotsize     --barcode 92 --dotty --dotsize=0.5 --data Hello
t cafe        --barcode 92 --data $'caf\xc3\xa9'
t cjk         --barcode 92 --data '日本語'
t fast        --barcode 92 --fast --data Hello
t qz          --barcode 92 --data Hello --quietzones
t noqz        --barcode 92 --data Hello --noquietzones
t scale       --barcode 92 --data Hello --scale=1.5
t ws          --barcode 92 --data Hello --whitesp=2 --vwhitesp=2
t rev         --barcode 92 --data Hello --reverse
t box         --barcode 92 --data Hello --box --border=2
t bind        --barcode 92 --data Hello --bind --border=1
t notext      --barcode 92 --data Hello --notext
t small       --barcode 92 --data Hello --small --bold
t xdim        --barcode 92 --data Hello --scalexdimdp=0.625

for r in 0 90 180 270; do
  t "rot-$r"  --barcode 92 --data Hello --rotate "$r"
  t "drot-$r" --barcode 92 --dotty --data Hello --rotate "$r"
done

t w-secure5   --barcode 92 --secure=5 --data Hello
t w-secure9   --barcode 92 --secure=9 --data Hello

t e-vers0     --barcode 92 --vers=0 --data Hello
t e-vers37    --barcode 92 --vers=37 --data Hello
t e-empty     --barcode 92 --data ''
t e-gs1init   --barcode 92 --gs1 --init --data '[01]09501101530003'

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
