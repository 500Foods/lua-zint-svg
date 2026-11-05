#!/usr/bin/env lua
-- The PDF form's rectangles are the vector list after the y flip.
-- Human-readable strings are in the content stream. This does not
-- compare the stream to zint.

os.setlocale("C", "numeric")

local script = arg[0]
local dir = script:match("^(.*)/") or "."
local root = dir .. "/.."
package.path = root .. "/src/?.lua;" .. root .. "/src/?/init.lua;" .. package.path

local common = require "zint.common"
local vector = require "zint.vector"
local pdf = require "zint.pdf"
local code = require "zint.code"
local code128 = require "zint.code128"
local upcean = require "zint.upcean"
local qr = require "zint.qr"
local gs1 = require "zint.gs1"

local f32 = common.stripf
local failed = 0

local function num(v)
  local s = ("%.8f"):format(v)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  if s == "-0" then s = "0" end
  return s
end

local function flip_y(height, y, h)
  return f32(f32(height - y) - (h or 0))
end

local function fail(name, msg)
  io.stderr:write(name, ": ", msg, "\n")
  failed = failed + 1
end

local function check(name, symbol)
  if symbol.height < 0.5 then
    common.set_height(symbol, 0.0, 50.0, 0.0)
  end
  vector.plot(symbol, 0)
  local form = pdf.form(symbol)
  local vec = symbol.vector

  if form.kind ~= "form-xobject" then
    return fail(name, "kind " .. tostring(form.kind))
  end
  if form.bbox[1] ~= 0 or form.bbox[2] ~= 0
      or form.bbox[3] ~= vec.width or form.bbox[4] ~= vec.height then
    return fail(name, "bbox does not match the vector size")
  end
  local font = form.resources.Font.F1
  if font.BaseFont ~= "Helvetica" or font.Subtype ~= "Type1" then
    return fail(name, "font resource is not Helvetica")
  end

  local got = {}
  for line in form.content:gmatch("[^\n]+") do
    if line:sub(-3) == " re" then got[#got + 1] = line end
  end
  if #got ~= #vec.rectangles then
    return fail(name, "rectangle count " .. #got .. " vs " .. #vec.rectangles)
  end
  for i, rect in ipairs(vec.rectangles) do
    local y = flip_y(vec.height, rect.y, rect.height)
    local expect = num(rect.x) .. " " .. num(y) .. " "
      .. num(rect.width) .. " " .. num(rect.height) .. " re"
    if got[i] ~= expect then
      return fail(name, "rect " .. i .. "\n  got " .. got[i] .. "\n  exp " .. expect)
    end
  end
  if #vec.rectangles == 0 then
    return fail(name, "no rectangles")
  end
  for _, str in ipairs(vec.strings) do
    local escaped = str.text:gsub("\\", "\\\\"):gsub("%(", "\\("):gsub("%)", "\\)")
    if not form.content:find(escaped, 1, true) then
      return fail(name, "missing text " .. str.text)
    end
  end
  local linear = symbol.symbology ~= 58
  if linear and #vec.strings == 0 then
    return fail(name, "linear symbol has no human-readable text")
  end
  io.write("ok  ", name, "  rects=", #got, "  strings=", #vec.strings, "\n")
end

local function symbol(id)
  local s = common.new_symbol()
  s.symbology = id
  return s
end

local s = symbol(8)
local ok, err = code.code39(s, "ABC-123")
if not ok then fail("code39", err) else check("code39", s) end

s = symbol(20)
ok, err = code128.code128(s, "Ab-129")
if not ok then fail("code128", err) else check("code128", s) end

s = symbol(16)
s.input_mode = common.GS1_MODE
local reduced, gerr = gs1.verify(s, "[01]40063813339314[10]ABC12")
if not reduced then
  fail("gs1-128", gerr)
else
  ok, err = code128.gs1_128(s, "[01]40063813339314[10]ABC12", reduced)
  if not ok then fail("gs1-128", err) else check("gs1-128", s) end
end

s = symbol(34)
ok, err = upcean.upca(s, "12345678901")
if not ok then fail("upca", err) else check("upca", s) end

s = symbol(58)
ok, err = qr.qrcode(s, "HELLO")
if not ok then fail("qr", err) else check("qr", s) end

if failed > 0 then os.exit(1) end
io.write("pdf  5 symbologies\n")
