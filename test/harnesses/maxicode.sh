#!/bin/bash
# MaxiCode (57) against vendored zint 2.16.0.
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

t mode4       --barcode 57 --data 1
t name        --barcode maxicode --data Hello
t primary     --barcode 57 --primary=123456789123456 --data A
t iso         --barcode 57 --primary=B1050056999 --data CEN
t mode2       --barcode 57 --mode=2 --primary=123456789123456 --data A
t mode3       --barcode 57 --mode=3 --primary=B1050056999 --data CEN
t mode5       --barcode 57 --mode=5 --data Hello
t mode6       --barcode 57 --mode=6 --data 'The quick brown fox'
t scm         --barcode 57 --mode=2 --primary=123456789123456 --scmvv=1 --data A
t zip5        --barcode 57 --mode=2 --primary='12345 840001' --data A
t cafe        --barcode 57 --data $'caf\xc3\xa9'
t cjk         --barcode 57 --mode=4 --data '日本語'
t qz          --barcode 57 --data 1 --quietzones
t noqz        --barcode 57 --data 1 --noquietzones
t qz-no       --barcode 57 --data 1 --quietzones --noquietzones
t scale       --barcode 57 --data 1 --scale=1.5
t ws          --barcode 57 --data 1 --whitesp=2 --vwhitesp=1
t rev         --barcode 57 --data 1 --reverse
t box         --barcode 57 --data 1 --box --border=2
t bind        --barcode 57 --data 1 --bind --border=1
t notext      --barcode 57 --data 1 --notext
t small       --barcode 57 --data 1 --small --bold
t xdim        --barcode 57 --data 1 --scalexdimdp=0.88
t height      --barcode 57 --data 1 --compliantheight

for r in 0 90 180 270; do
  t "rot-$r"  --barcode 57 --data 1 --rotate "$r"
  t "prot-$r" --barcode 57 --primary=123456789123456 --data A --rotate "$r"
done

LONGP="$(printf '1%.0s' {1..128})"
t w-primary   --barcode 57 --mode=4 --primary="$LONGP" --data A
t w-mode7     --barcode 57 --mode=7 --data Hello
t w-scm100    --barcode 57 --mode=2 --primary=123456789123456 --scmvv=100 --data A

t e-mode0     --barcode 57 --mode=0 --data A
t e-noprim    --barcode 57 --mode=2 --data A
t e-short     --barcode 57 --primary=123456 --data A
t e-long      --barcode 57 --primary=1234567890123456 --data A
t e-post      --barcode 57 --mode=2 --primary=A123456 --data A
t e-country   --barcode 57 --primary=1A23456 --data A
t e-gs1       --barcode 57 --gs1 --data '[01]09501101530003'
t e-dotty     --barcode 57 --data 1 --dotty
t e-empty     --barcode 57 --data ''

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
