-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'career_career'}

local fileName = "recentUnlocks.json"
local recentUnlocks = {}
local idCounter =  0

local function getRecentUnlocks(limit)
  if not limit then return recentUnlocks end
  local ret = {}
  for i = 1, limit do
    table.insert(ret, recentUnlocks[i])
  end
  return ret
end

local function setUnlockEventRead(eventId, read)
  for _, e in ipairs(recentUnlocks) do
    if e.eventId == eventId then
      e.read = read
      return
    end
  end
end

local function addNewUnlockEvent(event)
  event = event or {}
  event.time = os.time()
  event.eventId = idCounter
  event.read = false
  idCounter = idCounter + 1
  table.insert(recentUnlocks,1, event)
  --log("I","","New Unlock Event: " ..dumps(event))
  guihooks.trigger("onNewUnlockEventCareer", event)
end

local function missionUnlocked(id)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not id then return end
  addNewUnlockEvent({
    type = "missionUnlocked",
    cardTypeLabel = "ui.career.poiCard.missionUnlocked",
    missionId = id,
    title = mission.name,
    text = mission.description,
    image = mission.previewFile,
    flavor = "info"
  })
end

local function spawnPointUnlocked(spawnPoint)
  addNewUnlockEvent({
    type = "spawnPointUnlocked",
    cardTypeLabel = "ui.career.poiCard.spawnPointUnlocked",
    name = spawnPoint.translationId,
    image = spawnPoint.previews[1],
    flavour = "info",
  })
end

local function genericInfoUnlocked(title, text, image, ratio, flavour)
  -- TODO: add name, description, image etc
  addNewUnlockEvent({
    type = "genericInfoUnlocked",
    cardTypeLabel = "ui.career.poiCard.generic",
    title = title,
    text = text,
    image = image,
    ratio = ratio or "16x9",
    flavour = flavour or "info"
  })
end

local function loadDataFromFile()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  local data = jsonReadFile(savePath .. "/career/"..fileName) or {}
  recentUnlocks = data.recentUnlocks or {}
  idCounter = #recentUnlocks
end

