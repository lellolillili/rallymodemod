-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamTableSchema = require('jbeam/tableSchema')

local function _addNode(ctx, node)
  table.insert(ctx.ast.nodes, node)
end

-- allows to skip more of the same
local function _consume_same(ctx, chr)
  ctx.pos = ctx.pos + 1
  local startPos = ctx.pos
  local c
  while true do
    c = ctx.str:sub(ctx.pos, ctx.pos)
    if c ~= chr or not c or c == '' then
      break
    end
    ctx.pos = ctx.pos + 1
  end
  return ctx.pos - startPos + 1
end

local function _parse_string(ctx, delimiter)
  ctx.pos = ctx.pos + 1
  local res = ''
  local c
  while true do
    c = ctx.str:sub(ctx.pos, ctx.pos)
    ctx.pos = ctx.pos + 1
    if c == delimiter or not c or c == '' then
      break
    end
    res = res .. c
  end
  return res
end

local function _parse_number(ctx, delimiter)
  local num_str = ctx.str:match('^+?-?%d+%.?%d*[eE]?[+-]?%d*', ctx.pos)
  local num = tonumber(num_str)
  if not num then
    --dump{num_str, num}
    log('E', '', 'failed to parse number at position ' .. tostring(ctx.pos))
    return
  end
  local num_len = #num_str
  ctx.pos = ctx.pos + num_len
  local dotPos = num_str:find('%.')
  local precision = 0
  if dotPos then
    precision = math.max(0, num_len - dotPos)
  end
  local node = {
    'number',
    num,
    precision
  }
  if num_str:sub(1, 1) == '+' then
    node.prefixPlus = true
  end
  node.addPostfixDot = num_str:sub(num_len, num_len) == '.'
  _addNode(ctx, node)
end

local function _parse_comment(ctx)
  ctx.pos = ctx.pos + 2
  local res = ''
  local c
  local newline
  while true do
    c = ctx.str:sub(ctx.pos, ctx.pos)
    ctx.pos = ctx.pos + 1
    if not c or c == '' then
      break
    end
    local nextChar = ctx.str:sub(ctx.pos, ctx.pos)
    if c == '\n' then
      --res = res .. c
      newline = 'newline'
      break
    elseif c == '\r' and nextChar == '\n' then
      --res = res .. c .. nextChar
      ctx.pos = ctx.pos + 1
      newline = 'newline_windows'
      break
    end
    res = res .. c
  end
  _addNode(ctx, {'comment', res})
  if newline then
    _addNode(ctx, {newline})
  end
end

local function _parse_comment_multiline(ctx)
  ctx.pos = ctx.pos + 2
  local res = ''
  local c
  while true do
    c = ctx.str:sub(ctx.pos, ctx.pos)
    ctx.pos = ctx.pos + 1
    if not c or c == '' or ctx.pos > #ctx.str then
      break
    end
    if c == '*' and ctx.str:sub(ctx.pos, ctx.pos) == '/' then
      ctx.pos = ctx.pos + 1
      break
    end
    res = res .. c
  end
  _addNode(ctx, {'comment_multiline', res})
end

