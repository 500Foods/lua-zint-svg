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
| Code 128 (suppress C) | 60 | yes | vectors |
| Flattermarken | 28 | yes | vectors |
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
| GS1 DataBar Omnidirectional | 29 | yes | vectors |
| GS1 DataBar Stacked Omnidirectional | 80 | yes | vectors |
| GS1 DataBar Expanded | 31 | yes | vectors |
| GS1 DataBar Expanded Stacked | 81 | yes | vectors |
| Data Matrix | 71 | yes | vectors |
| PDF417 | 55 | yes | vectors |
| Compact PDF417 | 56 | yes | vectors |
| MaxiCode | 57 | yes | vectors |
| USPS Intelligent Mail | 85 | yes | vectors |
| Aztec | 92 | yes | vectors |
| EAN-2 add-on | 11 | yes | vectors |
| EAN-5 add-on | 12 | yes | vectors |
| ISBN | 69 | yes | vectors |

EAN-13 takes 12 digits and appends the check digit, or 13 digits and checks the one you supplied. EAN-8 does the same with 7 or 8 digits. UPC-E takes 6 digits, or 7 with a number system of 0 or 1, and id 38 requires the check digit. Short digit strings are padded with leading zeroes. An EAN-8 add-on is drawn and warned as non-standard.

Interleaved 2 of 5 takes digits. An odd count grows a leading zero. `--vers 1` appends a GS1 check digit and shows it; `--vers 2` appends it and leaves it off the human-readable line. ITF-14 takes up to 14 digits, pads to 13, and appends or checks the GS1 check digit. A `(01)`, `[01]`, or leading `01` of the right length is stripped. It draws a bearer box of 5 modules unless a box or bind is already set. ITF-14 always has a 10-module quiet zone. Interleaved 2 of 5 adds that zone only with `--quietzones`.

NVE-18 is the 18-digit SSCC, drawn as GS1-128. It takes up to 18 digits, pads to 17, and appends or checks the GS1 check digit. A `(00)`, `[00]`, or leading `00` of the right length is stripped. The name on the command line is `nve18`. Its quiet zone is added with `--quietzones`.

GS1 DataBar Omnidirectional takes up to 14 digits. Thirteen are padded and the check digit is appended. Fourteen must include the right check digit. A `(01)`, `[01]`, or leading `01` of the right length is stripped. The human-readable line is `(01)` plus the 14-digit GTIN. Stacked Omnidirectional is the same symbol in two rows, and it has no human-readable line. Neither variant has a quiet zone. `--gs1` is refused: this is a GTIN, not an element string. The short names are `dbaromn` and `dbaromnstk`.

GS1 DataBar Expanded takes a GS1 element string, the same bracketed Application Identifiers as GS1-128. Expanded Stacked is the same symbol broken into rows. `--cols` sets the columns per row (1 to 11, default 2). `--rows` sets the maximum rows (2 to 11) when `--cols` is omitted. Stacked symbols have no human-readable line. Neither variant has a quiet zone. The short names are `dbarexp` and `dbarexpstk`.

Data Matrix takes bytes. The short name is `datamatrix`. It has no human-readable line. `--vers` picks a size from 1 to 48 (square sizes, then rectangular, then DMRE). `--square` keeps the symbol square. `--dmre` allows the rectangular DMRE sizes. `--fast` uses the look-ahead encodation. A 144x144 symbol uses the de-facto ECC arrangement unless `--dmiso144` is set. The quiet zone is one module on each side, and only with `--quietzones`. `--gs1` encodes an element string. `--gssep` stores the GS separator as data. `--init` writes a reader-initialisation symbol, and is refused in GS1 mode. `--dotty` draws the modules as dots.

EAN-2 and EAN-5 are the magazine add-ons, drawn on their own. The short names are `ean2` and `ean5`. A short digit string is padded with leading zeroes. The digits sit above the bars. Each has a 5-module quiet zone on the right. The same add-on can hang off an EAN-13, a UPC-A, or a UPC-E: put `+` or a space and the digits after the body. EAN-8 accepts one and warns that it is non-standard.