local function onCareerActive(active)
  loadDataFromFile()
  if not next(recentUnlocks) then
    genericInfoUnlocked("Welcome to a very early sneak-peek of BeamNG’s Career Mode!",
    [[
      <h3>Please note that this is a highly-volatile early-version of Career Mode. All saved progress will be lost in the coming update(s).</h3>
      <ul>
        <li>This is only a sneak-peek into the gameplay and its accompanying framework.</li>
        <li>Gameplay-rewards are arbitrary and serve only as placeholder values.</li>
      </ul>
    ]],
    '/ui/modules/introPopup/assets/career-preview.jpg',
    '21x9',
    'welcome'
  )
  genericInfoUnlocked("Career Rewards Overview",
  [[
    <h3>As you make your way through the included gameplay various types of rewards are collected.</h3>
      <p><b>Money:</b> Currently WIP.</p>
      <p><b>Branch XP:</b> Accumulated and used to progress the player through branch-specific tiers. Branch XP serves to allow the player keep track of their performance and preferred playstyle.</p>
      <p><b>BeamXP:</b> An overall gameplay-tracking and reward-servicing system. Regardless of your preferred playstyle, Career Mode rewards your play time. BeamXP accumulates as you progress through the game’s countless challenges.</p>
  ]],
  '/ui/modules/introPopup/assets/career-preview2.jpg',
  '21x9',
  'welcome'
  )
  genericInfoUnlocked("Career Branch Overview",
  [[
    <div class="flex-row">
      <div class="flex-column branch-column">
        <div class="ratio3x4">
          <div class="ratio-content motorsports"></div>
        </div>
        <h3>Motorsports</h3>
        <p class="italic-paragraph">Explore your competitive driving side!</p>
        <p>The passion of racing against the clock and opponents on the drag-strip, race track, city streets, or offroad is undeniably alluring. The Motorsports Branch tests your skills through various challenges.</p>
      </div>
      <div class="flex-column branch-column">
        <div class="ratio3x4">
          <div class="ratio-content labourer"></div>
        </div>
        <h3>Labourer</h3>
        <p class="italic-paragraph">Not everything is about speed!</p>
        <p>Whether you’re interested in vehicle recovery, delivering heavy machinery, cargo, or people; the Labourer Branch offers a wide variety of fulfilling-yet-daunting task-oriented challenges to overcome.</p>
      </div>
      <div class="flex-column branch-column">
        <div class="ratio3x4">
          <div class="ratio-content specialized"></div>
        </div>
        <h3>Specialized</h3>
        <p class="italic-paragraph">Untrained professionals need not apply!</p>
        <p>From action-packed police operations and emergency rescues to highly specialized and exclusive deliveries and escorts, the Specialized Branch offers players a chance to step into the big leagues and thrive.</p>
      </div>
      <div class="flex-column branch-column">
        <div class="ratio3x4">
          <div class="ratio-content adventurer"></div>
        </div>
        <h3>Adventurer</h3>
        <p class="italic-paragraph">Seeking a little more adventure?</p>
        <p>From daring stunt jumps, to speed traps and other highly-reckless activities, the Adventurer Branch offers that menacing intensity, drama, and innate danger that keeps players coming back for more.</p>
      </div>
    </div>
  ]],
    nil,
    '3x4',
    'welcome'
  )

  genericInfoUnlocked("Career First Steps",
  [[
    <h3>Unlock new Content</h3>
    <ol>
     <li>Use the map to select and inspect missions.</li>
     <li>You must achieve at least one star in a mission for it to be considered a pass.</li>
     <li>To achieve mission-specific bonus challenges, it may be required to customize its settings.</li>
     <li>Passing a mission will unlock the ability to customize its settings.</li>
     <li>Depending on the type of mission, customization may provide the ability to; play the mission with your own vehicle, set a custom number of laps, change traffic settings, and more.</li>
     </ol>
  ]],
  '/ui/modules/introPopup/assets/to-do.jpg',
  '21x9',
  'welcome'
  )
  genericInfoUnlocked("Explore West Coast USA",
  [[
     <h3>Discover and play Missions</h3>
     <p>Check out the map to see all of the currently available missions, then set a route to your desired destination. Feel free to explore and discover missions as you come across them.</p>
     <p>Be sure to select "Open Garage" to learn about vehicle customization. Have fun out there!</p>
  ]],
  '/ui/modules/introPopup/assets/explore.jpg',
  '21x9',
  'welcome'
  )
  genericInfoUnlocked("Career Garage Overview",
  [[
    <h4>Customize your Vehicle</h4>
    <p>Using the garage, you can upgrade and personalize your vehicle. It's free to do so at this stage of development; so take advantage and create your dream collection of custom vehicles! Don't forget to save your vehicle once you've finished.</p>
    <p>You can enter the garage when parked between the yellow lines inside of the garage; larger vehicles can enter garage mode from the concrete pad located just outside of the garage.</P>
  ]],
  '/ui/modules/introPopup/assets/garageIntro.jpg',
  '21x9',
  'garage'
  )
  end

end

-- this should only be loaded when the career is active
local function onSaveCurrentSaveSlot(currentSavePath)
  jsonWriteFile(currentSavePath .. "/career/"..fileName,
    {
      recentUnlocks = recentUnlocks
    }, true)
end



M.onExtensionLoaded = onExtensionLoaded
M.onCareerActive = onCareerActive
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot

M.getRecentUnlocks = getRecentUnlocks
M.setUnlockEventRead = setUnlockEventRead
M.addNewUnlockEvent = addNewUnlockEvent

M.missionUnlocked = missionUnlocked
M.spawnPointUnlocked = spawnPointUnlocked
M.genericInfoUnlocked = genericInfoUnlocked


return M