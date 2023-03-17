-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- functional programming proof of concept created by BeamNG.
-- see test function below for example

-------------------------------------------------------------------------------
local F = {}

local function getVarByNameInScope(components, scope)
  --dump('getVarByNameInScope', components, scope)
  if #components == 1 then
    return scope[components[1]]
  else
    return getVarByNameInScope({select(2, unpack(components))}, scope[components[1]])
  end
end

function locals()
    local variables = {}
    local idx = 1
    while true do
      local ln, lv = debug.getlocal(2, idx)
      if ln ~= nil then
        variables[ln] = lv
      else
        break
      end
      idx = 1 + idx
    end
    return variables
  end

function getVarByName(name, scope)
  if scope == nil then scope = _G end
  return getVarByNameInScope({name:match("([^.]*).(.*)")}, scope)
end

local Smooth = {}
Smooth.__index = Smooth
F.smooth = function(rate)
    local data = {}
    setmetatable(data, Smooth)
    data.rate = rate or 1
    data.initialVal = true
    return data
end

function Smooth:get(dt, sample)
    if self.initialVal then
        self.state = sample
        self.initialVal = false
    end
    if sample < self.state then
        self.state = math.max(self.state - dt * self.rate, sample)
    else
        self.state = math.min(self.state + dt * self.rate, sample)
    end
    return self.state
end

local Interval = {}
Interval.__index = Interval
F.interval = function(offsetTime, timeOn, timeOff)
    local data = {}
    setmetatable(data, Interval)
    data.offTime = timeOff or 0.1
    data.onTime = timeOn or 0.1
    data.offsetTime = offsetTime or 0
    data.timer = 0
    data.state = false
    data.initialVal = true
    return data
end

function Interval:get(dt, ...)
    --print('dt: ' .. tostring(dt) .. '/ ' .. tostring(self.timer) .. ' ### ' .. tostring(self.state) )
    self.timer = self.timer + dt
    if self.state and self.timer > self.onTime then
        self.state = not self.state
        self.timer = 0
    elseif not self.state and self.timer > self.offTime then
        self.state = not self.state
        self.timer = 0
    end
    local args = select(1, {...})
    local res = self.state and args[1] -- take first arg only, just pass the others
    if not res then
        local res = {}
        for i = 1, #args do
            table.insert(res, 0)
        end
        return {dt, unpack(res)}
    else
        return {dt, ...}
    end
end

F.scale = function(scaleVal)
    return {
        get = function (self, dt, val) return val * scaleVal end
    }
end

F.digitize = function(threshold)
    threshold = threshold or 0.5
    return {
        get = function (self, dt, val)
            if val > threshold then return 1 else return 0 end
        end
    }
end

F.floor = function()
    return {
        get = function (self, dt, val) return math.floor(val) end
    }
end

F.clamp = function(minval, maxval)
    minval = minval or 0
    maxval = maxval or 1
    return {
        get = function (self, dt, val) return math.max(math.min(val, maxval), minval) end
    }
end

--[[
-- experimental things
F.plus = function(val)
    return {
        get = function (self, a, b) return a + b + val end
    }
end
F.pushConstant = function(var)
    return {
        get = function (self, ...)  return ..., var end
    }
end
]]

F.examine = function(str, commonArgumentsCount)
    if commonArgumentsCount == nil then commonArgumentsCount = 0 end
    return {
        get = function (self, ...)
            log('D', 'filterchain.examine', str .. ' ' .. dumps(...))
            return select(commonArgumentsCount + 1, ...)
        end
    }
end


local Startdelay = {}
Startdelay.__index = Startdelay
F.startdelay = function(startdelay)
    local data = {}
    setmetatable(data, Startdelay)
    data.startdelay = startdelay or 0
    data.hightime = 0
    data.prevsample = 0
    return data
end

function Startdelay:get(dt, sample)
    if sample <= self.prevsample then
        self.hightime = 0
        self.prevsample = sample
        return sample
    else
        self.hightime = self.hightime + dt
        if self.hightime < self.startdelay then
            return self.prevsample
        else
            return sample
        end
    end
end
-------------------------------------------------------------------------------
--local commonArguments = {'dt'} -- remove this if you want a more generic version of the filter Chain

local function newFilterchain(filterlist, debug, commonFilterArguments, codeArgs)
    filterlist = filterlist or {}
    if debug == nil then debug = false end
    if commonFilterArguments == nil then
        commonFilterArguments = {'dt'}
    end
    local data = { f = {} }

    -- insert debug if wanted
    if debug then
        local newList = {}
        table.insert(newList, 'examine("** starting input:")')
        for i, v in ipairs(filterlist) do
            table.insert(newList, 'examine(" ** step ' .. i .. ' - input: ",'..#commonFilterArguments..')')
            table.insert(newList, v)
            table.insert(newList, 'examine(" ** step ' .. i .. ' - output:",'..#commonFilterArguments..')')
        end
        table.insert(newList, 'examine("** final output:")')
        filterlist = newList
    end

    for i, v in ipairs(filterlist) do
        table.insert(data.f, load("return " .. v, nil, "t", F)())
    end

    local commonFilterArgumentsStr = table.concat(commonFilterArguments, ',')
    if #commonFilterArguments > 0 then commonFilterArgumentsStr = commonFilterArgumentsStr .. ',' end

    local s = ''
    for i = #filterlist, 1, -1 do
        s = s .. "f["..i.."]:get(" .. commonFilterArgumentsStr
    end

    local function getGenerator(arg)
        return 'return function(self,' .. commonFilterArgumentsStr ..'...) return ' .. s .. arg .. string.rep(')',  #filterlist) .. ' end'
    end

    if not codeArgs then
        local s = getGenerator('...')
        print(s)
        data.update = load(s, nil, "t", data)()
    else
        local s = getGenerator(codeArgs)
        print(s)
        data.updateCode = load(s, nil, "t", data)()
    end
    return data
end


local function test()

    --dump(  (function(a,b,c) return a + b + c end) ( unpack({(function (a, b, c) return a + b + c, 1, 1; end)(1,2,3)})  ))
--[[
    local f = newFilterchain({
        'delay(100)',
        'delay(100)',
    })
    dump(f:update(0.5, 1))
    dump(f:update(0.5, 2))
    dump(f:update(0.5, 3))
    dump(f:update(0.5, 4))
    dump(f:update(0.5, 5))
]]

    --local mv = {}
    --mv.foo = 1337
    --dump(getVarByName('mv.foo', locals()))

    --dump(locals())

    local led1 = newFilterchain({'interval(0.1, 0.1)'}, true)

    local dt = 0.02
    local timer = 0
    for i = 1, 30 do
        timer = timer + dt
        dump(led1:update(dt, 1))
        --local out = led1:update(dt, 1, 2, 3)
        --print('### ' .. timer .. ' = ' .. dumps(unpack({out})))
    end

end

M.test = test


return M
