#!/bin/bash
# Flattermarken (28) against vendored zint 2.16.0.
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

t digits       --barcode 28 --data 0123456789
t name         --barcode flat --data 0123456789
t one          --barcode 28 --data 1
t zero         --barcode 28 --data 0
t ones         --barcode 28 --data 111111
t zeros        --barcode 28 --data 000
t notext       --barcode 28 --data 0123456789 --notext
t qz           --barcode 28 --data 0123456789 --quietzones
t noqz         --barcode 28 --data 0123456789 --noquietzones
t scale        --barcode 28 --data 0123456789 --scale=1.5
t rev          --barcode 28 --data 42 --reverse
t box          --barcode 28 --data 42 --box --border=2
t bind         --barcode 28 --data 42 --bind --border=1
t small        --barcode 28 --data 42 --small --bold
t ws           --barcode 28 --data 42 --whitesp=3 --vwhitesp=2
t xdim         --barcode 28 --data 42 --scalexdimdp=0.495

for r in 0 90 180 270; do
  t "rot-$r"   --barcode 28 --data 0123456789 --rotate "$r"
done

t e-alpha      --barcode 28 --data 12A
t e-empty      --barcode 28 --data ''
t e-long       --barcode 28 --data "$(printf '1%.0s' {1..129})"
t e-gs1        --barcode 28 --gs1 --data 1234

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
