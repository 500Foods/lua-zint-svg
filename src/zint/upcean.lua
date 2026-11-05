-- zint/upcean.lua -- ports backend/upcean.c, restricted to UPC-A.
--
-- upcean.c handles the whole EAN/UPC family in one file: EAN-13, EAN-8, UPC-A,
-- UPC-E, ISBN, and the two- and five-digit add-ons that can hang off any of
-- them. Only UPC-A (and its BARCODE_UPCA_CHK variant, which differs solely in
-- whether the check digit is supplied) is in scope here, so the other five
-- entry points are absent. What *is* kept is the shared machinery they all use
-- -- the EANsetA/EANsetB representation tables, the add-on encoder, and the
-- leading-zero padding -- because UPC-A goes through all of it, and because the
-- next symbology added from this file would otherwise have to re-port it.
--
-- Two things about UPC-A make it unlike the four symbologies already here.
--
-- The first is that the symbol has a fixed width. Code 39 and Code 128 grow
-- with the data; UPC-A is always 95 modules, always twelve digits, and the
-- encoder's job is mostly validation. That makes the encoder small and pushes
-- the interesting work into vector.c, which has an entire second layout path
-- for this family -- guard bars that hang below the others, and a text line
-- broken into four separately-positioned pieces rather than one centred string.
--
-- The second is the check digit. UPC-A is the first symbology here where the
-- data can be *wrong* in a way zint detects: pass twelve digits with a bad
-- twelfth and it refuses rather than encoding what you gave it.

local common = require "zint.common"

local M = {}

local f32, ctoi = common.stripf, common.ctoi

-- ------------------------------------------------------------------- tables

-- backend/upcean.c EANsetA -- "Representation set A and C (EN Table 1)".
--
-- Each entry is the four element widths of one digit, in modules, alternating
-- space/bar/space/bar or bar/space/bar/space depending on where the digit
-- lands. Every row sums to 7, which is what makes the symbol width fixed.
--
-- Stored as strings rather than tables of characters because that is what
-- common.expand consumes: the whole symbol is built by concatenating these into
-- one run-length string.
local EANsetA = {
  [0] = "3211", "2221", "2122", "1411", "1132",
        "1231", "1114", "1312", "1213", "3112",
}

-- backend/upcean.c EANsetB -- "Representation set B (EN Table 1)". The mirror
-- of set A, read right to left, which inverts bar and space. UPC-A proper never
-- uses it -- upca_draw is set A throughout -- but the add-ons do, and their
-- parity pattern is what carries the add-on's own check information.
local EANsetB = {
  [0] = "1123", "1222", "2212", "1141", "2311",
        "1321", "4111", "2131", "3121", "2113",
}

-- backend/upcean.c EAN2Parity -- "Number sets for 2-digit add-on (EN Table 6)".
local EAN2Parity = { [0] = "AA", "AB", "BA", "BB" }

-- backend/upcean.c EAN5Parity -- "Number set for 5-digit add-on (EN Table 7)".
local EAN5Parity = {
  [0] = "BBAAA", "BABAA", "BAABA", "BAAAB", "ABBAA",
        "AABBA", "AAABB", "ABABA", "ABAAB", "AABAB",
}

-- ------------------------------------------------------------- check digit

-- backend/gs1.c `gs1_check_digit()` -- the standard GS1 modulo-10 check
-- (GS1 General Specifications 7.9.1).
--
-- Digits are weighted 3 and 1 alternately, but which weight the *first* digit
-- gets depends on the length: `factor = length & 1 ? 3 : 1`. Eleven digits is
-- odd, so a UPC-A body starts on 3. Getting that backwards produces a check
-- digit that is right half the time, which is a miserable thing to debug.
--
-- Lives here rather than in gs1.lua because gs1.lua is the AI parser and this
-- is arithmetic on a digit string; the C keeps them together only because they
-- share a header.
local function gs1_check_digit(source, length)
  local count = 0
  local factor = (length & 1) ~= 0 and 3 or 1

  for i = 1, length do
    count = count + factor * ctoi(source:sub(i, i))
    factor = factor ~ 2 -- toggles 1 and 3
  end

  return string.char(48 + (10 - (count % 10)) % 10)
end

-- ------------------------------------------------------------------ drawing

