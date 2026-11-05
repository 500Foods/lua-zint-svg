#!/bin/bash
# Oracle and port default to this repo. Override ZINT and LUA_ZINT to point
# elsewhere. The system zint is an older release and is not the oracle.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ZINT:=$ROOT/vendor/zint/build/frontend/zint}"
: "${LUA_ZINT:=$ROOT/bin/lua-zint}"
export LC_ALL=C
# Compare real zint against the Lua port across every option the wrapper now
# accepts. Fixed data throughout, so a failure is reproducible by hand.
# Usage: flags.sh [case-glob]
set -uo pipefail
export LC_ALL=C
FILTER="${1:-*}"

C39=ABC-123
C39L=ABCDEFGHIJKLMNOPQRSTUVWXYZ012345          # 32 chars: compliant height > 50
C128=Ab-129
C128D=1234567890
GS1='[01]40063813339314[10]ABC12'

# id|barcode|data|extra args (space separated, "-" for none)
CASES='
# ---- baselines (no new flags), to prove the refactor is inert
base-c39|8|ABC-123|-
base-c128|20|Ab-129|-
base-gs1|16|[01]40063813339314[10]ABC12|-

# ---- --scale
scale-0.5|8|ABC-123|--scale=0.5
scale-1|8|ABC-123|--scale=1
scale-2.5|20|Ab-129|--scale=2.5
scale-0.33|20|Ab-129|--scale=0.33
scale-3.7|16|[01]40063813339314[10]ABC12|--scale=3.7
scale-0.01|8|ABC-123|--scale=0.01
scale-min-warn|8|ABC-123|--scale=0.005
scale-10|8|ABC-123|--scale=10
scale-7sig|20|Ab-129|--scale=1.234567
scale-eq-form|20|Ab-129|--scale 1.75

# ---- --scalexdimdp (overrides --scale whichever order)
sxd-mm|8|ABC-123|--scalexdimdp=0.33mm
sxd-mm-dpi|20|Ab-129|--scalexdimdp=0.5mm,600dpi
sxd-in-dpmm|20|Ab-129|--scalexdimdp=0.02in,12dpmm
sxd-default-x|16|[01]40063813339314[10]ABC12|--scalexdimdp=0,600dpi
sxd-1mm300|8|ABC-123|--scalexdimdp=1mm,300dpi
sxd-bare|8|ABC-123|--scalexdimdp=0.264583mm
sxd-nounit|8|ABC-123|--scalexdimdp=0.5
sxd-upper|8|ABC-123|--scalexdimdp=0.5MM,300DPI
sxd-oor-x|8|ABC-123|--scalexdimdp=20mm
sxd-oor-dpmm|8|ABC-123|--scalexdimdp=1mm,2000dpmm
sxd-beats-scale|20|Ab-129|--scale=9 --scalexdimdp=0.5mm,600dpi
sxd-after-scale|20|Ab-129|--scalexdimdp=0.5mm,600dpi --scale=9
sxd-clamp-low|8|ABC-123|--scalexdimdp=0.01mm,12dpmm
sxd-clamp-high|8|ABC-123|--scalexdimdp=9mm,900dpmm

# ---- --height / --heightperrow
height-1|8|ABC-123|--height=1
height-12.7|20|Ab-129|--height=12.7
height-30|16|[01]40063813339314[10]ABC12|--height=30
height-min|8|ABC-123|--height=0.5
height-max|8|ABC-123|--height=2000
height-under|8|ABC-123|--height=0.4
height-over|8|ABC-123|--height=3000
heightperrow|20|Ab-129|--height=17 --heightperrow
heightperrow-c39|8|ABC-123|--height=23.5 --heightperrow

# ---- --compliantheight
ch-c39-short|8|ABC-123|--compliantheight
ch-c39-long|8|ABCDEFGHIJKLMNOPQRSTUVWXYZ012345|--compliantheight
ch-c128|20|Ab-129|--compliantheight
ch-gs1|16|[01]40063813339314[10]ABC12|--compliantheight
ch-gs1-height|16|[01]40063813339314[10]ABC12|--compliantheight --height=40
ch-c39-long-height|8|ABCDEFGHIJKLMNOPQRSTUVWXYZ012345|--compliantheight --height=12

# ---- --border with --bind / --bindtop / --box
bind-only|8|ABC-123|--bind
border-only|8|ABC-123|--border=5
bind-1|8|ABC-123|--bind --border=1
bind-5|20|Ab-129|--bind --border=5
bind-0|20|Ab-129|--bind --border=0
bindtop-5|20|Ab-129|--bindtop --border=5
box-5|20|Ab-129|--box --border=5
box-1|16|[01]40063813339314[10]ABC12|--box --border=1
box-12|8|ABC-123|--box --border=12
bind-box|8|ABC-123|--bind --box --border=3
bind-notext|20|Ab-129|--bind --border=4 --notext
box-notext|20|Ab-129|--box --border=4 --notext
bindtop-notext|20|Ab-129|--bindtop --border=4 --notext
border-max|8|ABC-123|--bind --border=1000
border-oor|8|ABC-123|--bind --border=1001
box-whitesp|20|Ab-129|--box --border=2 -w 4 --vwhitesp=3
box-quiet|16|[01]40063813339314[10]ABC12|--box --border=2 --quietzones

