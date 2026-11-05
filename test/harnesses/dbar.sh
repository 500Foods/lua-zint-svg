#!/bin/bash
# GS1 DataBar Expanded (31) and Expanded Stacked (81) against vendored zint 2.16.0.
# Stderr is compared only when both sides write an SVG. Exit codes are not compared:
# a GS1 lint warning exits 2 here and 0 from a zint built without the GS1 Syntax Engine.
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

DATE='[01]09501101530003[17]140704[10]AB-123'
M4='[01]90614141000015[3202]000150'
M3='[01]90012345678908[3103]001750'
LONG='[91]12345678901234567890123456789012345678901234567890123456789012345678'

# Linear methods and general-field compaction.
t l-m4         --barcode 31 --data "$M4"
t l-m3         --barcode 31 --data "$M3"
t l-m5         --barcode 31 --data "[01]90012345678908[3922]1234"
t l-m6         --barcode 31 --data "[01]90012345678908[3932]840123"
t l-m7         --barcode 31 --data "[01]90012345678908[3102]001750"
t l-m8         --barcode 31 --data "[01]90012345678908[3200]001750"
t l-m3103hi    --barcode 31 --data "[01]90012345678908[3103]400000"
t l-date15     --barcode 31 --data "[01]98898765432106[3202]012345[15]991231"
t l-date11     --barcode 31 --data "[01]90012345678908[3103]001750[11]991231"
t l-date13     --barcode 31 --data "[01]90012345678908[3103]001750[13]991231"
t l-date17     --barcode 31 --data "$DATE"
t l-short      --barcode 31 --data "[10]12A"
t l-odd5       --barcode 31 --data "[10]12345"
t l-odd9       --barcode 31 --data "[90]123456789"
t l-fnc1       --barcode 31 --data "[10]ABC[21]99"
t l-lower      --barcode 31 --data "[90]ab-cd"
t l-hello      --barcode 31 --data "[90]Hello"
t l-iso        --barcode 31 --data "[90]Hello, world"
t l-badsum     --barcode 31 --data "[01]90614141999996[10]1234222222222221"
t l-space      --barcode 31 --data "[90]AB CD"

t l-name       --barcode dbarexp --data "$DATE"
t l-name2      --barcode databarexpanded --data "$DATE"
t l-name3      --barcode rssexp --data "$DATE"
t l-gs1        --barcode 31 --data "$DATE" --gs1
t l-parens     --barcode 31 --data "$M4" --gs1parens
t l-notext     --barcode 31 --data "$DATE" --notext
t l-small      --barcode 31 --data "$DATE" --small
t l-bold       --barcode 31 --data "[10]12A" --bold
t l-height     --barcode 31 --data "$DATE" --height 40
t l-comp       --barcode 31 --data "$DATE" --compliantheight
t l-comp-low   --barcode 31 --data "$DATE" --compliantheight --height 10
t l-scale      --barcode 31 --data "$DATE" --scale 1.5
t l-xdim       --barcode 31 --data "$DATE" --scalexdimdp 0.33
t l-qz         --barcode 31 --data "$DATE" --quietzones
t l-noqz       --barcode 31 --data "$DATE" --noquietzones
t l-box        --barcode 31 --data "$DATE" --box --border 2
t l-bind       --barcode 31 --data "$DATE" --bind --border 2
t l-whitesp    --barcode 31 --data "$DATE" --whitesp 3 --vwhitesp 2
t l-reverse    --barcode 31 --data "$DATE" --reverse
t l-embed      --barcode 31 --data "$DATE" --embedfont
t l-init       --barcode 31 --data "$DATE" --init
t l-cols0      --barcode 31 --data "$DATE" --cols 0
t l-dotty      --barcode 31 --data "$DATE" --dotty

for r in 0 90 180 270; do
  t "l-r-$r"   --barcode 31 --data "$DATE" --rotate "$r"
done

# Stacked layout, including the even-column special-case row.
t s-date       --barcode 81 --data "$DATE"
t s-date-c3    --barcode 81 --data "$DATE" --cols 3
t s-date-v3    --barcode 81 --data "$DATE" --vers 3
t s-alpha      --barcode 81 --data "[91]ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFG"
t s-m4         --barcode 81 --data "$M4"
t s-name       --barcode dbarexpstk --data "$DATE"
t s-name2      --barcode databarexpandedstacked --data "$DATE"
t s-name3      --barcode rssexpstack --data "$DATE"
t s-notext     --barcode 81 --data "$DATE" --notext
t s-height     --barcode 81 --data "$DATE" --height 80
t s-hpr        --barcode 81 --data "$DATE" --heightperrow --height 40
t s-bind       --barcode 81 --data "$DATE" --bind --border 1
t s-reverse    --barcode 81 --data "$DATE" --reverse
t s-embed      --barcode 81 --data "$DATE" --embedfont
t s-qz         --barcode 81 --data "$DATE" --quietzones
t s-rows99     --barcode 81 --data "$LONG" --rows 99
t s-cols12     --barcode 81 --data "$LONG" --cols 12

for c in 1 2 3 4 5 6 7 8 9 10 11; do
  t "s-cols-$c" --barcode 81 --data "$LONG" --cols "$c"
done
for r in 2 3 11; do
  t "s-rows-$r" --barcode 81 --data "$LONG" --rows "$r"
done
for r in 0 90 180 270; do
  t "s-r-$r"   --barcode 81 --data "$DATE" --rotate "$r"
done

# Both sides refuse. The message text is not compared.
t e-empty      --barcode 31 --data ""
t e-noai       --barcode 31 --data 1234
t e-tilde      --barcode 31 --data "[90]abc~"
t e-ai90       --barcode 31 --data "[90]1234567890123456789012345678901"
t e-long91     --barcode 31 --data "[91]AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
t e-cols       --barcode 31 --data "$DATE" --cols abc
t e-rows       --barcode 81 --data "$DATE" --rows xx
t e-stk-empty  --barcode 81 --data ""

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
