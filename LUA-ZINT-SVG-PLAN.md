# lua-zint-svg

Public MIT Lua port of [zint](https://github.com/zint/zint), for a Lua report generator. SVG is the fidelity target. A PDF Form XObject content stream is the second output, so a report can draw the same vectors without rasterizing.

This file is the plan of record. The D3 and PDFKit Lua ports are separate repos and are not part of this work. The checklist at the bottom is here so those projects can be held up against the same sequence later: each of them is a half-finished port with its own license questions.

The August 2026 port this plan starts from lives at `~/DA/triton3/triton-toolkit-e8fb24a/tasks/lua-zint/`. This repository is still the empty 500Foods template.

## What this library is

A pure-Lua barcode encoder. At runtime it does not link to libzint, and it does not need a C library, an image library, or a network.

SVG is the text format Lua can build with string operations wherever the interpreter is running: a host program, an embedded device, a browser runtime. PNG, GIF, BMP, and TIFF need a rasterizer. They also freeze a resolution. In a report full of barcodes that tradeoff is the wrong one: a coarse raster fails to scan, a fine one costs more than the vectors did. Those formats are out of scope on purpose.

Deflate is not the reason. A pure-Lua zlib already exists in the PDFKit port at `~/DA/triton4/triton-toolkit-5b12870/tasks/lua-pdfkit/solution/lua-pdfkit/`. `zlib/deflate.lua` and `zlib/trees.lua` transcribe zlib 1.3.1's compressor, including the match-finder heuristics that decide the bytes. `flate.lua` adds inflate, Adler-32, and the zlib wrapper. PDF stream compression belongs in that writer. This rock does not copy zlib in, and it does not grow a PNG backend because the compressor happens to exist.

SVG does not drop into a PDF content stream. The second output is the drawing commands for a PDF Form XObject: filled rectangles and text, in PDF user space, ready for the report writer to wrap as an XObject and invoke with `Do`. Compact, resolution-independent, no font subsetter and no zlib inside this library.

zint already separates those stages. `vector.lua` turns the module bitmap into rectangles and strings. `svg.lua` only formats that list. The PDF emitter is a sibling of `svg.lua`. It does not parse SVG back into drawing commands.

## Decisions

- The published Lua is MIT. `NOTICE` carries the notices that have to travel with the code.
- `options.lua` is a new file, written from the zint 2.16.0 manual and from byte-compare tests against the pinned CLI. The August transcription of GPL-3 `frontend/main.c` stays in `~/DA` and does not enter this repo. The rewrite is aimed at observable CLI behavior. It is not a clean-room by a person who never saw the GPL source. That sentence stays in this file and in `NOTICE`.
- Modules transcribed from libzint (BSD-3-Clause) keep Robin Stuart's copyright notice.
- Font blobs stay. Arimo (Steve Matteson, 2013) is Apache-2.0. The OCR-B subset is Matthew Skala's digitization of Norbert Schwarz, released for unrestricted use.
- `vendor/zint` keeps zint's licenses: BSD-3-Clause for libzint, GPL-3.0-or-later for the CLI and the GUI. It is the reading copy and the SVG oracle. It is not in the rock.
- The pin for this round is zint **2.16.0** (release of 2025-12-19). Git master is `2.16.0.9-dev` and is not the pin. This machine's `/usr/bin/zint` is 2.15.0 and is not the oracle. The comparator builds the vendored tree.
- Tests run on Lua **5.5.1**. The rockspec depends on `lua >= 5.5`. The pin is there so a test run does not change versions underneath us. The next major round pins whatever release is current and fixes the diffs.
- Five symbologies ship first. The goal remains essentially all of them, then a yearly pass, or sooner if a release matters.
- The rock and the copy inside the report generator are the same plain Lua files. Nothing is downloaded at runtime.
- `bin/lua-zint` is callable from bash for the harness. Library callers use `local zint = require "zint"`.
- LuaRocks upload is the last step, after SVG matches 2.16.0 and the PDF fragment exists for those same symbols. It waits on an API key if none is configured.

We do not imply affiliation with the zint project. The BSD-3 endorsement clause forbids using their name to promote a derived product. The README credits them and says this is an independent Lua port.

## Where the code is today

`github.com/500foods/lua-zint-svg` on `main` is the template. `LICENSE` is Unlicense. `.gitignore` is a Delphi template and will be replaced. The CLOC badge and workflow still name `500Foods/Template` and force Pascal on `*.inc`.

The port is `solution/lua-zint.lua` plus `solution/zint/*.lua` in the Harbor task above. About 6,000 lines, 16 files, of which about 3,400 are code. `zint.barcode(opts)` returns the SVG string and, when `opts.output` is set, writes that file.

Implemented, and matched to zint 2.13.0 SVG bytes:

| id | name | module |
|----|------|--------|
| 8 | Code 39 | `code.lua` |
| 20 | Code 128 (the default) | `code128.lua` |
| 16 | GS1-128 | `code128.lua` and `gs1.lua` |
| 34 / 35 | UPC-A, with and without a supplied check digit | `upcean.lua` |
| 58 | QR Code | `qr.lua`, `qrtables.lua`, `reedsol.lua` |

The shared path is `common.lua` (float32 narrowing so coordinates match zint's `float` formatting), `output.lua`, `vector.lua`, and `svg.lua`. Further symbologies plug into that path. The option layer implements the flags `zint-lua.sh` accepted, which is wider than the nine the eval required.

The harness README records about 1,581 passing SVG comparisons against zint 2.13.0. QR was swept across 40/40 versions, masks 0–7, and ECC L/M/Q/H. Those numbers are from August 2026. They get re-run against 2.16.0 before we repeat them in the README.

The two consistency gaps on these five symbols are closed:

- `gs1_lint` matches the built-in checker. An unknown AI is Error 260 and a bad length is Error 259, with no file. A bad check digit or date is Warning 261 and the SVG matches. AIs (01), (10), (17), and (21) with valid data stay byte for byte.
- QR automatic ECI and the Shift-JIS fallback match. Latin-1 is unchanged. Shift JIS warns 760 with no ECI header. If that fails, the driver retries with an automatic ECI and warns 222.

UPC-A add-ons, Code Set A, FNC4, and compliant height are implemented. The eval verifier never drew them. The harnesses did.

2.14 through 2.16 changed real encoder behavior. Code 128 start-code selection changed in 2.15. 2.16 treats ECI 899 binary input as UTF-8 in Unicode mode. The five symbologies are rebased onto 2.16.0 until the SVGs match. Matching 2.13.0 is not the claim we publish.

## Outputs

`zint.barcode(opts)` encodes one symbol.

`opts.filetype` defaults to `"SVG"`. The return value is the SVG document. `opts.output`, when set, also writes that string. This is the path the byte-compare oracle checks.

`opts.filetype = "PDF"` returns a table. It is not a PDF file and it is not a string of a finished document.

```lua
{
  kind = "form-xobject",
  bbox = { 0, 0, width, height },
  content = "...",
  resources = {
    Font = { F1 = { BaseFont = "Helvetica", Subtype = "Type1" } },
  },
}
```

`content` is a PDF content stream. `bbox` uses the same user units as the SVG viewBox. The origin is the bottom left and y grows up, which is legal PDF. The emitter does the flip. The report writer supplies the object number, `/Length`, the stream dictionary (`/Type /XObject /Subtype /Form /BBox /Resources`), and the `Do` invocation. It also applies whatever scale turns those units into points on the page. This library does not choose a DPI.

Rectangles become `re f` with the same fill as the SVG. That is the scannable symbol.

Text becomes `BT Tf Tm Tj ET` at the same anchors as the SVG, y-flipped. The stream names a font. It does not embed one. The default is Helvetica, which every PDF consumer already has, so a report with no font machinery still gets a human-readable line. UPC-A in zint places digits with OCR-B widths. Helvetica widths will not sit in those slots. The bars stay correct. A report that needs the digits under the guards passes its own font resource and can use the OCR-B bytes already in `fonts.lua`. Embedding and subsetting stay in the PDF writer, next to the zlib port.

An unknown `filetype` is an error.

There is no zint PDF to diff. PDF tests reconstruct the rectangles from `content` and compare them to `symbol.vector` after the y flip, and they check that every human-readable string is in the stream. SVG remains the byte-identical claim. PDF means the same vectors, expressed as PDF operators.

A one-page PDF file for opening in a viewer can wait. It is not the embedding format. Building that page, including compressed streams, is the PDF writer's job and it already has deflate.

## License

| Path | License |
|---|---|
| `src/zint/*.lua`, except the font blobs | MIT, plus the BSD-3-Clause notice for the libzint-derived work |
| `src/zint/fonts.lua` blobs | Apache-2.0 (Arimo) and the OCR-B grant, quoted in `NOTICE` |
| `src/zint/options.lua` | MIT. New file, written from the manual and the CLI |
| `vendor/zint/` | Upstream licenses, unchanged. Excluded from the rock and from CLOC |
| `LICENSE` | MIT, replacing the template's Unlicense |

A function whose body was transcribed from `frontend/*.c` or the Qt front end is rewritten from the manual and the CLI. `get_barcode_name` and the CLI defaults are re-expressed from `--help` and the manual. Backend modules (`code`, `code128`, `upcean`, `qr`, `gs1`, `svg`, `vector`, `output`, the float narrowing in `common`, `eci`, `reedsol`, `fonts`) come from the BSD library and keep the notice.

`docs/PORTING-NOTES.md` is our build log from the August port. Short algorithm notes stay. Multi-line pastes of GPL source do not come into this repo.

## Repository layout

```
LICENSE
NOTICE
LUA-ZINT-SVG-PLAN.md
README.md
lua-zint-svg-0.2.0-1.rockspec
src/zint/init.lua              was lua-zint.lua; returns the module
src/zint/*.lua                 svg.lua and pdf.lua format the same vector list
bin/lua-zint                   bash-callable CLI, zint-style flags
vendor/zint/                   zint 2.16.0 source, not in the rock
vendor/PIN                     tag, commit, url
test/compare.sh                builds vendor/zint, diffs SVG bytes
test/harnesses/                adapted from the August harnesses
test/smoke.lua                 golden SVGs, no C compiler required
test/pdf.lua                   content stream against the vector list
docs/PORTING-NOTES.md
.gitignore
.github/workflows/main.yml
```

Vendor the 2.16.0 release tarball (GitHub tag or SourceForge `zint-2.16.0-src.tar.gz`). Keep `backend/` including its tests, `frontend/`, `cmake/`, `getopt/`, the root build files, `LICENSE`, `ChangeLog`, and the manual. Drop `frontend_qt/`, `backend_qt/`, `backend_tcl/`, `win32/`, and `debian/`. The manual is the spec the option parser is written against. The backend tests stay because the remaining symbologies will be read from this tree.

Build the oracle with Qt and PNG off, into `vendor/zint/build/`. That directory is gitignored. The comparator calls that binary, never `/usr/bin/zint`.

## Rock and the report generator

`lua-zint-svg-0.2.0-1.rockspec`, format 3.0, same shape as the doksuela rockspec. Package name `lua-zint-svg`, module name `zint`, homepage this GitHub repo, license `MIT`, dependency `lua >= 5.5`. `build.modules` lists each `src/zint/*.lua`. `bin/lua-zint` is installed as a script. No native dependency and no other rock dependency.

The report generator copies `src/zint` into its tree, or submodules this repo, and `require "zint"` resolves on `package.path`. `luarocks make` in this repo is how we check the rock. `luarocks upload` is how other people install it. Same files either way.

`bin/lua-zint` accepts zint's flag forms (`-b`, `--barcode=`, `--data=`, and the rest) and passes values through as strings, so float parsing happens inside the port. The August shell wrapper hardcodes `/usr/local/bin/lua`, `/app`, and a sandbox. Those stay in `~/DA`.

## README, tests, and the public claim

The README is what stops a vague "this is zint" reading. It states, in this order:

- Pure Lua, no libzint at runtime. SVG, and a PDF form content stream.
- Credit and links: Robin Stuart, https://github.com/zint/zint, https://zint.org.uk, the 2.16.0 pin. Independent port. Not affiliated.
- A table: symbology, status (`matches 2.16.0 SVG`, `PDF vectors`, `not yet`). Five rows filled. The rest of vendored `zint.h` listed as not yet.
- The two deferred gaps, including that invalid GS1 can produce a symbol zint would refuse.
- Font notices, one line each, pointing at `NOTICE`.
- `local zint = require "zint"`, one SVG example, one PDF-table example.
- One sentence on speed: a version-40 QR took a few seconds in the August port. Fine for a report page. Measure before putting it in a tight loop.
- The CLOC badge for this repo: `https://github.com/500foods/lua-zint-svg/actions/workflows/main.yml/badge.svg`.

The workflow drops `--force-lang=Pascal,inc` and excludes `vendor`, so the count is this port.

Tests come in two layers.

- `test/smoke.lua` plus a handful of committed SVG fixtures. Runs with Lua alone. This is what a LuaRocks user can execute.
- `test/compare.sh` builds vendored zint 2.16.0 and runs the adapted harnesses: `fuzz.sh`, `upca.sh`, a short `stressqr.sh`, `flags.sh`, `colourdiff.sh`. This is the byte-identical claim. It is allowed to need CMake.
- `test/pdf.lua` checks the content stream against the vector list. It does not claim byte identity with zint.

`.gitignore` replaces the Delphi template. Ignore compiler and CMake output (`*.o`, `*.a`, `*.so`, `*.obj`, `CMakeCache.txt`, `CMakeFiles/`, `vendor/zint/build/`), LuaRocks output (`*.rock`, `lua_modules/`, `.luarocks/`), and editor or OS noise. Track `vendor/zint` source, `src/`, and `test/`. The Delphi rules go away, including `*.dcu`, `*.bpl`, `__history/`, `TMSWeb/`, `*.identcache`, `Win32/`, `modules/`, `*.cfg`, and `*.map`.

## Order of work

1. This file, then MIT `LICENSE`, `NOTICE`, `.gitignore`, the README, and the CLOC workflow change.
2. Vendor zint 2.16.0, write `vendor/PIN`, build it, confirm `zint --version` prints 2.16.0.
3. Copy the BSD-derived Lua into `src/zint/`. Add `init.lua`. Do not copy the old `options.lua`.
4. Write `src/zint/options.lua` and `bin/lua-zint` against the 2.16.0 manual and CLI. `flags.sh` and `colourdiff.sh` are the proof.
5. Adapt the SVG harnesses. Fix encoder diffs until the five symbologies match. Commit a few golden SVGs and `test/smoke.lua`. Refresh the backlog below from `zint.h`.
6. Add `src/zint/pdf.lua` and `test/pdf.lua` over the existing vector list, for those five symbologies.
7. `luarocks make`, then `lua -e 'local z=require"zint"; print(type(z.barcode))'` on Lua 5.5.1. That prints `function`.
8. Upload if a LuaRocks API key is present. Otherwise stop with the rockspec ready.

## Done

- Vendored `zint --version` is 2.16.0, and `vendor/zint/build/` is untracked.
- Five SVG samples are byte-identical to that binary. The harness subset is green aside from the deferred gaps, which the README names.
- `test/smoke.lua` passes without a C compiler.
- For each of those five, the PDF content stream's rectangles match the vector list after the y flip, and the human-readable strings are in the stream.
- `luarocks make` succeeds. `LICENSE` is MIT. `options.lua` in this repo is the new file. `NOTICE` names zint, Arimo, and OCR-B.

## Backlog

Refreshed from vendored `backend/zint.h` at 2.16.0. Legacy macros that share an id with a name below are omitted (`BARCODE_EAN128` is 16, `BARCODE_RSS14` is 29, and the rest of that kind). Shipped in this rock: Interleaved 2 of 5 (3), Code 39 (8), EAN-8 (10), EAN-13 (15), GS1-128 (16), Code 128 (20), UPC-A (34), UPC-A with check digit (35), UPC-E (37), UPC-E with check digit (38), QR Code (58), NVE-18 (75), ITF-14 (89).

Not yet, by id:

- Linear and retail: Code 11 (1), Code 2 of 5 Standard (2), IATA (4), Data Logic (6), Industrial (7), Extended Code 39 (9), EAN-2 add-on (11), EAN-5 add-on (12), EANX (13), EANX check (14), Codabar (18), DP Leitcode (21), DP Identcode (22), Code 93 (25), Flattermarken (28), Telepen (32), MSI Plessey (47), LOGMARS (50), PZN (52), VIN (73), Code 128 suppress C (60), UK Plessey (86), Telepen Numeric (87), Code 32 (129), Channel Code (140), BC412 (146), DX Film Edge (147).
- GS1 DataBar: Omnidirectional (29), Limited (30), Expanded (31), Stacked (79), Stacked Omnidirectional (80), Expanded Stacked (81).
- Matrix: Data Matrix (71), Aztec (92), MaxiCode (57), Micro QR (97), Han Xin (116), DotCode (115), Grid Matrix (142), Ultracode (144), rMQR (145), UPNQR (143), Aztec Rune (128), Code One (141).
- Stacked: Code 16k (23), Code 49 (24), PDF417 (55), Compact PDF417 (56), MicroPDF417 (84), Codablock-F (74).
- Postal: POSTNET (40), PLANET (82), Australia Post (63), Reply Paid (66), Routing (67), Redirection (68), RM4SCC (70), Japan Post (76), Korea Post (77), KIX (90), USPS Intelligent Mail (85), CEPNet (54), Royal Mail 2D Mailmark (119), Mailmark 4-state (121), UPU S10 (120), FIM (49).
- Pharma and HIBC: Pharmacode One-Track (51), Two-Track (53), EAN-14 (72), ISBN (69), HIBC Code 128 (98), Code 39 (99), Data Matrix (102), QR (104), PDF417 (106), MicroPDF417 (108), Codablock-F (110), Aztec (112), DAFT (93), DPD (96).
- Composites: EANX (130), GS1-128 (131), DataBar Omnidirectional (132), Limited (133), Expanded (134), UPC-A (135), UPC-E (136), DataBar Stacked (137), Stacked Omnidirectional (138), Expanded Stacked (139), EAN-8 (148), EAN-13 (149).

Also waiting, and not part of the first rock:

- OCR-B embedding inside this library. Decided: the report writer embeds OCR-B and uses the positions this library already computes. Noted beside the symbologies in the README.
- A single-page PDF file, if a human wants to open one without a report writer.
- The next zint pin, when that round starts. Same rule: pin the latest release, rerun the comparator, fix what moved.

## Checklist for a later port

Written so the D3 and PDFKit repos can follow it. Nothing in this list is extra work for lua-zint-svg.

1. Audit the upstream license, and the license of every embedded asset, before the public repo receives code. Sort a conflict before the code lands.
2. Pin the latest upstream release, tag and commit, and test against that pin.
3. Vendor that source as the reading copy and the oracle. Keep its license. Exclude it from the package and from line-count badges. Gitignore the build.
4. Port to plain files another project can copy, with no runtime download.
5. Provide a shell-callable entry point for the differential harness.
6. Compare output against the pin. Write down intentional gaps. Keep a small fixture test that does not need the oracle toolchain.
7. The README states the claim precisely, credits upstream, denies affiliation where the upstream license requires it, and links a `NOTICE`.
8. Publish to the language index when the pinned suite is green.
9. Next round, yearly or on demand: move the pin, rerun the comparator, fix the diffs.

D3 is ISC. PDFKit is MIT. zint's split (BSD library, GPL CLI) is what forced the option-parser rewrite here. The PDFKit tree already carries the zlib port described above, plus its own font and image assets. Those assets get their own pass through step 1 when that repo starts. The rest of the checklist is the same.