ISBN is drawn as EAN-13. The short names are `isbn` and `isbnx`. An ISBN-13 must begin with 978 or 979 and include its check digit. An ISBN-10, or a 9-digit SBN, is turned into 978 plus the body, and the EAN-13 check digit replaces the ISBN check. The human-readable line is the EAN-13 digits. A `+` or a space and two or five digits adds the magazine add-on.

Code 128 suppress C is Code 128 that never uses code set C. A run of digits stays in set A or B. The short names are `code128ab` and `code128b`. The quiet zone is the same 10 modules as Code 128, and only with `--quietzones`.

Flattermarken draws one mark per digit and has no human-readable line. The short name is `flat`. It takes up to 128 digits. It has no quiet zone.

PDF417 takes bytes and has no human-readable line. The short name is `pdf417`. Compact PDF417 drops the right row indicator and the stop pattern. Its short names are `pdf417comp` and `pdf417trunc`. `--secure` sets the error correction level from 0 to 8. The default lets the symbol choose. `--cols` sets the data columns from 1 to 30. `--rows` sets the rows from 3 to 90. The quiet zone is two modules on each side, and only with `--quietzones`.

MaxiCode draws a hexagonal grid and a bullseye. The short name is `maxicode`. It has no human-readable line. The PDF form draws the same hexagons and rings. `--mode` selects modes 2 to 6. With no mode and no primary message the symbol is mode 4. Modes 2 and 3 read `--primary`: a numeric postcode, country, and service class select mode 2, and any other postcode selects mode 3. `--scmvv` sets the Structured Carrier Message version. The quiet zone is one module on each side, and only with `--quietzones`. `--dotty` is refused.

Aztec takes bytes. The short names are `aztec` and `azteccode`. It has no human-readable line and no quiet zone. `--vers` picks a size from 1 to 36. Sizes 1 to 4 are compact. `--secure` sets the error correction level from 1 to 4. The default is 2. `--gs1` encodes an element string. `--init` writes a reader-initialisation symbol, and is refused in GS1 mode. `--dotty` draws the modules as dots.

USPS Intelligent Mail takes a 20-digit tracking code, and an optional ZIP of 5, 9, or 11 digits after a hyphen. The short name is `uspsimail`. It has no human-readable line. The quiet zone is added with `--quietzones`.

UPC and EAN human-readable digits are placed at OCR-B advances. The report writer embeds OCR-B and uses those positions. The PDF form names Helvetica as a placeholder font, so the bars match the SVG while the digit slots follow OCR-B. SVG draws those digits in the bundled OCR-B face and every other symbol in Arimo. `--embedfont` inlines the SVG face.

This release draws those twenty-eight. Not yet: Code 11, Code 2 of 5 Standard, IATA, Data Logic, and Industrial, Extended Code 39, Codabar, Code 93, Code 16k, Code 49, Telepen, MSI Plessey, Plessey, Code 32, VIN, LOGMARS, Pharmacode, PZN, GS1 DataBar Limited and Stacked, Micro QR, rMQR, Han Xin, DotCode, Grid Matrix, Ultracode, Code One, MicroPDF417, Codablock-F, the other postal symbols, the HIBC family, DAFT, DPD, Channel Code, BC412, DX Film Edge, and the composite symbols.

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
Last updated at 2026-11-05 21:22:06 UTC
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Lua                             26            954           2016          10426
Markdown                         3            444              2           1701
Bourne Shell                    11            131            133           1282
SVG                             11              0              0            153
YAML                             2              8             13             37
-------------------------------------------------------------------------------
SUM:                            53           1537           2164          13599
-------------------------------------------------------------------------------
6 Files were skipped (duplicate, binary, or without source code):
  gi8pogfomp: 1
  gitattributes: 1
  gitignore: 1
  license: 1
  notice: 1
  rockspec: 1
```
<!--CLOC-END-->

## Sponsor / Donate / Support
If you find this work interesting, helpful, or valuable, or that it has saved you time, money, or both, please consider directly supporting these efforts financially via [GitHub Sponsors](https://github.com/sponsors/500Foods) or donating via [Buy Me a Pizza](https://www.buymeacoffee.com/andrewsimard500). Also, check out these other [GitHub Repositories](https://github.com/500Foods?tab=repositories&q=&sort=stargazers) that may interest you.
