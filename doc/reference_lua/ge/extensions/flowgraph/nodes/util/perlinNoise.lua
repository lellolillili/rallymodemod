-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local bit32 = bit

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Perlin noise'
C.tags = {'random'}
C.description = "Provides a coherant random number. If new with perlin noise, it's advised to google it, in order to understand the input parameters better."
C.category = 'provider'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'The input flow' },
  { dir = 'in', type = 'number', name = 'value', description = 'The input number used for the seed' },

  { dir = 'in', type = 'number', name = 'octaves', hidden = true, default = 6, hardcoded = true, description = 'The number of levels of detail the perlin noise will have' },
  { dir = 'in', type = 'number', name = 'amplitude', hidden = true, default = 128, hardcoded = true, description = 'Determines how much the output value will vary' },
  { dir = 'in', type = 'number', name = 'frequency', hidden = true, default = 4, hardcoded = true, description = 'Determines how much detail is added at each octave' },
  { dir = 'in', type = 'bool', name = 'normalize', hidden = true, default = false, hardcoded = true, description = 'Normalize the output or not' },
  { dir = 'in', type = 'bool', name = 'randomStartSeed', hidden = true, default = true, hardcoded = true, description = 'If false, you will have the same pattern over and over, since the input value will most likely be the same at every run' },

  { dir = 'out', type = 'flow', name = 'flow', description = 'The outflow' },
  { dir = 'out', type = 'number', name = 'value', description = 'The random number' },
}

C.p = {}