# ---- whitespace and quiet zones
whitesp-0|8|ABC-123|-w 0
whitesp-1|8|ABC-123|-w 1
whitesp-10|20|Ab-129|-w 10
whitesp-long|20|Ab-129|--whitesp=6
vwhitesp-1|8|ABC-123|--vwhitesp=1
vwhitesp-7|20|Ab-129|--vwhitesp=7
whitesp-both|16|[01]40063813339314[10]ABC12|-w 3 --vwhitesp=3
whitesp-oor|8|ABC-123|-w 1001
quietzones|8|ABC-123|--quietzones
quietzones-c128|20|Ab-129|--quietzones
quietzones-gs1|16|[01]40063813339314[10]ABC12|--quietzones
noquietzones|8|ABC-123|--noquietzones
noquietzones-c128|20|Ab-129|--noquietzones
quiet-both|20|Ab-129|--quietzones --noquietzones
quiet-whitesp|8|ABC-123|--quietzones -w 2

# ---- text
notext|8|ABC-123|--notext
notext-c128|20|Ab-129|--notext
small|8|ABC-123|--small
small-c128|20|Ab-129|--small
bold|8|ABC-123|--bold
bold-c128|20|Ab-129|--bold
small-bold|20|Ab-129|--small --bold
notext-bold|20|Ab-129|--notext --bold
textgap-min|8|ABC-123|--textgap=-5
textgap-neg|20|Ab-129|--textgap=-2
textgap-zero|20|Ab-129|--textgap=0
textgap-1|20|Ab-129|--textgap=1
textgap-2.5|20|Ab-129|--textgap=2.5
textgap-max|8|ABC-123|--textgap=10
textgap-under|8|ABC-123|--textgap=-6
textgap-over|8|ABC-123|--textgap=11
textgap-small|20|Ab-129|--textgap=3 --small
textgap-frac|20|Ab-129|--textgap=0.33

# ---- --embedfont
embedfont|8|ABC-123|--embedfont
embedfont-c128|20|Ab-129|--embedfont
embedfont-gs1|16|[01]40063813339314[10]ABC12|--embedfont
embedfont-notext|20|Ab-129|--embedfont --notext
embedfont-bold|20|Ab-129|--embedfont --bold --small

# ---- --guarddescent (inert for linear, but must still match)
guard-0|8|ABC-123|--guarddescent=0
guard-12.5|20|Ab-129|--guarddescent=12.5
guard-max|8|ABC-123|--guarddescent=50
guard-oor|8|ABC-123|--guarddescent=51

# ---- --dotty: rejected for every linear symbology, both sides must refuse
dotty-c39|8|ABC-123|--dotty
dotty-c128|20|Ab-129|--dotty
dotty-gs1|16|[01]40063813339314[10]ABC12|--dotty
dotsize-no-dotty|20|Ab-129|--dotsize=1.5
dotsize-oor|20|Ab-129|--dotsize=0.001
dotsize-frac|20|Ab-129|--dotsize=0.85

# ---- --rotate
rotate-0|8|ABC-123|--rotate=0
rotate-90|8|ABC-123|--rotate=90
rotate-180|8|ABC-123|--rotate=180
rotate-270|8|ABC-123|--rotate=270
rotate-bad|8|ABC-123|--rotate=45
rotate-90-c128|20|Ab-129|--rotate=90
rotate-180-gs1|16|[01]40063813339314[10]ABC12|--rotate=180
rotate-270-notext|20|Ab-129|--rotate=270 --notext
rotate-90-box|20|Ab-129|--rotate=90 --box --border=3
rotate-180-scale|8|ABC-123|--rotate=180 --scale=2.5
rotate-270-whitesp|20|Ab-129|--rotate=270 -w 4 --vwhitesp=2

# ---- colour
reverse|8|ABC-123|-r
reverse-long|20|Ab-129|--reverse
reverse-nobg|20|Ab-129|--reverse --nobackground
reverse-fg|20|Ab-129|--reverse --fg=00FF00

# ---- --init (reader initialisation)
init-c128|20|Ab-129|--init
init-c128-digits|20|1234567890|--init
init-c128-lower|20|abcdef|--init
init-c128-upper|20|ABCDEF|--init
init-c39|8|ABC-123|--init
init-gs1|16|[01]40063813339314[10]ABC12|--init

# ---- --esc
esc-tab|20|A\tB|--esc
esc-hex|20|\x41\x42\x43|--esc
esc-dec|20|\d065\d066|--esc
esc-oct|20|\o101\o102|--esc
esc-backslash|20|A\\B|--esc
esc-gs|20|A\GB|--esc
esc-esc|20|A\eB|--esc
esc-uni|20|café|--esc
esc-uni-cap|20|caf\U0000e9|--esc
esc-nul|20|A\0B|--esc
esc-none|20|Ab-129|--esc
esc-c39|8|ABC\x2D123|--esc
esc-gs1|16|[01]40063813339314[10]ABC\x3112|--esc
esc-gs1-parens|16|(01)40063813339314(10)ABC\x3112|--esc --gs1parens
esc-bad|20|A\qB|--esc
esc-short-hex|20|A\x4|--esc
esc-off|20|A\tB|-

