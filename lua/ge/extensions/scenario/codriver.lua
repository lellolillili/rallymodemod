-- You can use up to 20 alternative samples
local altSuffixes = {}
for i = 1, 20 do altSuffixes[i] = '_' .. tostring(i) end

local function buildCodriver(f)
  local dir = f
  if (not fileExists(dir .. "/codriver.ini")) then
    log("E", logTag, "Codriver file not found. Expecting \"" .. dir .. "/codriver.ini\".")
    return
  end
  local d = {}
  local f = io.open(dir .. "/codriver.ini", "r")
  for line in f:lines() do
    if string.len(line) > 0 then
      local firstChar = string.sub(line, 1, 1)
      if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
        if line:find("slowCorners=") then
          local sc = line:match("slowCorners=(.*)$")
          rcfg.slowCorners = fromCSV(sc)
        elseif line:find("LR") then
          local cstring
          local sample
          cstring, sample = line:match("^(%d*%u)%s%-%s(.*)$")
          corners["L" .. cstring] = sample:gsub("LR", "left")
          corners["R" .. cstring] = sample:gsub("LR", "right")
        else
          local key
          local sub
          if line:find("%>%>%>") then
            key, sub = line:match("^(.*)%>%>%>(.*)$")
            key = trim(key)
            sub = trim(sub)
          else
            key = trim(line:match("^(.+)$"))
          end
          d[key] = {}
          local mainSample = dir ..
            '/samples/' .. (sub or key) .. '.ogg'
          if fileExists(mainSample) then
            d[key]["samples"] = {}
            table.insert(d[key]["samples"], mainSample)
            for _, v in ipairs(altSuffixes) do
              local altSample = dir ..
                '/samples/alts/' .. (sub or key) .. v .. '.ogg'
              -- Dont search for the i+1-th and following
              -- alternative samples if you can't find the i-th
              -- sample. This avoids a lot of useless, very
              -- slow, file searches.  The filenames must not
              -- skip any numbers though.
              if not fileExists(altSample) then break end
              table.insert(d[key]["samples"], altSample)
            end
          end

         local pf = symbolsDir .. (sub or key) .. '.svg'
          if fileExists(pf) then
            d[key]["pics"] = {}
            table.insert(d[key]["pics"], pf)
          end
        end
      end
    end
  end
  f:close()

  local fs = io.open(dir .. "/symbols.ini", "r")
  for line in fs:lines() do
    if string.len(line) > 0 then
      local firstChar = string.sub(line, 1, 1)
      if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
        if line:find("%>%>%>") then
          local key
          local sub = nil
          key, sub = line:match("^(.*)%>%>%>(.*)$")
          key = trim(key)
          sub = fromCSV(sub)
          if d[key] then
            d[key].pics = {}
            for _, v in ipairs(sub) do
              local pf = symbolsDir .. trim(v) .. '.svg'
              if fileExists(pf) then
                table.insert(d[key].pics, pf)
              else
                log("W", logTag, pf .. " - Symbol substitution was specified,\
                but symbol file \"" .. pf .. "\" was not found. You might be missing a picture.")
              end
            end
          else
            log("W", logTag, "Symbol substitution was specified,\
            but key \"" .. key .. "\" was not found in the codriver. You might be missing the audio sample.")
          end
        end
      end
    end
  end
  fs:close()

  local dists = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130,
    140, 150, 160, 170, 180, 190, 200, 250, 300, 350, 400, 450, 500, 550,
    600, 650, 700, 750, 800, 850, 900, 1000, 1500, 2000 }
  for _, v in ipairs(dists) do
    if d[tostring(v)] then
      table.insert(allowedDists, v)
    end
  end

  d["_"] = nil

  return d
end
