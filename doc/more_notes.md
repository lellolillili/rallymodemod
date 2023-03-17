### Random notes for possible developers

All distances are systematically underestimated because the track is defined by connecting waypoints. The more waypoints you put down, the more accurate the measurement becomes.

# Documentation: a mix of things about lua and modding I've learned so far.

## Searching the code and inspecting data structures

Copy-paste the entirety of the `lua` folder into somewhere in your project. Use
it to search for how functions are used etc.

Another very useful command:
```
dumpToFile("file", command)
```
you can use it with an extension to dump all the relevant stuff.

There's a bunch of debug utils in utils.lua. Use those.


## General utils

Vector operations are in mathlib.lua

## Extensions

Prints currently loaded extensions:

```
extensions.printExtensions()
```

You can run run an extension on top of a Time Trial (and possibly scenarios) by
adding an appropriately named lua file in the levels folder. You can also just
run whatever code.

## Scenario-related data structures

The following has a lot of useful information.

```
dump(scenario_waypoints.state.branchGraph.mainPath)>
```

and its n-th entry looks like this

```
dump(scenario_waypoints.state.branchGraph.mainPath[N_wp])
{
  branch = "mainPath",
  cpName = "quickrace_wp2",
  index = 2,
  successors = { {
      branch = "mainPath",
      cpName = "quickrace_wp3",
      index = 3,
      insertBranch = false
    } }
}
```

See my dumps for other interesting objects that the game uses.

## Objects

The following returns an object with a crapload of methods. I was checking on a
waypoint, but I think they're the same for any object.


```
scenetree.findObject("quickrace_wp") >
```

For some reason, some of the methods have a mysterious second argument (a
number) that I don't know what it is. I wasted hours on this. For example: I
use


```
return wObj:getDynDataFieldbyName("pacenote", 0)
```

Note that the ':'. `o:method(args)` is the same as `o.method(self, args)`.

```
o:getFieldList()
o:getFields()  (which is apparently the same as the above?)
clone(), delete(), dump(), getPosition(), getRotation()
getClassName() - returns which kind of object it is (e.g., BeamNGWaypoint)
```

## Modifying objects.

Note: I think the api only works when the editor is open or the api extension
is loaded somehow.

Let's try to use `extensions/editor/api/object.lua` to modify waypoints
permanently. Most functions in that api need the Id. You can get it with

```
wpId = wp:getId()
```

for example, we can use the api to give dynamic fields of our waypoint:

```
dump(editor_main.getDynamicFields(wpId))
```

The following 2 functions work, at least after F11 for the first time, and it
actually writes to the prefab if you save the level from the editor.


```
local function setCall(n, newCall)
  local wId = getWaypointId(n)
  editor.setDynamicFieldValue(wId, "pacenote", newCall)
end

local function getCall(n)
  local wName = getWaypointName(n)
  local wObj = getWaypointObj(wName)
  local call = wObj:getDynDataFieldbyName("pacenote", 0)
  return call
end
```