# ---- UTF-8 -> ISO 8859-1 (library.c reduced_charset)
uni-acute|20|café|-
uni-c39|8|CAFÉ|-
uni-latin1-hi|20|ÿ|-
uni-latin1-a0|20|A B|--esc
uni-c1-gap|20|AB|--esc
uni-beyond|20|AĀB|--esc
uni-euro|20|€|-
uni-bom|20|﻿ABC|--esc
uni-bom-only|20|﻿|--esc
uni-badutf8|20|A\xC3|--esc
uni-gs1mode|16|[01]40063813339314|--gs1

# ---- library.c field ranges, tighter than the ones in main.c
lib-border-101|20|Ab-129|--bind --border=101
lib-border-100|20|Ab-129|--bind --border=100
lib-whitesp-101|20|Ab-129|-w 101
lib-whitesp-100|20|Ab-129|-w 100
lib-vwhitesp-101|20|Ab-129|--vwhitesp=101
lib-scale-201|20|Ab-129|--scale=201
lib-scale-200|20|Ab-129|--scale=200
lib-dotsize-21|20|Ab-129|--dotsize=21
lib-dotsize-20|20|Ab-129|--dotsize=20
lib-height-2001|20|Ab-129|--height=2001
lib-guarddescent-51|20|Ab-129|--guarddescent=51
lib-textgap-11|20|Ab-129|--textgap=11
lib-empty|20||-

# ---- --gs1 on symbologies that do not support it
gs1-c39|8|[01]40063813339314|--gs1
gs1-c128|20|[01]40063813339314|--gs1
gs1-128|16|[01]40063813339314|--gs1

# ---- --extraesc (Code 128 only)
xesc-a|20|\^A123|--extraesc
xesc-b|20|\^B123|--extraesc
xesc-c|20|\^C1234|--extraesc
xesc-ab|20|\^AABC\^Babc|--extraesc
xesc-bc|20|\^BAb\^C123456|--extraesc
xesc-caret|20|A\^^B|--extraesc
xesc-caret-only|20|\^^|--extraesc
xesc-mid|20|AB\^C1234CD|--extraesc
xesc-both|20|\^A123|--extraesc --esc
xesc-esc-first|20|\^B\x41\x42|--extraesc --esc
xesc-c39|8|ABC-123|--extraesc
xesc-noflag|20|\^A123|-
xesc-odd-c|20|\^C12345|--extraesc

# ---- combinations
combo-1|8|ABC-123|--scale=2 --bind --border=3 --small --textgap=2
combo-2|20|Ab-129|--box --border=2 --bold --embedfont --rotate=90
combo-3|16|[01]40063813339314[10]ABC12|--compliantheight --quietzones -w 2 --scale=1.5
combo-4|20|1234567890|--init --notext --bind --border=1 --reverse
combo-5|8|ABCDEFGHIJKLMNOPQRSTUVWXYZ012345|--compliantheight --rotate=270 --embedfont
combo-6|20|Ab-129|--scalexdimdp=0.5mm,600dpi --box --border=4 --vwhitesp=2 --small
'

pass=0; fail=0; errmatch=0
while IFS='|' read -r id bc data extra; do
  [ -z "$id" ] && continue
  case "$id" in \#*) continue ;; esac
  case "$id" in $FILTER) ;; *) continue ;; esac
  args=(); [ "$extra" != "-" ] && read -ra args <<< "$extra"
  rm -f /tmp/fa.svg /tmp/fb.svg
  "$ZINT" -b "$bc" -d "$data" --filetype=SVG -o /tmp/fa.svg "${args[@]}" >/dev/null 2>&1
  "$LUA_ZINT" -b "$bc" -d "$data" --filetype=SVG -o /tmp/fb.svg "${args[@]}" >/tmp/ferr.txt 2>&1
  a=0; b=0
  [ -f /tmp/fa.svg ] && a=1
  [ -f /tmp/fb.svg ] && b=1
  if [ $a -eq 0 ] && [ $b -eq 0 ]; then
    errmatch=$((errmatch+1))
    echo "err  $id  (both refused)  data=[$data] ${args[*]}"
  elif [ $a -ne $b ]; then
    fail=$((fail+1))
    echo "FAIL $id  zint-wrote=$a lua-wrote=$b  data=[$data] ${args[*]}"
    [ -s /tmp/ferr.txt ] && sed 's/^/      lua: /' /tmp/ferr.txt | head -4
  elif cmp -s /tmp/fa.svg /tmp/fb.svg; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL $id  data=[$data] ${args[*]}"
    diff <(fold -w110 /tmp/fa.svg) <(fold -w110 /tmp/fb.svg) | head -8 | sed 's/^/      /'
  fi
done <<< "$CASES"
echo "pass=$pass fail=$fail both-refused=$errmatch"
exit $((fail > 0 ? 1 : 0))