--[[Thanks to : https://gist.github.com/kymckay/25758d37f8e3872e1636d90ad41fe2ed--]]
local permutation = {151,160,137,91,90,15,
  131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
  190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
  88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
  77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
  102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
  135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
  5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
  223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
  129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
  251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
  49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
  138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
}

C.dot_product = {
    [0x0]=function(x,y,z) return  x + y end,
    [0x1]=function(x,y,z) return -x + y end,
    [0x2]=function(x,y,z) return  x - y end,
    [0x3]=function(x,y,z) return -x - y end,
    [0x4]=function(x,y,z) return  x + z end,
    [0x5]=function(x,y,z) return -x + z end,
    [0x6]=function(x,y,z) return  x - z end,
    [0x7]=function(x,y,z) return -x - z end,
    [0x8]=function(x,y,z) return  y + z end,
    [0x9]=function(x,y,z) return -y + z end,
    [0xA]=function(x,y,z) return  y - z end,
    [0xB]=function(x,y,z) return -y - z end,
    [0xC]=function(x,y,z) return  y + x end,
    [0xD]=function(x,y,z) return -y + z end,
    [0xE]=function(x,y,z) return  y - x end,
    [0xF]=function(x,y,z) return -y - z end
}

function C:init()
  self.graphData = {}
  self.randomStartSeed = 0
  self.data.debug = true
  self.data.graphDataCount = 1000
  self.scaleMax = 1
  self.scaleMin = 0
end

function C:drawCustomProperties()
  local reason = nil

  if im.Button("Smooth preset") then
    self:_setHardcodedDummyInputPin(self.pinInLocal.frequency, 0.15)
    self:_setHardcodedDummyInputPin(self.pinInLocal.amplitude, 64)
    self:_setHardcodedDummyInputPin(self.pinInLocal.octaves, 1)
    reason = "Changed perlin noise preset to Smooth"
  end
  if im.Button("Natural preset") then
    self:_setHardcodedDummyInputPin(self.pinInLocal.frequency, 0.5)
    self:_setHardcodedDummyInputPin(self.pinInLocal.amplitude, 128)
    self:_setHardcodedDummyInputPin(self.pinInLocal.octaves, 6)
    reason = "Changed perlin noise preset to Natural"
  end
  return reason
end

function C:drawMiddle(builder, style)
  if self.data.debug then
    builder:Middle()
    if #self.graphData > 0 then
      im.PlotMultiLines("", 1, {"val"}, {im.ImColorByRGB(255,255,255,255)}, {self.graphData}, self.data.graphDataCount-1, "", self.scaleMin, self.scaleMax, im.ImVec2(200,60))
    end
  end
end

function C:_executionStarted()
  self.graphData = {}

  if self.pinIn.normalize.value then
    self.scaleMax = 0.5
    self.scaleMin = -0.5
  else
    self.scaleMax = self.pinIn.amplitude.value / 2 + 5
    self.scaleMin = - (self.pinIn.amplitude.value / 2 + 5)
  end

  for i=0,255 do
    -- Convert to 0 based index table
    self.p[i] = permutation[i+1]
    -- Repeat the array to avoid buffer overflow in hash function
    self.p[i+256] = permutation[i+1]
  end

  if self.pinIn.randomStartSeed.value then
    self.randomStartSeed = math.random(0, 9999999)
  end
end


function C:work()
  if self.pinIn.flow.value then

  local output = self:OctavePerlin(self.randomStartSeed + self.pinIn.value.value, 0, 0, self.pinIn.octaves.value, self.pinIn.amplitude.value, self.pinIn.frequency.value)

  if self.data.debug then
    table.insert(self.graphData, output)
    if #self.graphData >= self.data.graphDataCount then
      table.remove(self.graphData, 1)
    end
  end

  self.pinOut.value.value = output
  self.pinOut.flow.value = true
  else
    self.pinOut.flow.value = false
  end
end

function C:OctavePerlin(x, y, z, octaves, amplitude, frequency)
  local total = 0
  local maxValue = 0

  for i=0, octaves do
    total = total + self:noise(x * frequency, y * frequency, z * frequency) * amplitude
    maxValue = maxValue + amplitude
    frequency = frequency * 2
    amplitude = amplitude / 2
  end
  if self.pinIn.normalize.value then
    return total / maxValue
  else
    return total
  end
end

function C:noise(x, y, z)
    y = y or 0
    z = z or 0

    -- Calculate the "unit cube" that the point asked will be located in
    local xi = bit32.band(math.floor(x),255)
    local yi = bit32.band(math.floor(y),255)
    local zi = bit32.band(math.floor(z),255)

    -- Next we calculate the location (from 0 to 1) in that cube
    x = x - math.floor(x)
    y = y - math.floor(y)
    z = z - math.floor(z)

    -- We also fade the location to smooth the result
    local u = self.fade(x)
    local v = self.fade(y)
    local w = self.fade(z)

    -- Hash all 8 unit cube coordinates surrounding input coordinate
    local p = self.p
    local A, AA, AB, AAA, ABA, AAB, ABB, B, BA, BB, BAA, BBA, BAB, BBB
    A   = p[xi  ] + yi
    AA  = p[A   ] + zi
    AB  = p[A+1 ] + zi
    AAA = p[ AA ]
    ABA = p[ AB ]
    AAB = p[ AA+1 ]
    ABB = p[ AB+1 ]

    B   = p[xi+1] + yi
    BA  = p[B   ] + zi
    BB  = p[B+1 ] + zi
    BAA = p[ BA ]
    BBA = p[ BB ]
    BAB = p[ BA+1 ]
    BBB = p[ BB+1 ]

    -- Take the weighted average between all 8 unit cube coordinates
    return self.lerp(w,
        self.lerp(v,
            self.lerp(u,
                self:grad(AAA,x,y,z),
                self:grad(BAA,x-1,y,z)
            ),
            self.lerp(u,
                self:grad(ABA,x,y-1,z),
                self:grad(BBA,x-1,y-1,z)
            )
        ),
        self.lerp(v,
            self.lerp(u,
                self:grad(AAB,x,y,z-1), self:grad(BAB,x-1,y,z-1)
            ),
            self.lerp(u,
                self:grad(ABB,x,y-1,z-1), self:grad(BBB,x-1,y-1,z-1)
            )
        )
    )
end

function C:grad(hash, x, y, z)
    return self.dot_product[bit32.band(hash,0xF)](x,y,z)
end

-- Fade function is used to smooth final output
function C.fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function C.lerp(t, a, b)
    return a + t * (b - a)
end


return _flowgraph_createNode(C)
