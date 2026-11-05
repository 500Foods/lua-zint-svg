-- zint/eci.lua -- ports backend/eci.c, restricted to the one conversion the
-- symbologies here can reach.
--
-- The C's `utf8_to_eci` dispatches through a table of 36 conversion functions,
-- one per Extended Channel Interpretation: ISO 8859-2 through -16, Shift JIS,
-- the Windows code pages, Big5, GB 18030, UTF-16 and UTF-32. None of that is
-- reachable from this port. Setting an ECI needs --eci, which the front end
-- here does not accept, and even with it, `library.c` refuses an ECI on any
-- symbology outside its "supports ECI" list -- of the five covered here only QR
-- is on that list, and QR is one of the "elite" symbologies that bypasses this
-- file entirely and does its own character-set handling inside the encoder.
--
-- So the ECI is always 0, and ECI 0 takes a special case at the top of the C
-- function: it is not a table lookup at all but a direct fold to ISO 8859-1.
-- That is what is ported. The rest is left out deliberately rather than
-- forgotten -- a full port would fill this file in, and the shape here leaves
-- room for it.
--
-- Why it matters at all, given the task's data is ASCII: `--esc` makes non-ASCII
-- reachable in one keystroke (`é`), and any UTF-8 in the data goes through
-- here. Skipping the conversion encodes "cafe\xc3\xa9" as five characters where
-- zint encodes four, which is a different barcode, not a rounding difference.

local common = require "zint.common"

local M = {}

-- backend/eci.c `utf8_to_eci()`, the `eci == 0 || eci == 3` branch. Returns the
-- converted bytes, or nil for ZINT_ERROR_INVALID_DATA.
--
-- Two ways to fail, and they are different failures wearing the same return
-- code: the input is not valid UTF-8, or it is valid UTF-8 for a codepoint that
-- ISO 8859-1 has no room for. The second test looks lopsided -- everything below
-- 0x80 passes, 0x80 to 0x9f is rejected, 0xa0 to 0xff passes, 0x100 up is
-- rejected -- because ISO 8859-1 leaves 0x80..0x9f as unassigned C1 control
-- codes. Latin-1 as most people mean it (Windows-1252, with quotes and dashes
-- in that gap) is a different ECI, number 23.
function M.utf8_to_latin1(source)
  local out = {}
  local state, codepoint = 0, 0
  local pos = 1
  local len = #source

  while pos <= len do
    -- The C's inner do/while: keep feeding bytes until the DFA either completes
    -- a codepoint (state 0) or gives up (state 12). Running off the end of the
    -- input mid-sequence leaves a state that is neither, which the test below
    -- catches -- a truncated multi-byte sequence is invalid, not ignorable.
    repeat
      state, codepoint = common.decode_utf8(state, codepoint, source:byte(pos))
      pos = pos + 1
    until pos > len or state == 0 or state == 12

    if state ~= 0 then return nil end
    if codepoint >= 0x80 and (codepoint < 0xa0 or codepoint >= 0x100) then
      return nil
    end
    out[#out + 1] = string.char(codepoint)
  end

  return table.concat(out)
end

return M
