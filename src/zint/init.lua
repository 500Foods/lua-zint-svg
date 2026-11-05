-- src/zint/init.lua -- the pure-Lua zint port.
--
-- Library entry point. Callers use `local zint = require "zint"`. There is no
-- forced global. `zint.barcode(opts)` returns an SVG document, or a PDF form
-- table when opts.filetype is "PDF".
--
-- opts fields are named after the zint long option they come from and take the
-- same values. A flag is on when its key is truthy. A valued option may be
-- given as a string or a number. Strings are parsed the way the 2.16.0 CLI
-- parses them, which is why the command-line wrapper passes the text through
-- unchanged. Float parsing lives in options.lua.
--
--   barcode       number or name; defaults to 20 (CODE128) when absent
--   data          symbol data content
--   output        path to write the SVG to
--   fg, bg        colour as RGB, RGBA, or "C,M,Y,K"
--   filetype      "SVG" (default) or "PDF" (form XObject content stream)
--   gs1           treat input as GS1 data
--   gs1parens     "()" rather than "[]" as AI delimiters
--   nobackground  omit the background rect
--
--   scale         output scale multiplier, >= 0.01
--   scalexdimdp   "xdim[,resolution]", e.g. "0.33mm,600dpi" -- overrides scale
--   height        symbol height in modules, 0.5 to 2000
--   heightperrow  read height as per-row rather than overall
--   compliantheight  use the standard's height rather than zint's default 50
--   border        border width in modules, 0 to 1000
--   bind          boundary bars above and below
--   bindtop       boundary bar above only
--   box           box around the symbol
--   whitesp       horizontal whitespace in modules, 0 to 1000
--   vwhitesp      vertical whitespace in modules, 0 to 1000
--   quietzones    add the standards' quiet zones
--   noquietzones  remove them
--   notext        no human readable text
--   small         smaller human readable text
--   bold          bolder human readable text
--   textgap       gap between symbol and text, -5 to 10
--   embedfont     inline the font as a base64 @font-face
--   guarddescent  UPC/EAN guard bar descent, 0 to 50
--   dotty         draw circles rather than squares
--   dotsize       dot diameter in modules, >= 0.01
--   rotate        0, 90, 180 or 270
--   reverse       white on black
--   init          reader initialisation (programming) symbol
--   esc           process escape sequences in the data
--   extraesc      process Code 128 "\^A"/"\^B"/"\^C" code-set escapes
--
-- Runs with no shell, no native modules and no access to zint: the point of
-- the port is that it works inside a browser or an embedded Lua interpreter
-- where the binary is not there to fall back on.
--
-- The modules under zint/ mirror the C files they are ported from, so a
-- function here can be read next to its original:
--
--   zint/common.lua   backend/common.c   float32 narrowing, module bitmap
--   zint/output.lua   backend/output.c   number formatting, colours, offsets
--   zint/vector.lua   backend/vector.c   bitmap -> rectangles and strings
--   zint/svg.lua      backend/svg.c      rectangles and strings -> SVG text
--   zint/code.lua     backend/code.c     Code 39
--   zint/code128.lua  backend/code128.c  Code 128, GS1-128
--   zint/upcean.lua   backend/upcean.c   UPC-A
--   zint/gs1.lua      backend/gs1.c      GS1 AI parsing and input reduction
--   zint/eci.lua      backend/eci.c      UTF-8 to ISO 8859-1
--   zint/options.lua  (this repo)        option parsing, from the manual and the CLI
--   zint/pdf.lua      (this repo)        the same vector list, as PDF operators
--   zint/fonts.lua    backend/fonts/*.h  the --embedfont WOFF2 blobs

-- SVG decimals are part of the byte-identical claim. The C locale's decimal
-- point is a period. Callers that need another numeric locale can restore it
-- after barcode() returns.
os.setlocale("C", "numeric")

local common  = require "zint.common"
local eci     = require "zint.eci"
local options = require "zint.options"
local vector  = require "zint.vector"
local svg     = require "zint.svg"
local code    = require "zint.code"
local code128 = require "zint.code128"
local upcean  = require "zint.upcean"
local qr      = require "zint.qr"
local gs1     = require "zint.gs1"

-- ------------------------------------------------------------- symbologies
--
-- frontend/main.c `get_barcode_name()` resolves --barcode when it is not a
-- number: lower case, drop a leading "barcode", drop everything that is not
-- alphanumeric, then look the remainder up.

local BARCODE_CODE39    = 8
local BARCODE_GS1_128   = 16
local BARCODE_CODE128   = 20
local BARCODE_UPCA      = 34
local BARCODE_UPCA_CHK  = 35
local BARCODE_QRCODE    = 58

local NAMES = {
  code39   = BARCODE_CODE39,
  gs1128   = BARCODE_GS1_128,
  ean128   = BARCODE_GS1_128, -- synonym, as in main.c
  code128  = BARCODE_CODE128,
  upca     = BARCODE_UPCA,
  upcachk  = BARCODE_UPCA_CHK,
  qrcode   = BARCODE_QRCODE,
}

local function symbology_number(barcode)
  if barcode == nil then return BARCODE_CODE128 end -- --barcode omitted
  if type(barcode) == "number" then return barcode end

  local n = barcode:gsub("[A-Z]", function(c) return string.char(c:byte() | 0x20) end)
  if n:sub(1, 7) == "barcode" then n = n:sub(8) end
  n = n:gsub("[^%w]", "")
  return NAMES[n]
end

-- backend/library.c `barcode_symbology()`, restricted to what is implemented.
local ENCODERS = {
  [BARCODE_CODE39]  = code.code39,
  [BARCODE_CODE128] = code128.code128,
  [BARCODE_GS1_128] = function(symbol, source, opts)
    -- GS1-128 is one of the symbologies `check_force_gs1()` lists, which means
    -- GS1 mode is on whether or not --gs1 was given: passing the flag changes
    -- nothing here. It also means `ZBarcode_Encode_Segs` does *not* reduce the
    -- input on the encoder's behalf, as it does for the symbologies that only
    -- enter GS1 mode when asked -- gs1_128_cc() calls gs1_verify() itself, so
    -- the reduction happens once, here.
    local reduced, err = gs1.verify(symbol, source)
    if not reduced then return nil, err end
    return code128.gs1_128(symbol, source, reduced)
  end,
  -- Both UPC-A variants run the same encoder. 34 appends the check digit and 35
  -- expects it supplied; upcean.lua tells them apart by symbol.symbology, which
  -- is also how the C does it -- the two share a case label in library.c.
  [BARCODE_UPCA]     = upcean.upca,
  [BARCODE_UPCA_CHK] = upcean.upca,
  -- QR is the other side of the GS1-128 coin: it is gs1-compliant but NOT
  -- force-gs1, so `ZBarcode_Encode_Segs` reduces the input before the encoder
  -- runs and qr.c never calls gs1_verify() itself. See the reduction step in
  -- barcode() below.
  [BARCODE_QRCODE]   = qr.qrcode,
}

-- backend/library.c `check_force_gs1()`. The symbologies that are in GS1 mode
-- whether or not --gs1 was given. Of the five here only GS1-128 qualifies, and
-- the distinction matters for exactly one thing: force-gs1 symbologies reduce
-- their own input, everything else has it reduced for them.
local FORCE_GS1 = {
  [BARCODE_GS1_128] = true,
}

-- backend/common.c `is_dotty()`. Dotty mode is a matrix-symbology feature: the
-- C's list is fifteen 2D symbologies long and contains no linear ones at all,
-- so of the five here only QR qualifies. --dotty on any of the other four is an
-- error rather than a no-op, which is worth knowing before wondering why a
-- dotted Code 128 never appears.
local IS_DOTTY = {
  [BARCODE_QRCODE] = true,
}

-- backend/library.c `gs1_compliant()` unioned with `check_force_gs1()`, cut
-- down to the five here. --gs1 on anything not in this table is an error, not a
-- no-op, so Code 39, Code 128 and UPC-A all refuse it.
local GS1_COMPLIANT = {
  [BARCODE_GS1_128] = true,
  [BARCODE_QRCODE]  = true,
}

-- backend/library.c `supports_eci()`, same treatment. Only used for the wording
-- of the empty-input message here, but it is the same list that decides whether
-- library.c retries a failed character-set conversion under a different ECI --
-- a path none of the four linear symbologies can take.
local SUPPORTS_ECI = {
  [BARCODE_QRCODE] = true,
}

-- backend/library.c `extended_or_reduced_charset()`. The symbologies listed
-- there are the ones that understand character sets themselves; everything else
-- falls through to `reduced_charset()`, which folds the input to ISO 8859-1
-- before the encoder sees it. QR is the only one of the five on the elite list,
-- which is why it -- alone -- receives raw UTF-8.
local HANDLES_OWN_CHARSET = {
  [BARCODE_QRCODE] = true,
}

-- backend/zint.h.
local ZINT_MAX_DATA_LEN = 17400

-- backend/library.c, "Check other symbol fields". A second range check on top
-- of the front end's, and a stricter one: main.c lets --border go to 1000 and
-- this refuses anything over 100, so `--border 500` warns nowhere and simply
-- produces no file. Returns the message, or nil when everything is in range.
--
-- The float bounds are f32'd for the reason options.lua spells out -- 0.01 as a
-- double is not 0.01f, and `--scale 0.01` sits exactly on that boundary.
local FIELD_CHECKS = {
  { "scale",             common.stripf(0.01), common.stripf(200.0),
    "Error 227: Scale out of range (0.01 to 200)" },
  { "dot_size",          common.stripf(0.01), common.stripf(20.0),
    "Error 221: Dot size out of range (0.01 to 20)" },
  { "height",            common.stripf(0.0),  common.stripf(2000.0),
    "Error 765: Height out of range (0 to 2000)" },
  { "guard_descent",     common.stripf(0.0),  common.stripf(50.0),
    "Error 769: Guard bar descent out of range (0 to 50)" },
  { "text_gap",          common.stripf(-5.0), common.stripf(10.0),
    "Error 219: Text gap out of range (-5 to 10)" },
  { "whitespace_width",  0, 100,
    "Error 766: Whitespace width out of range (0 to 100)" },
  { "whitespace_height", 0, 100,
    "Error 767: Whitespace height out of range (0 to 100)" },
  { "border_width",      0, 100,
    "Error 768: Border width out of range (0 to 100)" },
}

local function check_symbol_fields(symbol)
  for _, c in ipairs(FIELD_CHECKS) do
    local v = symbol[c[1]]
    if v < c[2] or v > c[3] then return c[4] end
  end
  return nil
end

-- backend/library.c `strip_bom()`. RFC 3629 says a leading byte order mark is
-- not part of the text, so it goes -- unless it is the *whole* text, which the
-- strict `> 3` guards: three bytes of BOM and nothing else would otherwise
-- reduce to empty input.
local function strip_bom(source)
  if #source > 3 and source:sub(1, 3) == "\239\187\191" then
    return source:sub(4)
  end
  return source
end

-- ------------------------------------------------------------------- driver

local zint = {}

-- backend/library.c `ZBarcode_Encode_and_Print()`, collapsed to the one output
-- format this port covers. Returns the SVG text as well as writing it, which
-- makes the port testable without touching the filesystem.
function zint.barcode(opts)
  local symbology = symbology_number(opts.barcode)
  local encode = symbology and ENCODERS[symbology]
  if not encode then
    return nil, "Error 206: Symbology out of range"
  end

  local symbol = common.new_symbol()
  symbol.symbology = symbology

  -- Everything the command line would have done to the symbol before libzint
  -- ever sees it. Note 0 is truthy in Lua, so a rotation of 0 -- the common
  -- case -- passes this test; only a nil return means failure.
  local rotate_angle, aerr, warned = options.apply(symbol, opts)
  if rotate_angle == nil then return nil, aerr end

  -- --------------------------------------- backend/library.c ZBarcode_Encode_Segs
  --
  -- What follows is that function's preamble in its original order. The order
  -- is load-bearing in one respect only -- every branch below either produces
  -- an error and no file, or leaves the data changed for the next step -- but
  -- it is kept anyway so the two can be read side by side.

  local raw = opts.data or ""

  -- Segment length checks. The suffix on the empty-input message is not
  -- decoration: the C only mentions "segment 0" for symbologies that can have
  -- more than one segment in the first place.
  if #raw == 0 then
    return nil, "Error 778: No input data" ..
      (SUPPORTS_ECI[symbology] and " (segment 0 empty)" or "")
  end

  -- De-escaping. The C runs `escape_char_process` twice: once here, discarding
  -- the result and keeping only the length, and again further down to actually
  -- produce the bytes. One pass is enough as long as the error surfaces at this
  -- point rather than later, which is what the two-pass structure is really
  -- buying -- so the result is computed here and held until the C would have
  -- used it.
  --
  -- Doing it up front is also why `--esc --gs1` reduces the *de-escaped* data,
  -- and why the "\^A" sequences --extraesc looks for have to survive --esc
  -- untouched.
  local source = raw
  if (symbol.input_mode & common.ESCAPE_MODE) ~= 0 then
    local escaped, eerr = common.escape_char_process(symbol, raw)
    if not escaped then return nil, eerr end
    source = escaped
    if #source > ZINT_MAX_DATA_LEN then
      return nil, "Error 797: Input data too long"
    end
  elseif #raw > ZINT_MAX_DATA_LEN then
    return nil, "Error 777: Input data too long"
  end

  local ferr = check_symbol_fields(symbol)
  if ferr then return nil, ferr end

  if (symbol.input_mode & 0x07) == common.GS1_MODE and not GS1_COMPLIANT[symbology] then
    return nil, "Error 220: Selected symbology does not support GS1 mode"
  end

  -- Note this runs on the data as typed, before de-escaping: `é` is four
  -- ASCII characters and passes whatever it later expands to.
  if (symbol.input_mode & 0x07) == common.UNICODE_MODE
      and not common.is_valid_utf8(raw) then
    return nil, "Error 245: Invalid UTF-8 in input data"
  end

  if (symbol.input_mode & 0x07) == common.UNICODE_MODE then
    source = strip_bom(source)
  end

  -- GS1 reduction, for the symbologies that do not do it themselves.
  --
  -- `gs1_verify()` parses the AI syntax and rewrites the input into the form
  -- the encoders want: brackets stripped, FNC1 separators inserted as "[", and
  -- the whole thing validated. library.c runs it here for anything gs1-compliant
  -- that is not force-gs1, and *skips* it for the force-gs1 set because those
  -- encoders call it themselves. GS1-128 is in the skipped set; QR is not.
  --
  -- Running it twice would be worse than not running it at all -- the second
  -- pass would see "[" where the first left it and reject the input -- so the
  -- FORCE_GS1 guard is load-bearing, not defensive.
  if (symbol.input_mode & 0x07) == common.GS1_MODE and not FORCE_GS1[symbology] then
    local reduced, gerr = gs1.verify(symbol, source)
    if not reduced then return nil, gerr end
    source = reduced
  end

  -- `extended_or_reduced_charset()`. The default arm folds UTF-8 down to
  -- ISO 8859-1, so `é` reaches the encoder as one byte rather than the two it
  -- was typed as. Getting this wrong is not a rounding error: it encodes a
  -- different number of characters and produces a different symbol.
  if (symbol.input_mode & 0x07) == common.UNICODE_MODE
      and not HANDLES_OWN_CHARSET[symbology] then
    local converted = eci.utf8_to_latin1(source)
    if not converted then
      return nil, "Error 204: Invalid character in input data (ISO/IEC 8859-1 only)"
    end
    source = converted
  end

  local ok, err = encode(symbol, source, opts)
  if not ok then return nil, err end

  -- backend/library.c, tail of `ZBarcode_Encode_Segs()`. A general fallback for
  -- any encoder that left the height alone -- Code 128 is one, because
  -- ISO/IEC 15417 leaves height to the application. Code 39 sets its own, so
  -- this does not fire for it.
  if symbol.height < 0.5 then
    common.set_height(symbol, 0.0, 50.0, 0.0)
  end

  -- frontend/main.c prints symbol->errtxt as soon as ZBarcode_Encode returns,
  -- before ZBarcode_Print runs -- so a height warning appears ahead of anything
  -- the output stage has to say. Only one message survives, because the C has
  -- one buffer for it.
  --
  -- Reachable today only through --compliantheight; without it every encoder
  -- passes a minimum row height of zero and there is nothing to breach.
  if symbol.warning and io and io.stderr then
    io.stderr:write(symbol.warning, "\n")
  end

  -- backend/library.c `check_output_args()`, on the output path rather than the
  -- encode path -- which is why it runs here, after a symbol has already been
  -- built. Its rotation branch is unreachable from the command line, because
  -- options.apply has already thrown out any angle that is not one of the four;
  -- dotty mode is the branch that fires.
  if (symbol.output_options & common.BARCODE_DOTTY_MODE) ~= 0
      and not IS_DOTTY[symbology] then
    return nil, "Error 224: Selected symbology cannot be rendered as dots"
  end

  local ft = "SVG"
  if opts.filetype and opts.filetype ~= "" then
    ft = tostring(opts.filetype):upper()
  end
  if ft ~= "SVG" and ft ~= "PDF" then
    return nil, "Error 142: File type '" .. tostring(opts.filetype) .. "' not supported"
  end

  vector.plot(symbol, rotate_angle)
  local out
  if ft == "PDF" then
    out = require("zint.pdf").form(symbol)
  else
    out = svg.plot(symbol)
  end

  if opts.output then
    local payload = ft == "PDF" and out.content or out
    local f, oerr = io.open(opts.output, "wb")
    if not f then return nil, oerr end
    f:write(payload)
    f:close()
  end

  return out, symbol.warning, warned
end

return zint
