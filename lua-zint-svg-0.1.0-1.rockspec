rockspec_format = "3.0"
package = "lua-zint-svg"
version = "0.1.0-1"
source = {
  url = "git+https://github.com/500Foods/lua-zint-svg.git",
}
description = {
  summary = "Pure Lua SVG barcodes and PDF form content",
  detailed = [[
A native Lua port of five zint 2.16.0 symbologies: Code 39, Code 128,
GS1-128, UPC-A, and QR Code. Output is an SVG document or a PDF Form
XObject content stream. There is no libzint dependency at runtime.
The encoders follow the BSD-licensed libzint sources. See NOTICE.
]],
  homepage = "https://github.com/500Foods/lua-zint-svg",
  license = "MIT",
}
dependencies = {
  "lua >= 5.5",
}
build = {
  type = "builtin",
  modules = {
    ["zint"] = "src/zint/init.lua",
    ["zint.code"] = "src/zint/code.lua",
    ["zint.code128"] = "src/zint/code128.lua",
    ["zint.common"] = "src/zint/common.lua",
    ["zint.eci"] = "src/zint/eci.lua",
    ["zint.fonts"] = "src/zint/fonts.lua",
    ["zint.gs1"] = "src/zint/gs1.lua",
    ["zint.options"] = "src/zint/options.lua",
    ["zint.output"] = "src/zint/output.lua",
    ["zint.pdf"] = "src/zint/pdf.lua",
    ["zint.qr"] = "src/zint/qr.lua",
    ["zint.qrtables"] = "src/zint/qrtables.lua",
    ["zint.reedsol"] = "src/zint/reedsol.lua",
    ["zint.reedsol_logs"] = "src/zint/reedsol_logs.lua",
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
