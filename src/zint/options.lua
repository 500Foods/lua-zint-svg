-- src/zint/options.lua -- apply one symbol's command-line options.
--
-- Written from the zint 2.16.0 manual and from the pinned CLI in vendor/zint.
-- It is not a transcription of frontend/main.c, and it is not a clean-room:
-- an earlier transcription of that file was read while this port was built.
-- See NOTICE.
--
-- options.apply(symbol, opts) mutates symbol and returns the rotation angle,
-- or nil and an error. Zero is a successful angle. A value the CLI warns
-- about and ignores is left at the symbol default and the warning is printed
-- immediately, which is when the CLI prints it. A value the CLI accepts and
-- the library later rejects is stored, so the driver's field checks refuse it.

local common = require "zint.common"
local output = require "zint.output"

local M = {}
local f32 = common.stripf

-- C `0.1f` .. `1e-7f`. Index is the number of fractional digits.
local FRACT_MULS = {}
for i = 1, 7 do
  FRACT_MULS[i] = f32(10 ^ -i)
end

-- The CLI's float reader. "0.33" is 33 * 0.01f, not strtof("0.33").
-- At most seven significant digits. Leading zeros are free. Trailing zeros
-- in the fraction are stripped before they are counted, so "1.5000" is "1.5"
-- and "1.5000001" is eight significant digits.
-- Returns the float32 value, or nil and a reason that slots into the CLI's
-- "Invalid ... floating point (reason)" message.
local function validate_float(text, allow_neg)
  if type(text) == "number" then return f32(text) end
  if type(text) ~= "string" or text == "" then
    return nil, "integer part must be digits only"
  end

  local s = text
  local neg = false
  local lead = s:sub(1, 1)
  if lead == "-" then
    if not allow_neg then return nil, "negative value not permitted" end
    neg = true
    s = s:sub(2)
  elseif lead == "+" then
    s = s:sub(2)
  end

  local dot = s:find(".", 1, true)
  local int_digits, fract_digits
  if not dot then
    int_digits, fract_digits = s, ""
  else
    int_digits = s:sub(1, dot - 1)
    fract_digits = s:sub(dot + 1)
  end
  if int_digits == "" and fract_digits == "" then
    return nil, "integer part must be digits only"
  end
  if int_digits:find("%D") then
    return nil, "integer part must be digits only"
  end
  if #int_digits:gsub("^0+", "") > 7 then
    return nil, "integer part must be 7 digits maximum"
  end
  if fract_digits:find("%D") then
    return nil, "fractional part must be digits only"
  end
  local fract_body = fract_digits:gsub("0+$", "")
  if #fract_body > 7 then
    return nil, "fractional part must be 7 digits maximum"
  end

  local int_body = int_digits:gsub("^0+", "")
  local sig = int_body == "" and fract_body:gsub("^0+", "") or (int_body .. fract_body)
  if #sig > 7 then
    return nil, "7 significant digits maximum"
  end

  local ival = tonumber(int_digits) or 0
  local result
  if fract_body == "" then
    result = f32(ival)
  else
    local frac_int = tonumber(fract_body)
    local mul = FRACT_MULS[#fract_body]
    result = f32(f32(ival) + f32(f32(frac_int) * mul))
  end
  if neg then result = f32(-result) end
  return result
end

-- Digits only, decimal. Leading zeros are decimal, not octal. Empty is an error.
local function validate_int(text)
  if type(text) == "number" then
    if text < 0 or text ~= math.floor(text) then return nil end
    return text
  end
  if type(text) ~= "string" or not text:match("^%d+$") then return nil end
  return tonumber(text)
end

-- backend/library.c `ZBarcode_Default_Xdim()`, for the symbologies this port
-- encodes. The others fall through to the same "application defined" default
-- the library uses for Code 128 and Code 39.
local function default_xdim(symbology)
  -- GS1 retail X is 0.33mm: EAN, UPC, and DataBar. QR is the
  -- fixed-ratio default. Everything else is the GS1-128 application default.
  if symbology == 10 or symbology == 15 or symbology == 29 or symbology == 31
      or symbology == 34 or symbology == 35 or symbology == 37
      or symbology == 38 or symbology == 80 or symbology == 81 then
    return f32(0.33)
  end
  if symbology == 58 then return f32(0.625) end
  return f32(0.495)
end

-- backend/library.c `ZBarcode_Scale_From_XdimDp()` for SVG, which is vector
-- output and not EMF. Raster half-increments do not apply. The result is
-- clamped to the vector range 0.1 .. 200.
local function scale_from_xdim(x_mm, dpmm)
  local scale = f32(f32(x_mm) * f32(dpmm))
  scale = f32(scale / 2.0)
  if scale > f32(200) then
    scale = f32(200)
  elseif scale < f32(0.1) then
    scale = f32(0.1)
  end
  return scale
end

local function peel_unit(text)
  local num, unit = text:match("^(.-)(%a+)$")
  if num then return num, unit:lower() end
  return text, nil
end

function M.apply(symbol, opts)
  opts = opts or {}
  local warned = false
  local function warn(msg)
    if io and io.stderr then io.stderr:write(msg, "\n") end
    warned = true
  end

  local function absent(v)
    return v == nil or v == ""
  end

  if not absent(opts.scale) then
    local v, reason = validate_float(opts.scale, false)
    if not v then
      return nil, "Error 184: Invalid scale floating point (" .. reason .. ")"
    end
    if v < f32(0.01) then
      warn("Warning 105: Invalid scale value '" .. tostring(opts.scale)
        .. "' (less than 0.01), **IGNORED**")
    else
      symbol.scale = v
    end
  end

  if not absent(opts.scalexdimdp) then
    local text = tostring(opts.scalexdimdp)
    local commas = select(2, text:gsub(",", ""))
    local xtext, rtext
    if commas == 0 then
      xtext = text
    elseif commas == 1 then
      local cpos = text:find(",", 1, true)
      xtext = text:sub(1, cpos - 1)
      rtext = text:sub(cpos + 1)
    else
      return nil, "Error 178: scalexdimdp X-dim invalid floating point (integer part must be digits only)"
    end

    local xnum, xunit = peel_unit(xtext)
    if xunit and xunit ~= "mm" and xunit ~= "in" then
      return nil, "Error 177: scalexdimdp X-dim units must occur at end"
    end
    local x, xreason = validate_float(xnum, false)
    if not x then
      return nil, "Error 178: scalexdimdp X-dim invalid floating point (" .. xreason .. ")"
    end
    -- zint 2.16.0 converts "in" with `/= 25.4` and checks the range after that
    -- conversion. The manual describes an inch as 25.4 millimetres. The CLI
    -- divides, and the SVG comparison follows the CLI.
    local x_mm = x
    if xunit == "in" then x_mm = f32(f32(x) / f32(25.4)) end

    local dpmm = f32(0)
    if rtext then
      local rnum, runit = peel_unit(rtext)
      if runit and runit ~= "dpmm" and runit ~= "dpi" then
        return nil, "Error 179: scalexdimdp resolution units must occur at end"
      end
      local r, rreason = validate_float(rnum, false)
      if not r then
        return nil, "Error 180: scalexdimdp resolution invalid floating point (" .. rreason .. ")"
      end
      if runit == "dpi" then
        dpmm = f32(f32(r) / f32(25.4))
      else
        dpmm = r
      end
    end
    if dpmm == 0 then dpmm = f32(12) end

    if x_mm > f32(10) or dpmm > f32(1000) then
      if x_mm > f32(10) then
        warn(string.format(
          "Warning 185: scalexdimdp X-dim '%g' out of range (greater than 10), **IGNORED**",
          x_mm))
      else
        warn(string.format(
          "Warning 186: scalexdimdp resolution '%g' out of range (greater than 1000), **IGNORED**",
          dpmm))
      end
    else
      if x_mm == 0 then x_mm = default_xdim(symbol.symbology) end
      symbol.scale = scale_from_xdim(x_mm, dpmm)
      symbol.dpmm = dpmm
    end
  end

  if not absent(opts.height) then
    local v, reason = validate_float(opts.height, false)
    if not v then
      return nil, "Error 183: Invalid symbol height floating point (" .. reason .. ")"
    end
    if v < f32(0.5) or v > f32(2000) then
      warn("Warning 110: Symbol height '" .. tostring(opts.height)
        .. "' out of range (0.5 to 2000), **IGNORED**")
    else
      symbol.height = v
    end
  end

  -- frontend/main.c OPT_VERS. Digits only, at most 9, and 1..999. Zero and
  -- anything past 999 are warned and ignored. Interleaved 2 of 5 reads 1 as
  -- "append a GS1 check digit" and 2 as "append it and hide it". Other
  -- symbologies keep the value on option_2 and use it only where the encoder
  -- already did.
  if not absent(opts.vers) then
    local text = tostring(opts.vers)
    -- Zero is a real value here (out of range, warned). A failed match must
    -- not be written as `if not val`, because 0 is false in Lua.
    if #text > 9 or not text:match("^%d+$") then
      return nil, "Error 133: Invalid version value (digits only)"
    end
    local val = tonumber(text)
    if val >= 1 and val <= 999 then
      symbol.option_2 = val
    else
      warn(string.format(
        "Warning 113: Version value '%d' out of range (1 to 999), **IGNORED**",
        val))
    end
  end

  -- frontend/main.c OPT_COLS. Any symbology stores it on option_2. DataBar
  -- Expanded Stacked reads 1..11 as columns per row. Applied after --vers,
  -- so when both are set the column count wins.
  if not absent(opts.cols) then
    local text = tostring(opts.cols)
    if not text:match("^%d+$") then
      return nil, "Error 131: Invalid columns value (digits only)"
    end
    local val = tonumber(text)
    if val >= 1 and val <= 200 then
      symbol.option_2 = val
    else
      warn(string.format(
        "Warning 111: Number of columns '%d' out of range (1 to 200), **IGNORED**",
        val))
    end
  end

  -- frontend/main.c OPT_ROWS. Out of range warns for every symbology. In
  -- range, only Expanded Stacked stores it, and it stores it on option_3.
  if not absent(opts.rows) then
    local text = tostring(opts.rows)
    if not text:match("^%d+$") then
      return nil, "Error 132: Invalid rows value (digits only)"
    end
    local val = tonumber(text)
    if val >= 1 and val <= 90 then
      if symbol.symbology == 81 then symbol.option_3 = val end
    else
      warn(string.format(
        "Warning 112: Number of rows '%d' out of range (1 to 90), **IGNORED**",
        val))
    end
  end

  if not absent(opts.border) then
    local v = validate_int(opts.border)
    if not v then
      return nil, "Error 107: Invalid border width value (digits only)"
    end
    if v > 1000 then
      warn("Warning 108: Border width '" .. tostring(opts.border)
        .. "' out of range (0 to 1000), **IGNORED**")
    else
      symbol.border_width = v
    end
  end

  if not absent(opts.whitesp) then
    local v = validate_int(opts.whitesp)
    if not v then
      return nil, "Error 120: Invalid horizontal whitespace value '"
        .. tostring(opts.whitesp) .. "' (digits only)"
    end
    if v > 1000 then
      warn("Warning 121: Horizontal whitespace value '" .. tostring(opts.whitesp)
        .. "' out of range (0 to 1000), **IGNORED**")
    else
      symbol.whitespace_width = v
    end
  end

  if not absent(opts.vwhitesp) then
    local v = validate_int(opts.vwhitesp)
    if not v then
      return nil, "Error 153: Invalid vertical whitespace value '"
        .. tostring(opts.vwhitesp) .. "' (digits only)"
    end
    if v > 1000 then
      warn("Warning 154: Vertical whitespace value '" .. tostring(opts.vwhitesp)
        .. "' out of range (0 to 1000), **IGNORED**")
    else
      symbol.whitespace_height = v
    end
  end

  local angle = 0
  if not absent(opts.rotate) then
    local v = validate_int(opts.rotate)
    if not v then
      return nil, "Error 117: Invalid rotation value (digits only)"
    end
    if v ~= 0 and v ~= 90 and v ~= 180 and v ~= 270 then
      warn("Warning 137: Rotation value '" .. tostring(opts.rotate)
        .. "' out of range (0, 90, 180 or 270 only), **IGNORED**")
    else
      angle = v
    end
  end

  if not absent(opts.dotsize) then
    local v, reason = validate_float(opts.dotsize, false)
    if not v then
      return nil, "Error 181: Invalid dot radius floating point (" .. reason .. ")"
    end
    if v < f32(0.01) then
      warn("Warning 106: Invalid dot radius value (less than 0.01), **IGNORED**")
    else
      symbol.dot_size = v
    end
  end

  if not absent(opts.textgap) then
    local v, reason = validate_float(opts.textgap, true)
    if not v then
      return nil, "Error 194: Invalid text gap floating point (" .. reason .. ")"
    end
    if v < f32(-5) or v > f32(10) then
      warn("Warning 195: Text gap '" .. tostring(opts.textgap)
        .. "' out of range (-5 to 10), **IGNORED**")
    else
      symbol.text_gap = v
    end
  end

  if not absent(opts.guarddescent) then
    local v, reason = validate_float(opts.guarddescent, false)
    if not v then
      return nil, "Error 182: Invalid guard bar descent floating point (" .. reason .. ")"
    end
    if v < f32(0) or v > f32(50) then
      warn("Warning 135: Guard bar descent '" .. tostring(opts.guarddescent)
        .. "' out of range (0 to 50), **IGNORED**")
    else
      symbol.guard_descent = v
    end
  end

  -- Colour. The CLI wrapper drops an option that is no longer the last writer
  -- of any field it writes, then the survivors are applied in this order:
  -- reverse, foreground, background, no-background. That order matches the
  -- cases where two of them both survive.
  if opts.reverse then
    symbol.fgcolour = "ffffff"
    symbol.bgcolour = "000000"
  end
  if not absent(opts.fg) then
    local err = output.check_colour(tostring(opts.fg), "foreground")
    if err then return nil, err end
    symbol.fgcolour = tostring(opts.fg)
  end
  if not absent(opts.bg) then
    local err = output.check_colour(tostring(opts.bg), "background")
    if err then return nil, err end
    symbol.bgcolour = tostring(opts.bg)
  end
  if opts.nobackground then
    symbol.bgcolour = "ffffff00"
  end

  -- --gs1parens selects the parenthesis syntax and, as of 2.16, also enters
  -- GS1 mode. A symbology that cannot do GS1 then fails with Error 220.
  if opts.gs1 or opts.gs1parens then
    symbol.input_mode = (symbol.input_mode & ~0x07) | common.GS1_MODE
  end
  if opts.gs1parens then symbol.input_mode = symbol.input_mode | common.GS1PARENS_MODE end
  if opts.esc then symbol.input_mode = symbol.input_mode | common.ESCAPE_MODE end
  if opts.extraesc then symbol.input_mode = symbol.input_mode | common.EXTRA_ESCAPE_MODE end
  if opts.heightperrow then symbol.input_mode = symbol.input_mode | common.HEIGHTPERROW_MODE end

  if opts.compliantheight then symbol.output_options = symbol.output_options | common.COMPLIANT_HEIGHT end
  if opts.quietzones then symbol.output_options = symbol.output_options | common.BARCODE_QUIET_ZONES end
  if opts.noquietzones then symbol.output_options = symbol.output_options | common.BARCODE_NO_QUIET_ZONES end
  if opts.bind then symbol.output_options = symbol.output_options | common.BARCODE_BIND end
  if opts.bindtop then symbol.output_options = symbol.output_options | common.BARCODE_BIND_TOP end
  if opts.box then symbol.output_options = symbol.output_options | common.BARCODE_BOX end
  if opts.small then symbol.output_options = symbol.output_options | common.SMALL_TEXT end
  if opts.bold then symbol.output_options = symbol.output_options | common.BOLD_TEXT end
  if opts.embedfont then symbol.output_options = symbol.output_options | common.EMBED_VECTOR_FONT end
  if opts.dotty then symbol.output_options = symbol.output_options | common.BARCODE_DOTTY_MODE end
  if opts.init then symbol.output_options = symbol.output_options | common.READER_INIT end
  if opts.notext then symbol.show_hrt = 0 end

  return angle, nil, warned
end

return M
