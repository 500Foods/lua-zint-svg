#!/bin/bash
# ISBN (69) and standalone EAN-2 (11) / EAN-5 (12) against vendored zint 2.16.0.
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

# --------------------------------------------------------------- EAN-2 add-on
t e2-12          --barcode 11 --data 12
t e2-name        --barcode ean2 --data 5
t e2-alias       --barcode ean2addon --data 05
t e2-one         --barcode 11 --data 9
t e2-zero        --barcode 11 --data 00
t e2-qz          --barcode 11 --data 12 --quietzones
t e2-noqz        --barcode 11 --data 12 --noquietzones
t e2-qz-no       --barcode 11 --data 12 --quietzones --noquietzones
t e2-box         --barcode 11 --data 12 --box --border=2
t e2-bindtop     --barcode 11 --data 99 --bindtop --border=2
t e2-comp        --barcode 11 --data 12 --compliantheight
t e2-xdim        --barcode 11 --data 12 --scalexdimdp=0.33
t e2-notext      --barcode 11 --data 12 --notext
t e2-small       --barcode 11 --data 12 --small
t e2-scale       --barcode 11 --data 12 --scale=1.5
t e2-rev         --barcode 11 --data 12 --reverse
t e2-embed       --barcode 11 --data 12 --embedfont
t e2-ws          --barcode 11 --data 12 --whitesp=3 --vwhitesp=2

for r in 0 90 180 270; do
  t "e2-rot-$r"  --barcode 11 --data 12 --rotate "$r"
done

# Both sides refuse. The message text is not compared.
t e2-longbody    --barcode 11 --data 123
t e2-alpha       --barcode 11 --data 1A
t e2-plus        --barcode 11 --data '12+3'
t e2-empty       --barcode 11 --data ''
t e2-toolong     --barcode 11 --data 12345678901234567890

# --------------------------------------------------------------- EAN-5 add-on
t e5-12345       --barcode 12 --data 12345
t e5-name        --barcode ean5 --data 90
t e5-alias       --barcode ean5addon --data 12345
t e5-one         --barcode 12 --data 1
t e5-three       --barcode 12 --data 123
t e5-bind        --barcode 12 --data 12345 --bind --border=1
t e5-notext      --barcode 12 --data 12345 --notext
t e5-smallbold   --barcode 12 --data 12345 --small --bold
t e5-comp        --barcode 12 --data 12345 --compliantheight
t e5-qz          --barcode 12 --data 12345 --quietzones
t e5-box         --barcode 12 --data 12345 --box --border=2
t e5-scale       --barcode 12 --data 90 --scale=1.5
t e5-rev         --barcode 12 --data 12345 --reverse

for r in 0 90 180 270; do
  t "e5-rot-$r"  --barcode 12 --data 12345 --rotate "$r"
done

t e5-empty       --barcode 12 --data ''
t e5-long        --barcode 12 --data 123456
t e5-alpha       --barcode 12 --data ABC

# ---------------------------------------------------------------------- ISBN
t isbn13         --barcode 69 --data 9780306406157
t isbn-name      --barcode isbn --data 9780306406157
t isbn-alias     --barcode isbnx --data 9780306406157
t isbn10         --barcode 69 --data 0306406152
t isbn10-name    --barcode isbnx --data 0306406152
t sbn            --barcode 69 --data 306406152
t isbn-x         --barcode 69 --data 080442005X
t isbn-x-lower   --barcode 69 --data 080442005x
t isbn979        --barcode 69 --data 9791234567896
t isbn-add2      --barcode 69 --data '9780306406157+12'
t isbn-add5      --barcode 69 --data '9780306406157+12345'
t isbn-space     --barcode 69 --data '9780306406157 05'
t isbn-pad2      --barcode 69 --data '9780306406157+1'
t isbn-pad5      --barcode 69 --data '9780306406157+123'
t isbn-gap       --barcode 69 --data '9780306406157+12' --cols=9
t isbn-notext    --barcode 69 --data 9780306406157 --notext
t isbn-small     --barcode 69 --data 9780306406157 --small
t isbn-scale     --barcode 69 --data 9780306406157 --scale=1.5
t isbn-rev       --barcode 69 --data 9780306406157 --reverse
t isbn-comp      --barcode 69 --data 9780306406157 --compliantheight
t isbn-qz        --barcode 69 --data 9780306406157 --quietzones
t isbn-noqz      --barcode 69 --data 9780306406157 --noquietzones
t isbn-box       --barcode 69 --data 9780306406157 --box --border=2
t isbn-bind      --barcode 69 --data '9780306406157+12' --bind --border=2
t isbn-embed     --barcode 69 --data 9780306406157 --embedfont
t isbn-ws        --barcode 69 --data '9780306406157+12345' --whitesp=4

for r in 0 90 180 270; do
  t "isbn-rot-$r" --barcode 69 --data 9780306406157 --rotate "$r"
done

# Magazine EAN-13 with a 2-digit add-on. Same drawing path as an attached add-on.
t mag            --barcode 15 --data '9771234567898+05'

# EAN-8 accepts an add-on and warns. Stderr is compared; exit codes are not.
t ean8-add       --barcode 10 --data '1234567+12'

t isbn-bad13     --barcode 69 --data 9780306406158
t isbn-bad10     --barcode 69 --data 0306406153
t isbn-short     --barcode 69 --data 1234
t isbn-mid       --barcode 69 --data 978030640615
t isbn-14        --barcode 69 --data 97803064061570
t isbn-x13       --barcode 69 --data 978030640615X
t isbn-xmid      --barcode 69 --data 03064X6152
t isbn-xbad      --barcode 69 --data 030640615x
t isbn-addonx    --barcode 69 --data '9780306406157+1X'
t isbn-twosep    --barcode 69 --data '9780306406157+12+34'
t isbn-979bad    --barcode 69 --data 9761234567896
t isbn-empty     --barcode 69 --data ''
t isbn-gs1       --barcode 69 --gs1 --data 9780306406157
t isbn-alpha     --barcode 69 --data '9780306406157A'

echo
echo "pass=$pass fail=$fail"
for f in "${failed[@]}"; do echo "  FAIL $f"; done
exit $((fail > 0 ? 1 : 0))
