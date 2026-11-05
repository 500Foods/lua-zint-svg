# lua-zint-svg

Pure Lua barcodes for a Lua report generator. No libzint, no image library, and no network at runtime. The module returns an SVG document, or a PDF Form XObject content stream the report writer can place on a page.

```lua
local zint = require "zint"

local svg = zint.barcode({
  barcode = "qrcode",
  data = "https://example.invalid/report",
})

local form = zint.barcode({
  barcode = 34, -- UPC-A
  data = "12345678901",
  filetype = "PDF",
})
-- form.kind == "form-xobject"
-- form.bbox, form.content, form.resources
-- The writer supplies the object number, /Length, the Form dictionary, and Do.
```

`bin/lua-zint` is the same library from the shell. Values are strings, so float parsing happens inside the port.

This is an independent port of [zint](https://github.com/zint/zint) 2.16.0 (19 December 2025, commit `55541e1`), by Robin Stuart and the zint authors. Upstream lives at [zint.org.uk](https://zint.org.uk). It is not affiliated with, endorsed by, or sponsored by the zint project. See [NOTICE](NOTICE).

The encoders shipped here follow the BSD-3-Clause library. The SVG for the five symbologies below matches the vendored 2.16.0 `zint` CLI byte for byte, Qt/PNG/GS1 Syntax Engine off. The PDF stream is this library's own drawing of that same vector list. It is not a zint PDF, and it is not byte-compared to zint.

`--scalexdimdp` with an `in` or `dpi` suffix follows the 2.16.0 CLI, which divides by 25.4.

## Symbologies

| symbology | id | SVG | PDF form |
|---|---:|---|---|
| Code 39 | 8 | matches 2.16.0 | vectors |
| GS1-128 | 16 | matches 2.16.0 | vectors |
| Code 128 | 20 | matches 2.16.0 | vectors |
| UPC-A | 34 | matches 2.16.0 | vectors |
| UPC-A, check digit supplied | 35 | matches 2.16.0 | vectors |
| QR Code | 58 | matches 2.16.0 | vectors |

`test/compare.sh` is that claim. Against this pin it ran `flags.sh` (171 matched, 20 refused by both), `colourdiff.sh` (42/42), `upca.sh` (253), `fuzz.sh` (165 over 5 rounds), and `stressqr.sh` (279 matched, 5 skipped because zint wrote no file, versions 40/40, masks 0–7, ECC L/M/Q/H). `test/smoke.lua` repeats five of those SVGs with Lua alone.

Not yet, from the same `zint.h`: Code 11, the 2 of 5 family, Extended Code 39, EAN-8, EAN-13, the standalone EAN add-ons, Codabar, Code 93, Code 16k, Code 49, Telepen, UPC-E, MSI Plessey, Plessey, ITF-14, ISBN, Code 32, VIN, LOGMARS, Pharmacode, PZN, GS1 DataBar (all variants), Data Matrix, Aztec, MaxiCode, Micro QR, rMQR, Han Xin, DotCode, Grid Matrix, Ultracode, Code One, PDF417, MicroPDF417, Codablock-F, the postal symbologies, the HIBC family, DAFT, DPD, Channel Code, BC412, DX Film Edge, and the composite symbols. The full id list is in [LUA-ZINT-SVG-PLAN.md](LUA-ZINT-SVG-PLAN.md).

## Consistency

GS1 checks match zint 2.16.0 built without the GS1 Syntax Engine. An unknown Application Identifier is Error 260 and a bad length is Error 259, and neither writes a file. A bad check digit or a bad date is Warning 261, and the SVG is the one zint writes. Valid AIs, including `(01)`, `(10)`, `(17)`, and `(21)`, stay byte-identical.

QR Latin-1 stays byte-identical. Shift JIS warns 760 and is drawn with no ECI header. Input that fits neither Latin-1 nor Shift JIS is drawn again under an automatic ECI and warns 222.

An unknown `filetype` is an error: `Error 142: File type '...' not supported`.

UPC-A human-readable digits in the PDF stream are Helvetica, named and not embedded. The bars are the same geometry as the SVG. The digit widths are not OCR-B. The report writer can supply a font if the widths matter.

## Fonts

SVG text uses Arimo (Steve Matteson, 2013, Apache-2.0) or OCR-B (Matthew Skala, 2011, based on Norbert Schwarz, unrestricted). One `@font-face` per file. `--embedfont` inlines it. Details are in [NOTICE](NOTICE).

## Speed

A version-40 QR took a few seconds in the August port. That is fine for a report page. Measure it before putting it in a tight loop.

## Build the comparator

The vendored tree is the reading copy and the oracle. Its build directory is gitignored.

```bash
test/compare.sh
lua test/smoke.lua
lua test/pdf.lua
```

## Install

```bash
luarocks --lua-version=5.5 make
```

The rockspec depends on `lua >= 5.5`. The default `luarocks` on some machines is bound to Lua 5.4, which cannot satisfy that. Lua 5.5.1 is what the suite runs on.

LuaRocks 3.9.2 reads `LUA_VERSION_NUM` as a literal in `lua.h`. Lua 5.5 writes that macro as an expression, so `luarocks make` reports that the header does not match. Point `LUA_INCDIR` at a header that contains `#define LUA_VERSION_NUM 505`. This rock builds no C.

## Repository Information
[![Count Lines of Code](https://github.com/500foods/lua-zint-svg/actions/workflows/main.yml/badge.svg)](https://github.com/500foods/lua-zint-svg/actions/workflows/main.yml)
<!--CLOC-START -->
```cloc
Last updated at 2026-11-05 19:08:31 UTC
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Lua                             23            762           1782           6805
Markdown                         3            440              2           1679
Bourne Shell                     6             75            115            743
SVG                              5              0              0             66
YAML                             2              8             13             37
-------------------------------------------------------------------------------
SUM:                            39           1285           1912           9330
-------------------------------------------------------------------------------
```
<!--CLOC-END-->

## Sponsor / Donate / Support
If you find this work interesting, helpful, or valuable, or that it has saved you time, money, or both, please consider directly supporting these efforts financially via [GitHub Sponsors](https://github.com/sponsors/500Foods) or donating via [Buy Me a Pizza](https://www.buymeacoffee.com/andrewsimard500). Also, check out these other [GitHub Repositories](https://github.com/500Foods?tab=repositories&q=&sort=stargazers) that may interest you.