local function _calcHierarchy(ctx)
  local astNodes = ctx.ast.nodes
  ctx.transient.hierarchy = {}
  local hierarchy = ctx.transient.hierarchy
  local containerStack = {}

  for i, node in ipairs(astNodes) do
    local parentNodeIdx = containerStack[#containerStack]
    if parentNodeIdx then
      if not hierarchy[parentNodeIdx] then hierarchy[parentNodeIdx] = {} end
      table.insert(hierarchy[parentNodeIdx], i)
    else
      if node[1] ~= 'space' and node[1] ~= 'newline_windows' and node[1] ~= 'newline' and node[1] ~= 'array_delimiter' then
        if ctx.transient.root then
          log('E', '', 'Multiple root nodes not allowed. Type: ' .. tostring(node[1]))
          return false
        end
        ctx.transient.root = i
      end
    end

    if node[1] == 'object_begin' or node[1] == 'list_begin' then
      table.insert(containerStack, i)
    elseif node[1] == 'object_end' or node[1] == 'list_end' then
      table.remove(containerStack, #containerStack)
    end
  end
  return true
end

local function _convertToLuaNative(ctx, nodeIdx, addAstId)
  local node = ctx.ast.nodes[nodeIdx]
  local nodeHierarchy = ctx.transient.hierarchy[nodeIdx]
  local nodeType = node[1]

  if nodeType == 'bool' then
    return node[2]
  elseif nodeType == 'string' or nodeType == 'string_single' then
    return node[2]
  elseif nodeType == 'number' then
    return node[2]
  elseif nodeType == 'list_begin' then
    local res = {}
    for _, childNodeIdx in ipairs(nodeHierarchy) do
      local val = _convertToLuaNative(ctx, childNodeIdx, addAstId)
      if val ~= nil then
        table.insert(res, val)
      end
    end
    if addAstId then
      res.__astNodeIdx = nodeIdx
    end
    return res
  elseif nodeType == 'object_begin' then
    local res = {}
    local mode = 0
    local storedKey
    for _, childNodeIdx in ipairs(nodeHierarchy) do
      local childNode = ctx.ast.nodes[childNodeIdx]
      local childNodeType = childNode[1]

      -- TODO: we could also look for key_delimiter

      if mode == 0 then -- looking for key
        local keyVal = _convertToLuaNative(ctx, childNodeIdx, addAstId)
        if type(keyVal) == 'string' then
          storedKey = keyVal
          mode = 1
        end
      elseif mode == 1 then -- looking for the value
        local val = _convertToLuaNative(ctx, childNodeIdx, addAstId)
        if val ~= nil then
          res[storedKey] = val
          mode = 0 -- back to key
        end
      end
    end
    if addAstId then
      res.__astNodeIdx = nodeIdx
    end
    return res
  end
end

local function _convertTableSchema(fileRoot)
  for _, partRoot in pairs(fileRoot) do
    if type(partRoot) == 'table' then
      jbeamTableSchema.process(partRoot, true)
      partRoot.__schemaProcessed = true
    end
  end
end

-- creates vec3 and alike
local function _cleanupData(node)
  if type(node) == 'table' then
    if type(node.posX) == 'number' and type(node.posY) == 'number' and type(node.posZ) == 'number' then
      node.pos = vec3(node.posX, node.posY, node.posZ)
      node.posX = nil
      node.posY = nil
      node.posZ = nil
    end
    for k, v in pairs(node) do
      _cleanupData(v)
    end
  end
end

local function _parse(ctx)
  local astNodes = ctx.ast.nodes
  while true do
    if ctx.pos > #ctx.str then
      return
    end

    local chr = ctx.str:sub(ctx.pos, ctx.pos)
    local posSaved = ctx.pos

    --dump{ctx.pos, chr}

    if chr == '{' then
      _addNode(ctx, {'object_begin'})
      ctx.pos = ctx.pos + 1
    elseif chr == '}' then
      _addNode(ctx, {'object_end'})
      ctx.pos = ctx.pos + 1
    elseif chr == '[' then
      _addNode(ctx, {'list_begin'})
      ctx.pos = ctx.pos + 1
    elseif chr == ']' then
      _addNode(ctx, {'list_end'})
      ctx.pos = ctx.pos + 1
    elseif chr == ',' then
      _addNode(ctx, {'array_delimiter'})
      ctx.pos = ctx.pos + 1
    elseif chr == 't' and ctx.str:sub(ctx.pos, ctx.pos + 3) == 'true' then
      _addNode(ctx, {'bool', true})
      ctx.pos = ctx.pos + 4
    elseif chr == 'f' and ctx.str:sub(ctx.pos, ctx.pos + 4) == 'false' then
      _addNode(ctx, {'bool', false})
      ctx.pos = ctx.pos + 5
    elseif chr == '\n' then
      _addNode(ctx, {'newline'})
      ctx.pos = ctx.pos + 1
    elseif chr == '\r' and ctx.str:sub(ctx.pos + 1, ctx.pos + 1) == '\n' then
      _addNode(ctx, {'newline_windows'})
      ctx.pos = ctx.pos + 2
    elseif chr == ':' then
      _addNode(ctx, {'key_delimiter'})
      ctx.pos = ctx.pos + 1
    elseif chr == '/' and ctx.str:sub(ctx.pos + 1, ctx.pos + 1) == '/' then
      _parse_comment(ctx)
    elseif chr == '/' and ctx.str:sub(ctx.pos + 1, ctx.pos + 1) == '*' then
      _parse_comment_multiline(ctx)
    elseif chr == ' ' then
      _addNode(ctx, {'space', _consume_same(ctx, ' ')})
    elseif chr == '\t' then
      _addNode(ctx, {'tab', _consume_same(ctx, '\t')})
    elseif chr == '"' then
      _addNode(ctx, {'string', _parse_string(ctx, '"')})
    elseif chr == '\'' then
      _addNode(ctx, {'string_single', _parse_string(ctx, '\'')})
    elseif chr == '-' or chr == '+' or chr:match('%d') then
      _parse_number(ctx)
    end

    -- nothing consumed? use fallback
    if posSaved == ctx.pos then
      log('E', '', 'using fallback literal: ' .. chr .. ' at position ' .. tostring(ctx.pos))
      _addNode(ctx, {'literal', chr})
      ctx.pos = ctx.pos + 1
    end
  end
end

local function stringifyNodes(nodes)
  local res = ''
  local nodeType
  for i, node in ipairs(nodes) do
    nodeType = node[1]
    --dump{i, node}
    if nodeType == 'object_begin' then
      res = res .. '{'
    elseif nodeType == 'object_end' then
      res = res .. '}'
    elseif nodeType == 'list_begin' then
      res = res .. '['
    elseif nodeType == 'list_end' then
      res = res .. ']'
    elseif nodeType == 'array_delimiter' then
      res = res .. ','
    elseif nodeType == 'newline' then
      res = res .. '\n'
    elseif nodeType == 'newline_windows' then
      res = res .. '\r\n'
    elseif nodeType == 'bool' then
      res = res .. tostring(node[2])
    elseif nodeType == 'key_delimiter' then
      res = res .. ':'
    elseif nodeType == 'comment' then
      res = res .. '//' .. node[2]
    elseif nodeType == 'comment_multiline' then
      res = res .. '/*' .. node[2] .. '*/'
    elseif nodeType == 'space' then
      res = res .. string.rep(' ', node[2])
    elseif nodeType == 'tab' then
      res = res .. string.rep('\t', node[2])
    elseif nodeType == 'string' then
      res = res .. '"' .. node[2] .. '"'
    elseif nodeType == 'string_single' then
      res = res .. '"' .. node[2] .. '"'
    elseif nodeType == 'number' then
      local num = node[2]
      local precision = node[3]
      if node.prefixPlus then
        res = res .. '+'
      end
      res = res .. string.format('%' .. precision .. '.' .. precision .. 'f', num)
      if node.addPostfixDot then
        res = res .. '.'
      end
    elseif nodeType == 'literal' then
      res = res .. node[2]
    end
  end
  return res
end

local function parse(str, addAstId)
  local ctx = {
    ast = {
      nodes = {},
    },
    transient = {
      hierarchy = {},
    },
    str = str,
    pos = 1
  }
  _parse(ctx)
  if not _calcHierarchy(ctx) then return end

  -- we parsed the json primitives
  ctx.transient.luaDataRaw = _convertToLuaNative(ctx, ctx.transient.root, addAstId)

  -- now we need to parse the table primitives
  ctx.transient.luaData = deepcopy(ctx.transient.luaDataRaw)
  _convertTableSchema(ctx.transient.luaData)

  _cleanupData(ctx.transient.luaData)

  ctx.str = nil
  ctx.pos = nil
  return ctx
end

local function stringify(ast)
  return stringifyNodes(ast.nodes)
end

local function _lineSplit(str)
  local lines = {}
  for line in str:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  return lines
end

local function findDifferences(filename, strA, strB)
  local linesA = _lineSplit(strA)
  local linesB = _lineSplit(strB)
  for i, line in ipairs(linesA) do
    --dump{i, linesA[i], linesB[i]}
    if line ~= linesB[i] then
      log('E', 'Difference found: ' .. tostring(filename) .. ' - line ' .. tostring(i) .. '\nORG: '.. tostring(line) .. '\nRES: ' .. tostring(linesB[i]))
      --return
    end
  end
end

local function testFile(filename, writeAST, addASTId)
  local str = readFile(filename)
  if not str then
    log('E', '', 'Unable to read file: ' .. tostring(filename))
    return
  end
  local res = parse(str, addASTId)
  if not res then return end

  if res.transient.luaDataRaw then
    local jsonFast = require('json')
    local dataFast = json.decode(str)

    local dumpAst = dumps(res.transient.luaDataRaw)
    local dumpFast = dumps(dataFast)

    --dump{'AST: ', res.transient.luaDataRaw, dumpAst}
    --dump{'FAST: ', dataFast, dumpFast}

    if dumpAst ~= dumpFast then
      log('E', '', 'parsers have differet results')
      writeFile(filename .. '_dump_ast.txt', dumpAst)
      writeFile(filename .. '_dump_fast.txt', dumpFast)
      jsonWriteFile(filename .. '.ast.json', res, true)
      return
    end
  end
  --dumpz(res, 2)

  for _, node in ipairs(res.ast.nodes) do
    if node[1] == 'literal' then
      log('E', '', 'AST using literal fallback')
      return
    end
  end

  local str2 = stringify(res.ast)

  if str ~= str2 then
    findDifferences(filename, str, str2)
    writeFile(filename .. '_', str2)
    jsonWriteFile(filename .. '.ast.json', res, true)
    return false
  end

  if writeAST then
    jsonWriteFile(filename .. '.ast.json', res, true)
    print('wrote AST: ' .. tostring(filename .. '.ast.json'))
  end
  --if FS:fileExists(filename .. '.ast.json') then
  --  FS:removeFile(filename .. '.ast.json')
  --end
  --if FS:fileExists(filename .. '_') then
  --  FS:removeFile(filename .. '_')
  --end
  return true
end

local function testFiles(writeAST, reportOK)
  local filenames = FS:findFiles('/', '*.jbeam', -1, false, false)
  local fileCount = #filenames
  for i, filename in ipairs(filenames) do
    if not testFile(filename, writeAST) then
      log('E', '', string.format('File %04d/%04d ERROR: %s', i, fileCount, tostring(filename)))
      --return
    else
      if reportOK then
        log('I', '', string.format('File %04d/%04d OK: %s', i, fileCount, tostring(filename)))
      end
    end
  end
  print('Done! :)')
end

M.testFiles = testFiles
M.testFile = testFile
M.stringify = stringify
M.stringifyNodes = stringifyNodes
M.parse = parse

return M