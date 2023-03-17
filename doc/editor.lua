local function setCall(n, new)
  local wId = getWaypointId(n)
  editor.setDynamicFieldValue(wId, "pacenote", new)
end
