#!/usr/bin/env lua
-- Byte comparison against committed SVG fixtures. Needs Lua only.
-- The fixtures are the bytes of vendored zint 2.16.0 for these five inputs.

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
  { file = "qr.svg",       barcode = 58, data = "HELLO" },
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
