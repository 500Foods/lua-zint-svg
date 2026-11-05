#!/bin/bash
# Interleaved 2 of 5 (3) and ITF-14 (89) against vendored zint 2.16.0.
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
      failed+=("$name  [warning differs: '$(head -c 180 /tmp/l.err)' vs '$(head -c 180 /tmp/z.err)']")
      return
    fi
  fi
  pass=$((pass+1))
}

# Interleaved 2 of 5. Odd lengths grow a leading zero. --vers 1 shows a check
# digit; --vers 2 calculates it and hides it from the human-readable line.
t i-even        --barcode 3 --data 1234567890
t i-odd         --barcode 3 --data 123456789
t i-one         --barcode 3 --data 1
t i-two         --barcode 3 --data 00
t i-wiki        --barcode 3 --data 602003
t i-name        --barcode C25INTER --data 87654321
t i-syn         --barcode "2 of 5 interleaved" --data 87654321
t i-syn2        --barcode interleaved2of5 --data 7654321
t i-chk-show    --barcode 3 --data 87654321 --vers 1
t i-chk-odd     --barcode 3 --data 7654321 --vers 1
t i-chk-hide    --barcode 3 --data 87654321 --vers 2
t i-chk-hide-o  --barcode 3 --data 1234567890 --vers 2
t i-chk-show-e  --barcode 3 --data 1234567890 --vers 1
t i-vers3       --barcode 3 --data 1234567890 --vers 3
t i-vers0       --barcode 3 --data 1234567890 --vers 0
t i-vers1000    --barcode 3 --data 1234 --vers 1000
t i-pad         --barcode 3 --data 123456789 --vers 1

t i-long        --barcode 3 --data 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345
t i-toolong     --barcode 3 --data 123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456
t i-alpha       --barcode 3 --data 12345A
t i-space       --barcode 3 --data "12 34"
t i-empty       --barcode 3 --data ""
t i-gs1         --barcode 3 --data 1234567890 --gs1

t i-notext      --barcode 3 --data 1234567890 --notext
t i-small       --barcode 3 --data 1234567890 --small
t i-bold        --barcode 3 --data 1234567890 --bold
t i-height      --barcode 3 --data 1234567890 --height 20
t i-comp        --barcode 3 --data 1234567890 --compliantheight
t i-comp-low    --barcode 3 --data 1234567890 --compliantheight --height 15
t i-comp-ok     --barcode 3 --data 1234567890 --compliantheight --height 15.5
t i-comp-odd    --barcode 3 --data 12345678901 --compliantheight --height 17.5
t i-comp-oddok  --barcode 3 --data 12345678901 --compliantheight --height 17.75
t i-comp-long   --barcode 3 --data 123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 --compliantheight
t i-scale       --barcode 3 --data 1234567890 --scale 1.5
t i-qz          --barcode 3 --data 1234 --quietzones
t i-noqz        --barcode 3 --data 1234 --noquietzones
t i-bothqz      --barcode 3 --data 1234 --quietzones --noquietzones
t i-box         --barcode 3 --data 1234 --box --border 2
t i-bind        --barcode 3 --data 1234 --bind --border 2
t i-whitesp     --barcode 3 --data 1234 --whitesp 3 --vwhitesp 2
t i-xdim        --barcode 3 --data 1234567890 --scalexdimdp 0.495
t i-dotty       --barcode 3 --data 1234 --dotty
t i-reverse     --barcode 3 --data 1234 --reverse
t i-embed       --barcode 3 --data 1234567890 --embedfont

for r in 0 90 180 270; do
  t "i-r-$r"    --barcode 3 --data 1234567890 --rotate "$r"
done

# ITF-14. Pads to 13 digits, appends or checks the GS1 digit, and draws a
# bearer box of 5 unless the caller already set a box or a bind.
t t-short       --barcode 89 --data 1234567890
t t-13          --barcode 89 --data 1234567890123
t t-14          --barcode 89 --data 12345678901231
t t-bad         --barcode 89 --data 12345678901234
t t-one         --barcode 89 --data 0
t t-name        --barcode ITF14 --data 0000087654321
t t-fig         --barcode 89 --data 0950110153000
t t-fig2        --barcode 89 --data 1540014128876
t t-fig3        --barcode 89 --data 0950110153001
t t-vers        --barcode 89 --data 0000087654321 --vers 1
t t-paren       --barcode 89 --data "(01)12345678901231"
t t-paren13     --barcode 89 --data "(01)1234567890123"
t t-brack       --barcode 89 --data "[01]12345678901231"
t t-brack13     --barcode 89 --data "[01]1234567890123"
t t-ai          --barcode 89 --data 0112345678901231
t t-ai13        --barcode 89 --data 011234567890123
t t-zero        --barcode 89 --data 0012345678901231
t t-badpre      --barcode 89 --data "[00]12345678901231"
t t-mix         --barcode 89 --data "[01)12345678901231"
t t-alpha       --barcode 89 --data A
t t-alpha14     --barcode 89 --data 1234567890123A
t t-15          --barcode 89 --data 123456789012345
t t-empty       --barcode 89 --data ""
t t-gs1         --barcode 89 --data 12345678901231 --gs1

t t-notext      --barcode 89 --data 1234567890 --notext
t t-small       --barcode 89 --data 1234567890 --small
t t-bold        --barcode 89 --data 123 --bold
t t-height      --barcode 89 --data 1234567890 --height 20
t t-comp        --barcode 89 --data 1234567890 --compliantheight
t t-comp-low    --barcode 89 --data 1234567890 --compliantheight --height 5.7
t t-comp-ok     --barcode 89 --data 1234567890 --compliantheight --height 5.8
t t-scale       --barcode 89 --data 1234567890 --scale 1.5
t t-qz          --barcode 89 --data 1234 --quietzones
t t-noqz        --barcode 89 --data 1234 --noquietzones
t t-box0        --barcode 89 --data 123 --box --border 0
t t-box2        --barcode 89 --data 1234567890 --box --border 2
t t-bind        --barcode 89 --data 1234 --bind --border 4
t t-bindtop     --barcode 89 --data 1234 --bindtop --border 3
t t-border      --barcode 89 --data 1234 --border 8
t t-whitesp     --barcode 89 --data 1234 --whitesp 3 --vwhitesp 2
t t-xdim        --barcode 89 --data 1234567890 --scalexdimdp 0.495
t t-dotty       --barcode 89 --data 1234 --dotty
t t-reverse     --barcode 89 --data 1234 --reverse
t t-embed       --barcode 89 --data 1234567890 --embedfont
t t-textgap     --barcode 89 --data 1234 --textgap -5

for r in 0 90 180 270; do
  t "t-r-$r"    --barcode 89 --data 0950110153000 --rotate "$r"
done

for i in $(seq 1 8); do
  n=$(( (RANDOM % 12) + 1 ))
  d=$(head -c 40 /dev/urandom | tr -dc '0-9' | head -c "$n")
  t "i-rnd-$i"  --barcode 3 --data "$d"
  n=$(( (RANDOM % 13) + 1 ))
  d=$(head -c 40 /dev/urandom | tr -dc '0-9' | head -c "$n")
  t "t-rnd-$i"  --barcode 89 --data "$d"
done

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
