-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}


local function getBaseMission()
  return {
    description = "Mission Description for newIdadssad",
    name = "newIdadssad",
    missionType = "busMode",
    retryBehaviour = "infiniteRetries",
    startCondition = {
      --TODO: Driving a Bus vehicle should be a requirement!
      },
    visibleCondition = {},
    startTrigger = {
      type = "coordinates",
      level = "gridmap",
      pos = nil,
      radius = 3
    },
    customAdditionalAttributes = {
      icon = "bus",
      labelKey = "Provided Bus",
      valueKey = ""
    },
    trafficAllowed = false,
  }
end

local function generate()
  local data = scenario_scenariosLoader.getLevels('bus')
  local missions = {}
  for _, level in ipairs(data) do
    -- read all busline files for the route and navhelper data.
    local busLineFiles = FS:findFiles('/levels/'.. level.levelName .. '/buslines/', '*.buslines.json', -1, true, false)
    local routeData = {}
    local hasData = false
    for _, file in pairs(busLineFiles) do
      local busLine = jsonReadFile(file)
      for _, route in pairs(busLine.routes) do
        -- we save the data per route. route key is unfortunately a composite key of id and variance :(
        routeData[route.routeID .. route.variance] = route
        hasData = true
      end
    end
    -- only proceed if any busroute is found in this level
    if hasData then
      for _, scenario in ipairs(level.scenarios) do
        local mission = getBaseMission()
        local id = string.lower(level.levelName)..'-'..scenario.busdriver.routeID.."-"..scenario.busdriver.variance.."-procedural"
        local routeId = scenario.busdriver.routeID .. scenario.busdriver.variance
        local reVariance = scenario.busdriver.variance == "a" and "b" or "a"
        --local reversedRouteId = scenario.busdriver.routeID .. reVariance
        local route = routeData[routeId]
        local rRoute = routeData[scenario.busdriver.routeID .. reVariance] or {}

        mission.id = id
        mission.name = scenario.name
        mission.description = string.format("Play the busmode on this route. There are %d stops to drive to. If you are not in a bus when starting this mission, you will be provided with a default bus.", #route.tasklist)
        mission.missionFolder = string.lower(level.levelName)..'-'..scenario.name
        mission.previewFile = type(scenario.previews) == 'table' and scenario.previews[1] or scenario.previews or scenario.preview
        mission.thumbnailFile = mission.previewFile

        mission.missionTypeData = {
          routeId = route.routeID,
          variance = route.variance,
          tasklist = route.tasklist,
          navhelp = route.navhelp,
          routeColor = route.routeColor,
          direction = route.direction,
          model = route.vehicle.model,
          config = route.vehicle.config,
          --New reversed route to be able to continue the mission.
          rtasklist = rRoute.tasklist,
          rnavhelp = rRoute.navhelp,
          rdirection = rRoute.direction
        }

        mission.careerSetup = {
          defaultStarKeys = {'justFinish','noAccident'},
          showInCareer = false,
          showInFreeroam = true,
          starsActive = {justFinish=true, noAccident=true},
          starRewards = {},
        }

        -- setting the start trigger to the bus spawn location.
        -- in the future, bus mode should be startable from any bus stop.
        mission.startTrigger.level = string.lower(level.levelName)
        mission.startTrigger.pos = vec3(route.spawnLocation.pos.x, route.spawnLocation.pos.y, route.spawnLocation.pos.z)
        local rot = route.spawnLocation.rotAngAxisF or route.spawnLocation.rot
        mission.startTrigger.rot = route.spawnLocation.rotAngAxisF and quat(AngAxisF(rot.x, rot.y, rot.z, (rot.w * 3.1459) / 180.0 ):toQuatF()) or quat(rot)
        -- disabled until we have the mission type
        table.insert(missions, mission)
      end
    end
  end
  return missions
end

M.generate = generate
return M