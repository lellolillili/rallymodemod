# Rally mode - experimental

## Dowload

No need to clone the repo. Download a zip release instead.

If you're interested in working on the code, then go ahead and clone the repo. I'm very happy to collaborate.

## Install

Put the zip file in your mods folder. You do no need to unpack if you just want to play and edit basic settings (a the settings file, *rallyconfig.ini* will be created in *beamng_local/settings/*).

## Go Rallying

The rallies are under Time Trials menu. You can only start a rally from the Time Trials menu. 
Start the race. After the countdown, you will be greeted by a welcome message. Read it and follow the instructions.
You need to load the rally UI in order to see the pacenote symbols and the pause menu. 
Press 'SHIFT+CTRL+U', add apps, choose the Rally Mode UI app. Keep it nice and big and centered.

Restart once (press 'R') to disable the waypoint sounds. The custom waypoint module will be loaded, and the sounds won't play anymore. 

Anytime after the countdown starts, you can pause physics ('J') to open the rally menu. The menu is self explanatory.  

Don't forget to hit "save" to save the options you modify.

## Co-driver volume
You will see an option to adjust the co-driver volume. I actually have no idea what the hell is the correlation between the number you put in there, and actual volume of the co-driver voice. I only know that 0 is mute, small numbers are low volume, and large numbers are high volume. Please let me know if you figure out a reasonable range.

## Time trials
You can see the length of a rally in the thumbnail. Shakedowns are short stages, usually sections of the larger stages. Special stages are traditional length stages (5 to 15 km, for now).

## Configuration

### Advanced options

Open local_BeamNG_folder/setting/rallyconfig.ini (it is created after you use the "save" button in the menu for the first time). You can edit some of the options in this file for fine-tuning your co-driver. Not evey single option in this file can be changed from the pause menu.

### Change co-driver

Open setting/rallyconfig.ini. In codriverDir, you can use any of the codrivers you find

mods/unpacked/art/codrivers

For the moment, we have 

* Stu - text to speech
* Alex Gelsomino - sampled from real rally footage

## Edit pacenotes

When rallying, enter the pause menu ('J'), and check the pacenote-file name. You can create the pacenote file ("filename.pnt") in the correct directory, and start editing the pacenotes.

you have to have these files (note smallIslandRally_forward.pnt)
small_island
 ├── quickrace
 │   ├── smallIslandRally_forward.pnt           < custom pacenote overrides
 │   ├── smallIslandRally_forward.prefab        < waypoints and default pacenote
 │   ├── smallIslandRally.jpg
 │   ├── smallIslandRally.json                  < race config
 │   └── smallIslandRally.prefab                < stage clutter
 └── smallIslandRally.lua                       < tells BeamNG to start the mod

Pausing Physics will show pacenote information. Use that to edit the pacenotes.

If you want to change pacenote 1 to something that Stu will read "caution left 3 minus", add the following line to the pnt file

1 - caution L3M;

### Corner codes:

The corner codes for each co-driver are in pacenotedirector/art/codrivers/CODRIVER/codriver.ini

For the co-driver Stu, these are the corner codes

(L/R)0M - acute LR
(L/R)0E - hairpin LR
(L/R)0P - open hairpin LR

(L/R)1M - 1 LR minus
(L/R)1E - 1 LR
(L/R)1P - 1 LR plus

(L/R)2M - 2 LR minus
(L/R)2E - 2 LR
(L/R)2P - 2 LR plus

(L/R)3M - 3 LR minus
(L/R)3E - 3 LR
(L/R)3P - 3 LR plus

(L/R)4M - 4 LR minus
(L/R)4E - 4 LR
(L/R)4P - 4 LR plus

(L/R)5M - 5 LR minus
(L/R)5E - 5 LR
(L/R)5P - 5 LR plus

(L/R)6M - 6 LR minus
(L/R)6E - 6 LR
(L/R)6P - flat LR

You don't have to use corner codes, but if you do, your pacenotes will work with any co-driver. 

If you don't want to use them, your pacenotes will be co-driver dependent. In that case, you can just write (for example, if you're using Stu)

    '4 left minus', '5 left plus long', 'hairpin left over crest', etc. 

Here's an example pacenote file 

1 - caution left 3 minus;

Always check the console for pacenote errors. For example, it will tell you if you use an inexistent samples.

## Testing stuff
There are two test scenarios (gridmap and small island) for testing the mod. They are under the Scenario menu, not the Time Trial menu. 
In particular, the gridmap test will utter every single corner, which is useful when making new co-driver.
