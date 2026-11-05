# lua-zint-svg

Pure Lua barcodes. No C library, no image library, and no network at runtime. The module returns an SVG document, or a PDF Form XObject content stream the report writer can place on a page.

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

`lua-zint` is the same library from the shell. Values are strings, so float parsing happens inside the library.

`--scalexdimdp` with an `in` or `dpi` suffix divides by 25.4.

## Symbologies

| symbology | id | SVG | PDF form |
|---|---:|---|---|
| Code 39 | 8 | yes | vectors |
| GS1-128 | 16 | yes | vectors |
| Code 128 | 20 | yes | vectors |
| EAN-8 | 10 | yes | vectors |
| EAN-13 | 15 | yes | vectors |
| UPC-A | 34 | yes | vectors |
| UPC-A, check digit supplied | 35 | yes | vectors |
| UPC-E | 37 | yes | vectors |
| UPC-E, check digit supplied | 38 | yes | vectors |
| Interleaved 2 of 5 | 3 | yes | vectors |
| ITF-14 | 89 | yes | vectors |
| NVE-18 (SSCC) | 75 | yes | vectors |
| QR Code | 58 | yes | vectors |

EAN-13 takes 12 digits and appends the check digit, or 13 digits and checks the one you supplied. EAN-8 does the same with 7 or 8 digits. UPC-E takes 6 digits, or 7 with a number system of 0 or 1, and id 38 requires the check digit. Short digit strings are padded with leading zeroes. An EAN-8 add-on is drawn and warned as non-standard.

Interleaved 2 of 5 takes digits. An odd count grows a leading zero. `--vers 1` appends a GS1 check digit and shows it; `--vers 2` appends it and leaves it off the human-readable line. ITF-14 takes up to 14 digits, pads to 13, and appends or checks the GS1 check digit. A `(01)`, `[01]`, or leading `01` of the right length is stripped. It draws a bearer box of 5 modules unless a box or bind is already set. ITF-14 always has a 10-module quiet zone. Interleaved 2 of 5 adds that zone only with `--quietzones`.

NVE-18 is the 18-digit SSCC, drawn as GS1-128. It takes up to 18 digits, pads to 17, and appends or checks the GS1 check digit. A `(00)`, `[00]`, or leading `00` of the right length is stripped. The name on the command line is `nve18`. Its quiet zone is added with `--quietzones`.

UPC and EAN human-readable digits are placed at OCR-B advances. The report writer embeds OCR-B and uses those positions. The PDF form names Helvetica as a placeholder font, so the bars match the SVG while the digit slots follow OCR-B. SVG draws those digits in the bundled OCR-B face and every other symbol in Arimo. `--embedfont` inlines the SVG face.

This release draws those thirteen. Not yet: Code 11, Code 2 of 5 Standard, IATA, Data Logic, and Industrial, Extended Code 39, the standalone EAN add-ons, Codabar, Code 93, Code 16k, Code 49, Telepen, MSI Plessey, Plessey, ISBN, Code 32, VIN, LOGMARS, Pharmacode, PZN, GS1 DataBar (all variants), Data Matrix, Aztec, MaxiCode, Micro QR, rMQR, Han Xin, DotCode, Grid Matrix, Ultracode, Code One, PDF417, MicroPDF417, Codablock-F, the postal symbols, the HIBC family, DAFT, DPD, Channel Code, BC412, DX Film Edge, and the composite symbols.

## Behaviour

An unknown Application Identifier is Error 260 and a bad length is Error 259, and neither writes a file. A bad check digit or a bad date is Warning 261, and the symbol is still drawn. Valid AIs, including `(01)`, `(10)`, `(17)`, and `(21)`, encode as usual.

QR text that fits Latin-1 is encoded as Latin-1. Shift JIS warns 760 and is drawn with no ECI header. Input that fits neither Latin-1 nor Shift JIS is drawn again under an automatic ECI and warns 222.

An unknown `filetype` is an error: `Error 142: File type '...' not supported`.

The PDF form names Helvetica and leaves the face to the report writer. UPC and EAN digit positions are the OCR-B ones described beside the symbology table.

## Fonts

SVG text uses Arimo (Steve Matteson, 2013, Apache-2.0) or OCR-B (Matthew Skala, 2011, based on Norbert Schwarz, unrestricted). One `@font-face` per file. `--embedfont` inlines it. Details are in [NOTICE](NOTICE).

## Speed

A version-40 QR takes a few seconds. That is fine for a report page. Measure it before putting it in a tight loop.

## Tests

```bash
lua test/smoke.lua
lua test/pdf.lua
```

## Install

```bash
luarocks --lua-version=5.5 install lua-zint-svg
```

https://luarocks.org/modules/500foods/lua-zint-svg

From a clone of this repository:

```bash
luarocks --lua-version=5.5 make
```

The rockspec depends on `lua >= 5.5`. The default `luarocks` on some machines is bound to Lua 5.4, which cannot satisfy that. Lua 5.5.1 is what the suite runs on.

LuaRocks 3.9.2 reads `LUA_VERSION_NUM` as a literal in `lua.h`. Lua 5.5 writes that macro as an expression, so `luarocks make` reports that the header does not match. Point `LUA_INCDIR` at a header that contains `#define LUA_VERSION_NUM 505`. This rock builds no C.

## Repository Information
[![Count Lines of Code](https://github.com/500foods/lua-zint-svg/actions/workflows/main.yml/badge.svg)](https://github.com/500foods/lua-zint-svg/actions/workflows/main.yml)
<!--CLOC-START -->
```cloc
Last updated at 2026-11-05 20:35:48 UTC
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Lua                             24            872           1939           7637
Markdown                         3            443              2           1698
Bourne Shell                    11            131            133           1281
SVG                             11              0              0            153
YAML                             2              8             13             37
-------------------------------------------------------------------------------
SUM:                            51           1454           2087          10806
-------------------------------------------------------------------------------
26 Files were skipped (duplicate, binary, or without source code):
  br: 20
  bsxd2oe1wy: 1
  gitattributes: 1
  gitignore: 1
  license: 1
  notice: 1
  rockspec: 1
```
<!--CLOC-END-->

## Sponsor / Donate / Support
If you find this work interesting, helpful, or valuable, or that it has saved you time, money, or both, please consider directly supporting these efforts financially via [GitHub Sponsors](https://github.com/sponsors/500Foods) or donating via [Buy Me a Pizza](https://www.buymeacoffee.com/andrewsimard500). Also, check out these other [GitHub Repositories](https://github.com/500Foods?tab=repositories&q=&sort=stargazers) that may interest you.
