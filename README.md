# Rally mode - experimental

## Download
No need to clone the repo, just Download the leatest release (a zipfile) from the menu on the right.

If you're interested in working on the code, however, then go ahead and clone the repo.
I'm very happy to collaborate with anyone.

## Install
Put the zip file in your mods folder. You do no need to unpack if you just want
to play and edit basic settings (the settings file, *rallyconfig.ini* will be
created in *beamng_local/settings/).

## Go Rallying

If you have a *beamng_local_folder/settings/rallyconfig.ini* from previous versions of the mod, **remove it**.

The rallies are under Time Trials menu. You can only start a rally from the Time
Trials menu. 

You can see the length of a rally in the thumbnail. Shakedowns are short stages,
usually sections of the larger stages. Special stages are traditional length
stages (5 to 15 km, for now).

Most rallies are for vanilla maps, plus a few mod maps. If you want to rally on
mod maps, you will need the following mods
* [PJS Drift and Rally](https://www.beamng.com/resources/pjs-drift-rally-pbr.21164/)
* [Jungle Rock Island - Dirt version](https://www.beamng.com/resources/el-ferritos-jungle-rock-rally.22254/)
* [East Coast USA - Dirt version](https://www.beamng.com/resources/el-ferritos-east-coast-dirt-rally.19717/)
* [Carvalho de Rei](https://www.beamng.com/threads/carvalho-de-rei-rallye-de-portugal-rfactor-port-now-with-pacenotes-support.84721/)

* [Pikes Peak - WIP - coming soon!](https://www.beamng.com/resources/pikes-peak-lidar-edition.4986/)

Start the race. After the countdown, you will be greeted by a
welcome message. Read it and follow the instructions. You need to load the rally
UI in order to see the pacenote symbols and the pause menu. Press
'SHIFT+CTRL+U', add apps, choose the Rally Mode UI app. Keep it nice and big and
centered.

Restart once (press 'R') to disable the waypoint sounds. The custom waypoint
module will be loaded, and the sounds won't play anymore.

Anytime after the countdown starts, you can pause physics ('J') to open the
rally menu. The menu is self explanatory.

Don't forget to hit "save" to save the options you modify.

## Co-driver volume
You will see an option to adjust the co-driver volume. I actually have no idea
what the hell is the correlation between the number you put in there, and actual
volume of the co-driver voice. I only know that 0 is mute, small numbers are low
volume, and large numbers are high volume. Please let me know if you figure out
a reasonable range.

## Configuration

### Advanced options
[More details in *settings/rallyconfig.ini*]

Open *local_BeamNG_folder/setting/rallyconfig.ini* (it is created after you use
the "save" button in the pause menu for the first time). You can edit some of
the options in this file for fine-tuning your co-driver. Not every single option
in this file can be changed from the pause menu.

### Change co-driver
Open *local_beamng_folder/setting/rallyconfig.ini*. In the *codriverDir* option
you can use any of the co-drivers you have in the folder

    mods/unpacked/art/codrivers

For the moment, we have

* Stu - text to speech
* Alex Gelsomino - sampled from real rally footage

### Codriver customization
You can find a tutorial on how you can create and/or customize your co-driver in
Alex Gelsomino's config files.

* art/codrivers/Alex Gelsomino/codriver.ini
* art/codrivers/Alex Gelsomino/symbols.ini
                            
## Edit pacenotes
When rallying, enter the pause menu ('J'), and check the pacenote-file name. You
can create the pacenote file ("filename.pnt") in the correct directory, and
start editing the pacenotes.

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
Here's an example of a valid pacenote file

    1 - L2M;
    2 - LS;
    4 - right 2 minus;
    5 - L2M;
    8 - right 2 minus;
    14 - jump;

The pacenotes attached to waypoints  1, 2, 4, 5, 8 and 14 will be now
overridden. The rest will stay default. Default pacenotes are stored as a
field in the waypoints in
*.../levels/levelname/quickrace/rallyname_forward.prefab*. Do not touch this
file.

### Corner codes:

[More details in *art/codrivers/Stu/codriver.ini* and *art/codrivers/Alex
Gelsomino/codriver.ini*]

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

If you don't want to use them, your pacenotes will be co-driver dependent. In
that case, you can just write (for example, if you're using Stu)

    '4 left minus', '5 left plus long', 'hairpin left over crest', etc.

Here's an example pacenote file

    1 - caution left 3 minus;
    3 - caution R4M long;
    6 - jump;
    8 - hairpin left;

### Pacenote options

There are additional options you can specify after the semicolon
* nosuffix - do not automatically add a distance call after the pacenote

These I haven't used in ages, and I don't have time to test them properly now.
They are supposed to manage how much of a pause the co-driver will take after
uttering a pacenote. The pause length depends on the *breathLength* variable.

* nopause
* shortpause
* verylongpause
* longpause
* pause

Always check the console for pacenote errors. For example, it will tell you if
you use an inexistent samples.

## Testing stuff
There are two test scenarios (gridmap and small island) for testing the mod.
They are under the Scenario menu, not the Time Trial menu.  In particular, the
gridmapV2 test will utter every single corner, which is useful when making new
co-driver.

# Contribute 
There is SO MUCH stuff that ANYONE could do, depending on your inclinations.
Even with 0 coding experience. 

* Testing: just let me know if anything's off
* Feature request - What should I do next?
* YouTube videos (tutorials, showcase, plain ol' rallies)
* Graphic design stuff (logos, map thumbnails, pacenote icons, UI design 
* Do pacenotes for my reverse stages
* Split up the stages and make shorter ones (maybe 3 to 5 km long shakedowns?)
* Stitch them up and make them longer
* Decorating the stages a bit more - I'd love to add some spectators, haybales and stuff
* Implement recce mode
* Implement online leaderboard
* Help out with pacenote samples (do you want to record new sounds? contact me!)
* Same as above, but in your own language

# Contact 
Let's chat here:

https://www.beamng.com/threads/rally-pack-with-pacenotes.84072/