-- backend/upcean.c `upca_draw()`. Builds the run-length string for the whole
-- symbol: guard, six digits, centre guard, six digits, guard.
--
-- The comment in the C -- "also inverts right hand characters" -- is about the
-- physical symbol rather than this code. The centre guard is five elements, an
-- odd count, so everything after it lands on the opposite bar/space phase from
-- everything before. The same EANsetA row therefore draws as bars on the left
-- and spaces on the right, which is what lets a scanner tell which way up the
-- label is. Nothing here has to do anything to make that happen; it falls out
-- of the element count.
local function upca_draw(source, length)
  local half_way = length // 2
  local d = { "111" } -- start guard

  for i = 1, length do
    if i - 1 == half_way then
      d[#d + 1] = "11111" -- centre guard, separating manufacturer from product
    end
    d[#d + 1] = EANsetA[ctoi(source:sub(i, i))]
  end

  d[#d + 1] = "111" -- stop guard
  return table.concat(d)
end

-- backend/upcean.c `ean_add_on()`. Appends a two- or five-digit add-on to a
-- symbol already built by upca_draw.
--
-- The add-on has no check digit of its own. Instead the *parity* of its digits
-- -- which of set A and set B each is drawn from -- encodes a checksum, which
-- is why the tables above are indexed by a computed value rather than by
-- position. For EAN-2 that value is the two digits read as a number mod 4; for
-- EAN-5 it is a weighted sum mod 10.
--
-- `addon_gap` is the space between the main symbol and the add-on, in modules;
-- it comes out as a single run-length digit, so it has to be 9-12 and is
-- clamped to that by the caller.
local function ean_add_on(source, length, dest, addon_gap)
  local d = { dest }

  if addon_gap ~= 0 then
    d[#d + 1] = string.char(48 + addon_gap)
  end

  d[#d + 1] = "112" -- add-on start character

  local parity
  if length == 2 then
    local code_value = 10 * ctoi(source:sub(1, 1)) + ctoi(source:sub(2, 2))
    parity = EAN2Parity[code_value % 4]
  else
    -- The C reads six values out of a five-digit string here -- values[5] picks
    -- up the terminating NUL, for which ctoi returns -1 -- and then never uses
    -- it. Only indices 0..4 reach the sum, so the loop below stops at five.
    local v = {}
    for i = 1, 5 do v[i] = ctoi(source:sub(i, i)) end
    local parity_sum = 3 * (v[1] + v[3] + v[5]) + 9 * (v[2] + v[4])
    parity = EAN5Parity[parity_sum % 10]
  end

  for i = 1, length do
    local digit = ctoi(source:sub(i, i))
    d[#d + 1] = (parity:sub(i, i) == "A") and EANsetA[digit] or EANsetB[digit]
    if i ~= length then
      d[#d + 1] = "11" -- glyph separator
    end
  end

  return table.concat(d)
end

-- --------------------------------------------------------------- UPC-A proper

-- BS EN 797:1996 4.5.1 nominal dimensions, 22.85mm at an 0.33mm X dimension.
-- Same as the minimum in GS1 General Specifications 21.0.1 5.12.3.1.
--
-- Narrowed exactly where the C narrows: both literals are floats, the division
-- happens in float, and stripf() then re-narrows the result. Writing this as
-- f32(22.85 / 0.33) instead -- one narrowing rather than three -- gives
-- 69.2424240112 where zint has 69.2424240112, which happens to agree; the
-- bracketing is kept because agreeing by luck is not the same as being right.
local COMPLIANT_HEIGHT = f32(f32(22.85) / f32(0.33))

-- backend/upcean.c `upca_cc()`, without the composite arm.
--
-- `symbol.text` is set here, to the full twelve digits including the check --
-- so the human-readable line shows the digit zint computed even when the caller
-- supplied only eleven. vector.lua then slices that string into its four
-- pieces, which is why the length has to be exactly twelve by the time this
-- returns.
local function upca(symbol, source, length)
  local gtin = source

  if length == 11 then
    -- Eleven digits: zint supplies the twelfth.
    gtin = gtin .. gs1_check_digit(gtin, 11)
    length = 12
  else
    -- Twelve digits: the twelfth must be the one zint would have computed.
    -- Note the check is calculated over the first eleven characters of the
    -- twelve-digit string, not over a separate body.
    local expected = gs1_check_digit(gtin, 11)
    local given = gtin:sub(length, length)
    if given ~= expected then
      return nil, string.format(
        "Error 270: Invalid check digit '%s', expecting '%s'", given, expected)
    end
  end

  symbol.text = gtin

  local dest = upca_draw(gtin, length)

  if (symbol.output_options & common.COMPLIANT_HEIGHT) ~= 0 then
    common.set_height(symbol, COMPLIANT_HEIGHT, COMPLIANT_HEIGHT, 0.0)
  else
    common.set_height(symbol, 0.0, 50.0, 0.0)
  end

  return dest
end

-- backend/upcean.c `ean_leading_zeroes()`, reduced to the UPC-A arms.
--
-- Splits the input at a "+" or a space into the main body and the add-on, then pads each
-- with leading zeroes up to the length its symbology wants. UPC-A wants eleven
-- (twelve for UPCA_CHK, where the check digit is part of the input); an add-on
-- is padded to two or five.
--
-- This is why "00" .. nine digits and eleven digits both work, and also why a
-- three-digit input is accepted: it becomes 00000000123. The padding is silent
-- -- no warning -- so a caller who miscounts gets a valid symbol for a
-- different number.
--
-- Returns nil plus a flag when a part is too long for any padding to help. The
-- flag says *which* part overflowed, because the caller uses it to pick the
-- message. The C computes it as `second_len > 5 ? with_addon : 0`, which is a
-- longer way of writing `second_len > 5`: a second part can only be non-empty
-- if there was a "+" to begin with.
local function ean_leading_zeroes(symbol, source)
  local sep = source:find("[+ ]")
  local with_addon = sep ~= nil

  local first_part = with_addon and source:sub(1, sep - 1) or source
  local second_part = with_addon and source:sub(sep + 1) or ""

  -- The C counts characters rather than splitting, which means a *second* "+"
  -- would land in second_part's count. It cannot get here -- eanx_cc rejects
  -- multiple pluses first -- so a plain split is equivalent.
  if #first_part > 13 or #second_part > 5 then
    return nil, #second_part > 5 -- true: the add-on overflowed, not the body
  end

  local zfirst_len = (symbol.symbology == 35) and 12 or 11 -- UPCA_CHK / UPCA
  local zsecond_len
  if #second_part == 0 then
    zsecond_len = 0
  elseif #second_part <= 2 then
    zsecond_len = 2
  else
    zsecond_len = 5
  end

  -- string.rep with a negative count gives "", matching the C's for-loop that
  -- simply does not run when the target is shorter than the input.
  first_part = string.rep("0", zfirst_len - #first_part) .. first_part
  if with_addon then
    second_part = string.rep("0", zsecond_len - #second_part) .. second_part
  end

  return first_part, second_part
end

-- backend/upcean.c `eanx_cc()`, reduced to the UPC-A arms.
--
-- The order of the checks is the C's. It matters in one place: the "one +
-- only" test runs before the padding, so "1+2+3" is rejected as malformed
-- rather than silently padded into something.
function M.upca(symbol, source)
  if #source > 19 then
    return nil, "Error 283: Input too long (19 character maximum)"
  end

  -- SODIUM "0123456789+ ". A space is an add-on separator, the same as "+".
  local bad = source:find("[^0-9+ ]")
  if bad then
    return nil, string.format(
      "Error 284: Invalid character at position %d in input (digits and \"+\" or space only)",
      bad)
  end

  local _, sep_count = source:gsub("[+ ]", "")
  if sep_count > 1 then
    return nil, "Error 293: Invalid add-on data (one \"+\" or space only)"
  end

  local first_part, second_part = ean_leading_zeroes(symbol, source)
  if not first_part then
    -- On failure the second return is the "which part" flag, not a string.
    return nil, "Error 294: Input too long (" ..
      (second_part and "5 character maximum for add-on" or "13 character maximum")
      .. ")"
  end

  -- Gap between symbol and add-on. UPC-A's minimum is 9 modules where the rest
  -- of the family uses 7, because UPC-A's right quiet zone is wider.
  -- --addongap (option_2) is not among the options this port accepts, so the
  -- default is what always applies.
  local addon_gap = 0
  if #second_part > 0 then
    local o2 = symbol.option_2
    addon_gap = (o2 >= 9 and o2 <= 12) and o2 or 9
  end

  if #first_part ~= 11 and #first_part ~= 12 then
    return nil, "Error 288: Input wrong length (12 character maximum)"
  end

  local dest, err = upca(symbol, first_part, #first_part)
  if not dest then return nil, err end

  if #second_part == 2 or #second_part == 5 then
    dest = ean_add_on(second_part, #second_part, dest, addon_gap)
    symbol.text = symbol.text .. "+" .. second_part
  elseif #second_part ~= 0 then
    return nil, "Error 292: Add-on data wrong length (2 or 5 characters only)"
  end

  common.expand(symbol, dest)

  return true
end

return M
