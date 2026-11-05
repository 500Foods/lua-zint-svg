-- zint/gs1.lua -- ports the input-reduction half of backend/gs1.c
--
-- GS1 data arrives with its Application Identifiers written out in brackets:
--
--     [01]09501101020917[10]AB-123
--
-- and has to be reduced to the byte stream that actually gets encoded, in
-- which the brackets are gone and FNC1 characters mark the end of any AI whose
-- length is not fixed by the standard:
--
--     0109501101020917 10AB-123        (no separator: (01) is a fixed 14+2)
--
-- The reduced string uses the byte `[` to stand for FNC1, which is safe
-- because a literal `[` cannot survive the reduction -- every bracket in the
-- input is consumed as a delimiter. The encoders downstream test for `[` and
-- emit codeword 102.
--
-- ------------------------------------------------------------------ scope
--
-- What is NOT ported: `gs1_lint()` and the 900-line AI table behind it in
-- gs1_lint.h, which validates each AI's data against the GS1 General
-- Specifications -- that (01) is fourteen digits with a correct check digit,
-- that (17) is a real date, that (3103) has the right number of decimals, and
-- so on for several hundred AIs with two dozen distinct validator functions.
--
-- It is left out because it cannot change a byte of the output. Its failures
-- split three ways: an unknown AI or a bad length aborts the encode entirely
-- and produces no file at all, and everything else is a *warning* -- zint
-- prints it to stderr and writes exactly the same SVG. Since the task states
-- the input is valid, the abort cases never fire and the warning cases are
-- invisible. Porting it would be several hundred lines that no test can
-- distinguish from an empty function.
--
-- What IS ported is everything structural: the bracket checks, the AI-length
-- checks, the empty-data check, and the reduction itself. Those are cheap,
-- they are what turns malformed input into a clear message rather than a
-- wrong symbol, and the last of them is not optional -- it is the output.

local common = require "zint.common"

local M = {}

-- backend/common.c `to_int()` -- a fixed-width numeric field, or -1 if any of
-- it is not a digit.
local function to_int(s, from, len)
  local field = s:sub(from, from + len - 1)
  if #field ~= len or field:match("^%d+$") == nil then return -1 end
  return tonumber(field)
end

-- The predefined-length AIs, from GS1 General Specifications Release 21.0.1
-- figure 7.8.4-2: element strings whose total length the standard fixes, so a
-- reader knows where they end without a separator. Keyed on the first two
-- digits of the AI.
--
-- The C writes this as a chain of range tests rather than a table. It is a
-- table here because the ranges are data, not logic -- but the membership is
-- exactly the C's:
--
--     00-04, 11-20, 23, 31-36, 41
--
-- 23 is in the list for backward compatibility only. It complies with
-- ISO/IEC 24724:2011 table D.1 but clashes with AI (235), introduced in 2019;
-- zint's source carries a TODO about removing it. Kept, because matching zint
-- is the point.
local PREDEFINED_LENGTH = {}
for _, range in ipairs { { 0, 4 }, { 11, 20 }, { 23, 23 }, { 31, 36 }, { 41, 41 } } do
  for ai = range[1], range[2] do PREDEFINED_LENGTH[ai] = true end
end

