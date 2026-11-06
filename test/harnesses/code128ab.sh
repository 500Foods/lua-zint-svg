#!/bin/bash
# Code 128 suppress C (60) against vendored zint 2.16.0.
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

t digits       --barcode 60 --data 123456
t name         --barcode code128ab --data 123456
t alias        --barcode code128b --data 123456
t letters      --barcode 60 --data HELLO
t mixed        --barcode 60 --data 'Ab-129'
t longdig      --barcode 60 --data 12345678901234567890
t lower        --barcode 60 --data 'hello world'
t qz           --barcode 60 --data 123456 --quietzones
t noqz         --barcode 60 --data 123456 --noquietzones
t qz-no        --barcode 60 --data 123456 --quietzones --noquietzones
t notext       --barcode 60 --data 123456 --notext
t small        --barcode 60 --data 123456 --small --bold
t scale        --barcode 60 --data 123456 --scale=1.5
t rev          --barcode 60 --data 123456 --reverse
t box          --barcode 60 --data 123456 --box --border=2
t bind         --barcode 60 --data 123456 --bind --border=1
t init         --barcode 60 --data 123456 --init
t embed        --barcode 60 --data 123456 --embedfont
t xdim         --barcode 60 --data 123456 --scalexdimdp=0.495
t ws           --barcode 60 --data 123456 --whitesp=3 --vwhitesp=2
# extraesc is a Code 128 (20) feature. On 60 the backslashes stay data.
t extra        --barcode 60 --extraesc --data '12\^C34'

for r in 0 90 180 270; do
  t "rot-$r"   --barcode 60 --data 123456 --rotate "$r"
done

t e-empty      --barcode 60 --data ''
t e-gs1        --barcode 60 --gs1 --data 123456

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
