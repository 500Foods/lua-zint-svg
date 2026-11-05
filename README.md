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

The encoders shipped here follow the BSD-3-Clause library. The SVG for the five symbologies below matches the vendored 2.16.0 `zint` CLI byte for byte, Qt/PNG/GS1 Syntax Engine off, aside from the gaps named further down. The PDF stream is this library's own drawing of that same vector list. It is not a zint PDF, and it is not byte-compared to zint.

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

## Gaps

Invalid GS1 is still drawn. zint 2.16.0 refuses an Application Identifier whose length or check digit is wrong. This port draws a symbol for those inputs. Valid AIs, including `(01)`, `(10)`, `(17)`, and `(21)`, match.

QR automatic ECI and the Shift-JIS fallback are not implemented. Latin-1 QR matches. Input that is not Latin-1 and not the Kanji mode already in the encoder can differ, and the port may emit nothing where zint emits a symbol plus a warning.

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
Last updated at 2026-11-05 18:34:24 UTC
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Lua                             20            604           1683           3622
Markdown                         3            439              2           1678
Bourne Shell                     6             75            115            743
SVG                              5              0              0             66
YAML                             2              8             13             37
-------------------------------------------------------------------------------
SUM:                            36           1126           1813           6146
-------------------------------------------------------------------------------
6 Files were skipped (duplicate, binary, or without source code):
  gitattributes: 1
  gitignore: 1
  license: 1
  notice: 1
  q2hvdesaoe: 1
  rockspec: 1
```
<!--CLOC-END-->

## Sponsor / Donate / Support
If you find this work interesting, helpful, or valuable, or that it has saved you time, money, or both, please consider directly supporting these efforts financially via [GitHub Sponsors](https://github.com/sponsors/500Foods) or donating via [Buy Me a Pizza](https://www.buymeacoffee.com/andrewsimard500). Also, check out these other [GitHub Repositories](https://github.com/500Foods?tab=repositories&q=&sort=stargazers) that may interest you.