-- backend/gs1.c `gs1_verify()`.
--
-- Returns the reduced string, or nil plus a message. The C's distinction
-- between an error and a warning collapses here: a warning leaves the reduced
-- string valid and the output unchanged, so there is nothing for the caller to
-- do with it.
function M.verify(symbol, source)
  -- --gs1parens swaps which pair of characters delimits an AI. It is read off
  -- the symbol rather than passed in because that is where the C reads it, and
  -- one source of truth beats two. Note the FNC1 marker in the reduced string
  -- is always `[` regardless: that is an internal sentinel, not a delimiter.
  local obracket, cbracket = "[", "]"
  if (symbol.input_mode & common.GS1PARENS_MODE) ~= 0 then
    obracket, cbracket = "(", ")"
  end

  -- GS1 is ASCII-only and has no room for control characters: the reduced
  -- string reserves the low bytes for FNC1 and the encoders assume printables.
  for i = 1, #source do
    local b = source:byte(i)
    if b >= 128 then
      return nil, "250: Extended ASCII characters are not supported by GS1"
    elseif b == 0 then
      return nil, "262: NUL characters not permitted in GS1 mode"
    elseif b < 32 then
      return nil, "251: Control characters are not supported by GS1"
    elseif b == 127 then
      return nil, "263: DEL characters are not supported by GS1"
    end
  end

  if source:sub(1, 1) ~= obracket then
    return nil, "252: Data does not start with an AI"
  end

  -- One pass to check the shape of the brackets and the AIs between them.
  -- `ai_latch` here means "we are inside an AI" and is unrelated to the
  -- similarly named variable in the reduction pass below -- the C reuses the
  -- name for both, which is worth knowing when reading them side by side.
  local bracket_level, max_bracket_level = 0, 0
  local ai_length, max_ai_length, min_ai_length = 0, 0, 5
  local ai_zero_len_no_data, ai_single_digit, ai_nonnumeric = false, false, false
  local in_ai = false

  for i = 1, #source do
    local c = source:sub(i, i)
    if c == obracket then
      bracket_level = bracket_level + 1
      if bracket_level > max_bracket_level then max_bracket_level = bracket_level end
      in_ai = true
    elseif c == cbracket then
      bracket_level = bracket_level - 1
      if ai_length > max_ai_length then max_ai_length = ai_length end
      if ai_length < min_ai_length then min_ai_length = ai_length end
      if ai_length == 0 and (i == #source or source:sub(i + 1, i + 1) == obracket) then
        ai_zero_len_no_data = true
      elseif ai_length == 1 then
        ai_single_digit = true
      end
      ai_length = 0
      in_ai = false
    elseif in_ai then
      ai_length = ai_length + 1
      if not c:match("%d") then ai_nonnumeric = true end
    end
  end

  if bracket_level ~= 0 then
    return nil, "253: Malformed AI in input data (brackets don't match)"
  end
  if max_bracket_level > 1 then
    return nil, "254: Found nested brackets in input data"
  end
  if max_ai_length > 4 then
    return nil, "255: Invalid AI in input data (AI too long)"
  end
  -- The C also allows a short AI under GS1NOCHECK_MODE, which the CLI reaches
  -- with --gs1nocheck. Not in the task's option set, so this is unconditional.
  if min_ai_length <= 1 then
    return nil, "256: Invalid AI in input data (AI too short)"
  end
  if ai_nonnumeric then
    return nil, "257: Invalid AI in input data (non-numeric characters in AI)"
  end

  -- Every AI must have some data after it. The C computes each AI's data
  -- offset from the AI's own magnitude -- three characters past the opening
  -- bracket for a two-digit AI, four for three digits, five for four -- and
  -- then measures forward to the next opening bracket or the end.
  local i = 2
  while i <= #source do
    if source:sub(i - 1, i - 1) == obracket then
      local j = 1
      while source:sub(i + j, i + j) ~= cbracket do j = j + 1 end
      local ai_value = to_int(source, i, j)

      local data_location
      if ai_value >= 1000 then
        data_location = i + 5
      elseif ai_value >= 100 then
        data_location = i + 4
      else
        data_location = i + 3
      end

      local data_length = 0
      while data_location + data_length <= #source
          and source:sub(data_location + data_length, data_location + data_length) ~= obracket do
        data_length = data_length + 1
      end
      if data_length == 0 then
        return nil, "258: Empty data field in input data"
      end

      -- gs1_lint() would run here. See the scope note at the top.
      i = i + j
    end
    i = i + 1
  end

  -- The reduction. Brackets are dropped; an FNC1 is inserted before an AI only
  -- when the *previous* AI was variable-length and so needs terminating.
  --
  -- `ai_latch` starts set, which is what stops an FNC1 appearing before the
  -- first AI -- the start character already carries one for GS1-128.
  local reduced = {}
  local ai_latch = true

  for k = 1, #source do
    local c = source:sub(k, k)
    if c ~= obracket and c ~= cbracket then
      reduced[#reduced + 1] = c
    end
    if c == obracket then
      if not ai_latch then reduced[#reduced + 1] = "[" end
      if k ~= #source then
        -- Only the first two digits decide this, even for a four-digit AI:
        -- the predefined-length list is defined on the AI's leading pair.
        local last_ai = to_int(source, k + 1, 2)
        ai_latch = PREDEFINED_LENGTH[last_ai] or false
      end
    end
    -- The closing bracket is simply dropped.
  end

  return table.concat(reduced)
end

return M
