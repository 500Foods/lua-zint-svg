#!/usr/bin/env lua
-- Byte comparison against committed SVG fixtures. Needs Lua only.
-- The fixtures are the bytes of vendored zint 2.16.0 for these inputs.

os.setlocale("C", "numeric")

local script = arg[0]
local dir = script:match("^(.*)/") or "."
local root = dir .. "/.."
package.path = root .. "/src/?.lua;" .. root .. "/src/?/init.lua;" .. package.path

local zint = require "zint"

local function read_file(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local body = f:read("a")
  f:close()
  return body
end

local cases = {
  { file = "code39.svg",   barcode = 8,  data = "ABC-123" },
  { file = "code128.svg",  barcode = 20, data = "Ab-129" },
  { file = "gs1-128.svg",  barcode = 16, data = "[01]40063813339314[10]ABC12" },
  { file = "upca.svg",     barcode = 34, data = "12345678901" },
  { file = "ean13.svg",    barcode = 15, data = "123456789012" },
  { file = "ean8.svg",     barcode = 10, data = "1234567" },
  { file = "upce.svg",     barcode = 37, data = "123456" },
  { file = "c25inter.svg", barcode = 3,  data = "1234567890" },
  { file = "itf14.svg",    barcode = 89, data = "1234567890" },
  { file = "nve18.svg",    barcode = 75, data = "12345678901234567" },
  { file = "qr.svg",       barcode = 58, data = "HELLO" },
  { file = "dbarexp.svg",  barcode = 31, data = "[01]09501101530003[17]140704[10]AB-123" },
  { file = "dbarexpstk.svg", barcode = 81, data = "[01]09501101530003[17]140704[10]AB-123" },
  { file = "dbaromn.svg", barcode = 29, data = "09501101530003" },
  { file = "dbaromnstk.svg", barcode = 80, data = "09501101530003" },
  { file = "dmatrix.svg", barcode = 71, data = "HELLO" },
  { file = "ean2.svg",     barcode = 11, data = "05" },
  { file = "ean5.svg",     barcode = 12, data = "12345" },
  { file = "isbn.svg",     barcode = 69, data = "9780306406157" },
  { file = "code128ab.svg", barcode = 60, data = "123456" },
  { file = "flat.svg",     barcode = 28, data = "0123456789" },
  { file = "pdf417.svg",   barcode = 55, data = "PDF417" },
  { file = "pdf417comp.svg", barcode = 56, data = "Hello" },
  { file = "maxicode.svg", barcode = 57, data = "1" },
  { file = "imail.svg",    barcode = 85, data = "01234567094987654321-01234567891" },
  { file = "aztec.svg",    barcode = 92, data = "Hello" },
}

local failed = 0
for _, case in ipairs(cases) do
  local svg, err = zint.barcode({ barcode = case.barcode, data = case.data })
  local path = dir .. "/golden/" .. case.file
  local golden, gerr = read_file(path)
  if svg == nil then
    io.stderr:write(case.file, ": ", err or "no svg", "\n")
    failed = failed + 1
  elseif golden == nil then
    io.stderr:write(case.file, ": ", gerr, "\n")
    failed = failed + 1
  elseif svg ~= golden then
    io.stderr:write(case.file, ": SVG differs from the fixture (", #svg, " vs ", #golden, " bytes)\n")
    failed = failed + 1
  else
    io.write("ok  ", case.file, "\n")
  end
end

local empty = zint.barcode({ barcode = 8, data = "" })
if empty ~= nil then
  io.stderr:write("empty data was accepted\n")
  failed = failed + 1
else
  io.write("ok  empty data refused\n")
end

if failed > 0 then os.exit(1) end
io.write("smoke  ", #cases, " fixtures\n")
