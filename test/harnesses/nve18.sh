#!/bin/bash
# NVE-18 / SSCC (75) against vendored zint 2.16.0.
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

t v-17         --barcode 75 --data 12345678901234567
t v-18         --barcode 75 --data 123456789012345675
t v-short      --barcode 75 --data 1234
t v-5          --barcode 75 --data 12345
t v-40         --barcode 75 --data 12340
t v-name       --barcode NVE18 --data 12345678901234567
t v-lead00-18  --barcode 75 --data 003456789012345670
t v-lead00-17  --barcode 75 --data 00345678901234567
t v-prefix20   --barcode 75 --data 00123456789012345675
t v-prefix19   --barcode 75 --data 0012345678901234567
t v-brack18    --barcode 75 --data "[00]123456789012345675"
t v-brack17    --barcode 75 --data "[00]12345678901234567"
t v-paren18    --barcode 75 --data "(00)123456789012345675"
t v-paren17    --barcode 75 --data "(00)12345678901234567"
t v-gs1        --barcode 75 --data 12345678901234567 --gs1
t v-parens     --barcode 75 --data 12345678901234567 --gs1parens
t v-real       --barcode 75 --data 40700000071967072

t e-19         --barcode 75 --data 1234567890123456759
t e-19b        --barcode 75 --data 1234567890123456789
t e-alpha      --barcode 75 --data 12345678901234567A
t e-mid        --barcode 75 --data 1234A568901234567
t e-check      --barcode 75 --data 123456789012345678
t e-01         --barcode 75 --data 01123456789012345675
t e-badbrack   --barcode 75 --data "[01]123456789012345675"
t e-badparen   --barcode 75 --data "(01)123456789012345675"
t e-mix        --barcode 75 --data "(00]123456789012345675"
t e-empty      --barcode 75 --data ""

t l-notext     --barcode 75 --data 12345678901234567 --notext
t l-small      --barcode 75 --data 12345678901234567 --small
t l-bold       --barcode 75 --data 1234 --bold
t l-height     --barcode 75 --data 12345678901234567 --height 20
t l-comp       --barcode 75 --data 12345678901234567 --compliantheight
t l-comp-low   --barcode 75 --data 12345678901234567 --compliantheight --height 5.7
t l-comp-ok    --barcode 75 --data 12345678901234567 --compliantheight --height 5.8
t l-scale      --barcode 75 --data 12345678901234567 --scale 1.5
t l-qz         --barcode 75 --data 1234 --quietzones
t l-noqz       --barcode 75 --data 1234 --noquietzones
t l-box        --barcode 75 --data 1234 --box --border 2
t l-bind       --barcode 75 --data 1234 --bind --border 2
t l-whitesp    --barcode 75 --data 1234 --whitesp 3 --vwhitesp 2
t l-xdim       --barcode 75 --data 12345678901234567 --scalexdimdp 0.495
t l-init       --barcode 75 --data 12 --init
t l-dotty      --barcode 75 --data 1234 --dotty
t l-reverse    --barcode 75 --data 1234 --reverse
t l-embed      --barcode 75 --data 12345678901234567 --embedfont

for r in 0 90 180 270; do
  t "r-$r"     --barcode 75 --data 12345678901234567 --rotate "$r"
done

for i in $(seq 1 8); do
  n=$(( (RANDOM % 17) + 1 ))
  d=$(head -c 40 /dev/urandom | tr -dc '0-9' | head -c "$n")
  t "rnd-$i"   --barcode 75 --data "$d"
done

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
