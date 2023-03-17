-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- proof of concept Torque Script parser with PEG
-- not completely working yet, nowhere near ready

local M = {}

local epnf = require( "libs/lua-luaepnf/epnf" )

local nan, inf = 0/0, 1/0

local pg = epnf.define( function(_ENV) -- begin of grammar definition
  -- some useful lexical patterns
  local any = P( 1 )
  local comment = (P"//" * (any-P"\n")^0) +
                  (P"/*" * (any-P"*/")^0 * P"*/") -- comments
  local _ = (WS + comment)^0  -- white space
  local sign = S"+-"
  local digit = R"09"
  local digit1 = R"19"
  local octdigit = R"07"
  local hexdigit = R( "09", "af", "AF" )
  local decimal = P"0" + (digit1 * digit^0)
  local int = C( sign^-1 * decimal ) / tonumber
  local oct = P"0" * (C( octdigit^1 ) * Cc( 8 )) / tonumber
  local hex = P"0" * S"xX" * (C( hexdigit^1 ) * Cc( 16 )) / tonumber
  local letter = R( "az", "AZ" ) + P"_"
  local charescape = P"\\" * C( S"abfnrtv\\'\"" ) / {
    [ "a" ] = "\a", [ "b" ] = "\b", [ "f" ] = "\f",
    [ "n" ] = "\n", [ "r" ] = "\r", [ "t" ] = "\t",
    [ "v" ] = "\v", [ "\\" ] = "\\", [ "'" ] = "'",
    [ '"' ] = '"'
  }
  local hexescape = P"\\" * S"xX" * C( hexdigit * hexdigit^-1 ) / function( s )
    return string.char( tonumber( s, 16 ) )
  end
  local octescape = P"\\" * C( P"0"^-1 * octdigit * octdigit^-2 ) / function( s )
    return string.char( tonumber( s, 8 ) )
  end
  local sliteral = (P'"' * Cs( (charescape + hexescape +
                     octescape + (any-P'"'))^0 ) * P'"') +
                   (P"'" * Cs( (charescape + hexescape +
                     octescape + (any-P"'"))^0 ) * P"'")
  --local bool = C( W"true" + W"false" ) / { [ "true" ] = true, [ "false" ] = false }
  local boolStr = C( W"true" + W"false" )
  local integer = hex + oct + int
  local special_float = C( W"inf" + W"-inf" + W"nan" ) / { nan = nan, inf = inf, [ "-inf" ] = -inf }
  local float = C( sign^-1 * decimal * (P"." * digit^1)^-1 * (S"Ee" * sign^-1 * digit^1)^-1 ) / tonumber + special_float
  --local rawname = letter * (letter + digit)^0
  --local rel_ref = rawname * (P"." * rawname)^0
  --local abs_ref = P"." * rel_ref
  --local ref = C( P"."^-1 * rel_ref )
  --local oref = ((P"(" * _ * ref * _ * (P")"+E()) * C( abs_ref )^-1) / function( a, b ) return a .. (b or "") end) + ref
  local propertyValue = boolStr + integer + float + sliteral + ID
  local empty_statement = P";" * _


  START "tsfile"
  tsfile = _ * (V"object" + V"fct" + empty_statement)^0 * EOF()

  fct = (W"function" * _ *  ((ID * P"::")^0 * ID) * _ * P"(" * _ * (1 - S")")^0 * _ * P")" * _ * V"functionRecursion" * _ )
  object = (W"$ThisPrefab" * _ * P"=" * _)^0
           * C(W"new" + W"singleton" + W"datablock") * _ * (ID+E()) * _
               * P"("
                  * (P"'" + P'"')^0
                  * _ * V'objectName'^0 * _ * (P':' * _ * V'parentObject')^0 * _
                  * (P"'" + P'"')^0
               * P")"
               * _ * (P"{" + E()) * _ *
            (V'object' + V"property" + empty_statement)^0 * _ * (P"}" + E()) * _ * (P';') * _

  objectName = C(letter + digit + P'.' +  P'_' +  P'-')
  parentObject = V'objectName'

  className = C(letter + digit + P'.' +  P'_' +  P'-')
  functionName = C(letter + digit + P'.' +  P'_' +  P'-')

  functionRecursion = P"{" * (1 - S"{}")^0 * V"functionRecursion"^0 * (1 - S"{}")^0 *  P"}"

  property = ID * _ * V'propertyIndex'^0 * _ * (P"=" + E()) * _ * (propertyValue + E()) * _ * (P";" + E()) * _
  propertyIndex = P"[" * _ * C(decimal) / tonumber * _ * P"]"
end ) -- end of grammar definition


local function parse(s)
  return pcall(epnf.parsestring, pg, s)
  --local ok, ast = pcall(epnf.parsestring, pg, s)
  --if ok then
  --  return ast
  --end
  --print(ast)
  --return nil
end

M.parse = parse

return M
