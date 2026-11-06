#!/bin/bash
# USPS Intelligent Mail (85) against vendored zint 2.16.0.
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

t zip11       --barcode 85 --data '01234567094987654321-01234567891'
t name        --barcode uspsimail --data '01234567094987654321-01234567891'
t tracker     --barcode 85 --data 12345678901234567890
t zip5        --barcode 85 --data '12345678901234567890-12345'
t zip9        --barcode 85 --data '12345678901234567890-123456789'
t zip11b      --barcode 85 --data '12345678901234567890-12345678901'
t sample      --barcode 85 --data '53379777234994544928-51135759461'
t qz          --barcode 85 --data '01234567094987654321-01234567891' --quietzones
t noqz        --barcode 85 --data '01234567094987654321-01234567891' --noquietzones
t qz-no       --barcode 85 --data '01234567094987654321-01234567891' --quietzones --noquietzones
t scale       --barcode 85 --data '01234567094987654321-01234567891' --scale=1.5
t ws          --barcode 85 --data 12345678901234567890 --whitesp=2 --vwhitesp=1
t rev         --barcode 85 --data 12345678901234567890 --reverse
t box         --barcode 85 --data 12345678901234567890 --box --border=2
t bind        --barcode 85 --data 12345678901234567890 --bind --border=1
t notext      --barcode 85 --data 12345678901234567890 --notext
t small       --barcode 85 --data 12345678901234567890 --small --bold
t xdim        --barcode 85 --data 12345678901234567890 --scalexdimdp=0.591
t compliant   --barcode 85 --data 12345678901234567890 --compliantheight
t height-in   --barcode 85 --data 12345678901234567890 --compliantheight --height=6
t height-out  --barcode 85 --data 12345678901234567890 --compliantheight --height=20

for r in 0 90 180 270; do
  t "rot-$r"  --barcode 85 --data '01234567094987654321-01234567891' --rotate "$r"
done

t e-long      --barcode 85 --data '123456789012345678901234567890123'
t e-alpha     --barcode 85 --data 1234567890123456789A
t e-track     --barcode 85 --data 1234567890123456789
t e-zip       --barcode 85 --data '12345678901234567890-1234'
t e-id        --barcode 85 --data 15345678901234567890
t e-empty     --barcode 85 --data ''
t e-gs1       --barcode 85 --gs1 --data 12345678901234567890
t e-dotty     --barcode 85 --data 12345678901234567890 --dotty

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
