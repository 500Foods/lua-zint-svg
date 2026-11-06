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
local svg = require "zint.svg"
local woff = require "zint.fonts"
local ttf = require "zint.fonts_ttf"
local code = require "zint.code"
local code128 = require "zint.code128"
local flat = require "zint.flat"
local upcean = require "zint.upcean"
local c25inter = require "zint.c25inter"
local qr = require "zint.qr"
local gs1 = require "zint.gs1"
local dbar = require "zint.dbar"
local dmatrix = require "zint.dmatrix"
local pdf417 = require "zint.pdf417"
local maxicode = require "zint.maxicode"
local aztec = require "zint.aztec"
local imail = require "zint.imail"

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
  -- MaxiCode is hexagons and three stroked bullseye rings. It has no bars.
  if #vec.rectangles == 0 and symbol.symbology ~= 57 then
    return fail(name, "no rectangles")
  end
  if symbol.symbology == 57 then
    local _, fills = form.content:gsub("h\nf\n", "")
    local _, strokes = form.content:gsub("h\nS\n", "")
    if #vec.hexagons == 0 or fills ~= #vec.hexagons then
      return fail(name, "hexagons " .. fills .. " vs " .. #vec.hexagons)
    end
    if #vec.circles == 0 or strokes ~= #vec.circles then
      return fail(name, "rings " .. strokes .. " vs " .. #vec.circles)
    end
  end
  for _, str in ipairs(vec.strings) do
    local escaped = str.text:gsub("\\", "\\\\"):gsub("%(", "\\("):gsub("%)", "\\)")
    if not form.content:find(escaped, 1, true) then
      return fail(name, "missing text " .. str.text)
    end
  end
  if #vec.strings == 0 then
    if form.font ~= nil then
      return fail(name, "font field set with no text")
    end
  else
    local upcean = common.is_upcean(symbol.symbology)
    local face = form.font
    local family = upcean and "OCRB" or "Arimo"
    local bytes = upcean and ttf.upcean or ttf.normal
    local length = upcean and 2404 or 27448
    if not face then
      return fail(name, "missing font")
    end
    if face.family ~= family or face.format ~= "TTF" then
      return fail(name, "font " .. tostring(face.family) .. " " .. tostring(face.format))
    end
    if face.bytes ~= bytes or #face.bytes ~= length then
      return fail(name, "font bytes " .. tostring(face.bytes and #face.bytes))
    end
    if face.bytes:sub(1, 4) ~= "\0\1\0\0" then
      return fail(name, "font scaler")
    end
  end
  -- QR has no text line. Data Matrix (71), Expanded Stacked (81),
  -- Stacked Omnidirectional (80), Flattermarken (28), PDF417 (55),
  -- Compact PDF417 (56), MaxiCode (57), Intelligent Mail (85), and
  -- Aztec (92) do not either.
  local no_hrt = symbol.symbology == 28 or symbol.symbology == 55
      or symbol.symbology == 56 or symbol.symbology == 57
      or symbol.symbology == 58 or symbol.symbology == 71
      or symbol.symbology == 80 or symbol.symbology == 81
      or symbol.symbology == 85 or symbol.symbology == 92
  if not no_hrt and #vec.strings == 0 then
    return fail(name, "symbol has no human-readable text")
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

s = symbol(60)
ok, err = code128.code128(s, "123456")
if not ok then fail("code128ab", err) else check("code128ab", s) end

s = symbol(28)
ok, err = flat.flat(s, "0123456789")
if not ok then fail("flat", err) else check("flat", s) end

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

s = symbol(15)
ok, err = upcean.ean13(s, "123456789012")
if not ok then fail("ean13", err) else check("ean13", s) end

s = symbol(10)
ok, err = upcean.ean8(s, "1234567")
if not ok then fail("ean8", err) else check("ean8", s) end

s = symbol(37)
ok, err = upcean.upce(s, "123456")
if not ok then fail("upce", err) else check("upce", s) end

s = symbol(11)
ok, err = upcean.ean2(s, "05")
if not ok then fail("ean2", err) else check("ean2", s) end

s = symbol(12)
ok, err = upcean.ean5(s, "12345")
if not ok then fail("ean5", err) else check("ean5", s) end

s = symbol(69)
ok, err = upcean.isbn(s, "9780306406157")
if not ok then fail("isbn", err) else check("isbn", s) end

s = symbol(3)
ok, err = c25inter.c25inter(s, "1234567890")
if not ok then fail("c25inter", err) else check("c25inter", s) end

s = symbol(89)
ok, err = c25inter.itf14(s, "1234567890")
if not ok then fail("itf14", err) else check("itf14", s) end

s = symbol(75)
ok, err = code128.nve18(s, "12345678901234567")
if not ok then fail("nve18", err) else check("nve18", s) end

s = symbol(58)
ok, err = qr.qrcode(s, "HELLO")
if not ok then fail("qr", err) else check("qr", s) end

s = symbol(31)
ok, err = dbar.expanded(s, "[01]09501101530003[17]140704[10]AB-123")
if not ok then fail("dbarexp", err) else check("dbarexp", s) end

s = symbol(81)
ok, err = dbar.expanded(s, "[01]09501101530003[17]140704[10]AB-123")
if not ok then fail("dbarexpstk", err) else check("dbarexpstk", s) end

s = symbol(29)
ok, err = dbar.omn(s, "09501101530003")
if not ok then fail("dbaromn", err) else check("dbaromn", s) end

s = symbol(80)
ok, err = dbar.omn(s, "09501101530003")
if not ok then fail("dbaromnstk", err) else check("dbaromnstk", s) end

s = symbol(71)
ok, err = dmatrix.datamatrix(s, "HELLO")
if not ok then fail("dmatrix", err) else check("dmatrix", s) end

s = symbol(55)
ok, err = pdf417.pdf417(s, "PDF417")
if not ok then fail("pdf417", err) else check("pdf417", s) end

s = symbol(56)
ok, err = pdf417.pdf417(s, "Hello")
if not ok then fail("pdf417comp", err) else check("pdf417comp", s) end

s = symbol(57)
ok, err = maxicode.maxicode(s, "1")
if not ok then fail("maxicode", err) else check("maxicode", s) end

s = symbol(85)
ok, err = imail.imail(s, "01234567094987654321-01234567891")
if not ok then fail("imail", err) else check("imail", s) end

s = symbol(92)
ok, err = aztec.aztec(s, "Hello")
if not ok then fail("aztec", err) else check("aztec", s) end

-- --notext clears show_hrt, so the form has bars and no font field.
s = symbol(20)
s.show_hrt = 0
ok, err = code128.code128(s, "Ab-129")
if not ok then
  fail("code128-notext", err)
else
  if s.height < 0.5 then common.set_height(s, 0.0, 50.0, 0.0) end
  vector.plot(s, 0)
  local form = pdf.form(s)
  if #s.vector.strings ~= 0 then
    fail("code128-notext", "notext still drew text")
  elseif form.font ~= nil then
    fail("code128-notext", "font field set with no text")
  elseif form.resources.Font.F1.BaseFont ~= "Helvetica" then
    fail("code128-notext", "font resource is not Helvetica")
  else
    io.write("ok  code128-notext  no font\n")
  end
end

-- --embedfont still pastes the WOFF2 blob. The TrueType module is not on this path.
local function check_embed(name, symbol, family, blob)
  if symbol.height < 0.5 then common.set_height(symbol, 0.0, 50.0, 0.0) end
  vector.plot(symbol, 0)
  local doc = svg.plot(symbol)
  if not doc:find('font-family:"' .. family .. '"', 1, true) then
    return fail(name, "missing " .. family)
  end
  if not doc:find(blob, 1, true) then
    return fail(name, "WOFF2 blob changed")
  end
  if doc:find("font/ttf", 1, true) then
    return fail(name, "SVG carries a TTF")
  end
  io.write("ok  ", name, "  embedfont ", family, "\n")
end

s = symbol(20)
s.output_options = common.EMBED_VECTOR_FONT
ok, err = code128.code128(s, "Ab-129")
if not ok then fail("embedfont-c128", err) else check_embed("embedfont-c128", s, "Arimo", woff.normal) end

s = symbol(34)
s.output_options = common.EMBED_VECTOR_FONT
ok, err = upcean.upca(s, "12345678901")
if not ok then fail("embedfont-upca", err) else check_embed("embedfont-upca", s, "OCRB", woff.upcean) end

if failed > 0 then os.exit(1) end
io.write("pdf  26 symbologies\n")
