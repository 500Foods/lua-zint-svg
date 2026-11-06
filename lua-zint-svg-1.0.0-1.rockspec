rockspec_format = "3.0"
package = "lua-zint-svg"
version = "1.0.0-1"
source = {
  url = "git+https://github.com/500Foods/lua-zint-svg.git",
  tag = "v1.0.0",
}
description = {
  summary = "Pure Lua barcodes: Code 39, Code 128, GS1-128, UPC, EAN, ISBN, ITF, SSCC, QR, and Data Matrix",
  detailed = [[
Draw barcodes from Lua. No C library, no image library, and no
network at runtime. You get an SVG document, or a PDF Form XObject
content stream a report writer can place on a page.

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

form.kind is "form-xobject". form.bbox, form.content, and
form.resources are ready for the writer. The writer supplies the
object number, the length, the Form dictionary, and the Do.

This release draws these, by name or by id:

    Code 39                        8
    GS1-128                       16
    Code 128                      20
    Code 128 (suppress C)         60
    Flattermarken                 28
    UPC-A                         34
    UPC-A, check digit supplied   35
    EAN-8                         10
    EAN-13                        15
    UPC-E                         37
    UPC-E, check digit supplied   38
    Interleaved 2 of 5             3
    ITF-14                        89
    NVE-18 (SSCC)                 75
    QR Code                       58
    GS1 DataBar Omnidirectional          29
    GS1 DataBar Stacked Omnidirectional  80
    GS1 DataBar Expanded          31
    GS1 DataBar Expanded Stacked  81
    Data Matrix                   71
    PDF417                        55
    Compact PDF417                56
    MaxiCode                      57
    USPS Intelligent Mail         85
    Aztec                         92
    EAN-2 add-on                  11
    EAN-5 add-on                  12
    ISBN                          69

Refer to GitHub for more information about each symbology.

Needs Lua 5.5 or newer. The rock builds no C.             

Source, samples, and issues, or to request another zint-supported symbology:
https://github.com/500Foods/lua-zint-svg
https://github.com/500foods/lua-zint-svg/issues
]],
  homepage = "https://github.com/500Foods/lua-zint-svg",
  issues_url = "https://github.com/500foods/lua-zint-svg/issues",
  license = "MIT",
  maintainer = "Andrew Simard <andrew@500foods.com>",
  labels = { "barcode", "svg", "pdf" },
}
dependencies = {
  "lua >= 5.5",
}
build = {
  type = "builtin",
  modules = {
    ["zint"] = "src/zint/init.lua",
    ["zint.aztec"] = "src/zint/aztec.lua",
    ["zint.aztec_tabs"] = "src/zint/aztec_tabs.lua",
    ["zint.c25inter"] = "src/zint/c25inter.lua",
    ["zint.code"] = "src/zint/code.lua",
    ["zint.code128"] = "src/zint/code128.lua",
    ["zint.common"] = "src/zint/common.lua",
    ["zint.dbar"] = "src/zint/dbar.lua",
    ["zint.dmatrix"] = "src/zint/dmatrix.lua",
    ["zint.eci"] = "src/zint/eci.lua",
    ["zint.flat"] = "src/zint/flat.lua",
    ["zint.eci_sb"] = "src/zint/eci_sb.lua",
    ["zint.fonts"] = "src/zint/fonts.lua",
    ["zint.fonts_ttf"] = "src/zint/fonts_ttf.lua",
    ["zint.gs1"] = "src/zint/gs1.lua",
    ["zint.gs1_lint"] = "src/zint/gs1_lint.lua",
    ["zint.imail"] = "src/zint/imail.lua",
    ["zint.imail_tabs"] = "src/zint/imail_tabs.lua",
    ["zint.large"] = "src/zint/large.lua",
    ["zint.maxicode"] = "src/zint/maxicode.lua",
    ["zint.maxicode_tabs"] = "src/zint/maxicode_tabs.lua",
    ["zint.options"] = "src/zint/options.lua",
    ["zint.output"] = "src/zint/output.lua",
    ["zint.pdf"] = "src/zint/pdf.lua",
    ["zint.pdf417"] = "src/zint/pdf417.lua",
    ["zint.pdf417_tabs"] = "src/zint/pdf417_tabs.lua",
    ["zint.qr"] = "src/zint/qr.lua",
    ["zint.qrtables"] = "src/zint/qrtables.lua",
    ["zint.reedsol"] = "src/zint/reedsol.lua",
    ["zint.reedsol_logs"] = "src/zint/reedsol_logs.lua",
    ["zint.sjis"] = "src/zint/sjis.lua",
    ["zint.svg"] = "src/zint/svg.lua",
    ["zint.upcean"] = "src/zint/upcean.lua",
    ["zint.vector"] = "src/zint/vector.lua",
  },
  install = {
    bin = {
      ["lua-zint"] = "bin/lua-zint",
    },
  },
}
