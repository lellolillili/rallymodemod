Here I explain how to create new trime trials with pacenotes, for use with the Rally Mode Mod.

The official, stable release of the Rally Mode Mod can be found here
https://www.beamng.com/resources/rally-mode-smart-co-driver-stages-with-pacenotes.21824/

The documentation and the experimental version  can be found on the github repo
https://github.com/lellolillili/rallymodemod

Edit existing pacenotes
If you just want to know how to change a couple of pacenotes and go on with your life, this is explained in a look at the documentation linked above. This guide is for creating brand new rallies.

Make your own Time Trials with pacenotes
Creating a rally with pacenotes is effectively the same as creating a Time Trial with many waypoints. If you don't know how to create a Time Trial, you may want to look that up first (I will briefly explain that here though). In this guide, we'll name our new rally "myRally".

Preparing
Unpack the mod and find out where your local BeamNG folder is. In what follows, it is Local/BeamNG.drive/. Note that I use slashes instead of backslashes, because of reasons.

Getting started by cloning an existing rally
We'll copy one of the mods' rallies from the mod's folder into our local level folder. We'll use a random rally from Italy as a blueprint, but you can use whatever. Go to

Local/BeamNG.drive/0.xx/mods/unpacked/rallymodemod/levels/italy.

copy any one of the lua files (we'll use Castelletto.lua in this example), paste it to

Local/BeamNG.drive/0.26/levels/italy,

and rename the file you just pasted to myRally.lua. We are creating another rally in Italy, but you can pase  the file in any other level's folder. You'll need to create the folder if it doesn't exist already. This is the file that tells the game to load up the mod every time you play one of the rallies.

Go to the mod's italy/quickrace folder

Local/BeamNG.drive/0.26/mods/unpacked/pacenoteDirector/levels/italy/quickrace,

copy the following files
Castelletto.json
Castelletto_forward.prefab
Castelletto.prefab
and paste them into

Local/BeamNG.drive/0.26/levels/italy/quickrace. Rename the files you just pasted to
myRally.json
myRally_forward.prefab
myRally.prefab
1. has Stage info and waypoint order, 2. has waypoints and start/finish stage stuff, and 3. has barriers, stage clutter, and all that. You can use stage clutter to change a map quite a lot. You can add bridges, big stones, and other fun stuff to create new paths or block old ones. Use your imagination.

You may also add a thumbnail, myRally.jpg.

Open up myRally.json with a text editor and change the track name, description, etc.

Launch the map editor
Launch the game and start the Time Trial you just created. Don't worry if your car starts falling from the sky. It's just a waypoint name mismatch that you will fix soon.

Launch the F11 menu. Open the scene tree and look for the prefab. You'll find it after scrolling all the way down, in the MissionGroup group. It will be named myRally, and have a little package icon. Right-click, unpack it, and expand it so you can see the list of waypoints. The first thing you'll notice is that there are a lot of waypoints. This is because they serve multiple purposes, which I explain now.

upload_2022-3-2_21-32-31.png

Waypoints
1. Waypoints carry pacenotes describing features of the road such as corners, crests, and dips. They are placed at the features (e.g., at corner entry, at the beginning of a crest, or on a dip). I can't stress this enough: the whole point of this workflow is that you put a waypoint at a corner, and describe it in the pacenote field. The pacenote director will handle the timing.

upload_2022-3-2_21-29-29.png

2. Waypoints define the stage. Distances between any two points are calculated with respect to the rough outline of the track that is defined by the waypoints. The better the waypoints follow the road, the more accurate these distances will be. Examples of distances that are used by the mod are a) the distance between two pacenotes, b) the distance between your car and the next pacenote, c) total track length, d) distance traveled so far. There are more, but you get the idea: if there aren't enough waypoints, these distances will be inaccurate and the pacenote director will behave badly.

3. Waypoints act as a (very unsophisticated) track-cutting prevention system. Since you have to pass through every single waypoint to finish the track, skipping one will mess up your lap. For this reason, you should be generous and use large radius waypoints (significantly larger than the road width). More sophisticated systems such as time penalties and wrong way detection are a bit overkill for now, given the stage of the mod.

In your usual rally, many waypoints will be blank. An empty waypoint either does not have the pacenote dynamic field at all or has its value set to pacenote="empty".

upload_2022-3-2_21-29-51.png

Creating your own rally
Remove all the pacenotes from your prefab on the scene tree except the spawn point, start, finish, and the very first waypoint (shift+click to select multiple waypoints from the scene tree). These are usually named something_start, something_finish, and something_wp1. It's highly recommended that you rename the waypoints to something unique, for reasons that are beyond the scope of this tutorial. in this case, you can use my_rally_wp1, or myRallywp1 (anything al long as it ends in '1').

You need to change the spawn point name, in this case to myRally_standing_spawn. The part before _standing_spawn must always match the json filename (from myRally.json), otherwise, your car will spawn at the wrong place. Don't get too worried about names, you can always rename everything at the end by opening your prefab file with a text editor and doing find-replace. Just always be careful with the name of the standing spawn.

Your starting point now should be a prefab names myRally, with the following objects inside

myRally_standing_spawn
myRally_start
myRally_wp1
myRally_finish

Make sure the dynamic field in the first waypoint is set to "empty" (not crucial, but convenient, as you'll find out.) Copy the first pacenote, myRally_wp1. Here's your basic workflow, for the most part: Paste the waypoint (the pasted waypoint will be conveniently renamed to myRally_wp2), and navigate with the free camera to where you want to put the next waypoint (e.g., at a corner's entry), hit the shortcut for "move object to camera", and edit the pacenote dynamic field if you need to. Paste the next node, and do the same.

The last waypoint must be myRally_finish, and the first one must be myRally_start. Place them accordingly. myRally_standing_spawn is where your car will spawn, and should be in the middle of myRally_standing_spawn. Place it and rotate it so that your car will not spawn upside down.

Protip: re-map "move object to camera" to "V" from Options>Editor (or some other shortcut that's convenient to hit right after CTRL-V, because you're gonna be doing a lot of that).

The list of available calls is in the file AppData/Local/BeamNG.drive/0.24/mods/unpacked/pacenoteDirector/scripts/pacenotes/pacenotes.json.

Note: you have to press enter after writing the note in the field!

Note: blank nodes can be either pacenote="empty", or not have the pacenote field altogether.

Pacenotes and markers
The co-driver will always say the distance to the next pacenote after the call. For example, a few calls in a row will sound something like

"3 left 40", "6 right 100", "tightens bad 50", "line 300", etc.

Distances are calculated automatically. For medium and long corners, as well as hairpins, it's recommended that you add a "marker waypoint" to specify where the corner ends. Marker behavior is best explained with diagrams. This is done by adding the dynamic field marker to the waypoint. This is how markers work:

(P) = waypoint with pacenote
(P) = waypoint with pacenote
(M) = waypoint with marker
(PM) = waypoint with pacenote AND marker

Code:
case 1: No marker between 2 pacenotes
If the corner is very short or you're just describing a feature of the road with no relevant length (rock, kink...), just say the dist from the next corner or feature.
( P ) ----- ( ) ---- ( ) ----- ( ) ----- ( P )

case 2: one marker between 2 pacenotes.
If the corner is > 30 meters, you should mark the end of the corner. The only marker is interpreted as the end of the corner you just called.
( P ) ----- ( M ) ---- ( ) ----- ( ) ------ ( P )

You make a waypoint act as a marker by adding a dynamic field named "marker" to the waypoint. The content doesn't matter, but it'll be 0 by default. Also, note that putting a marker field on a non-empty pacenote does nothing. If this is confusing to you, look for a waypoint with a marker dynamic field in the examples. I'm sure it'll make sense once you see it in action.

upload_2022-3-2_21-31-49.png

If two pacenotes are closer than some cutoff distance, the co-driver will not say the distance, but it will add a link word at the beginning of the next call. The cutoff is specified in the settings/rallyconfig.ini configuration file. The cutoff and the link word can be configured. If you set the link word to "and", and the cutoff to 40, the utterance "3 left 40", "6 right 100" will become "3 left", "and 6 right 100". Look at the config file for the defaults and recommendations.

As far as saving the prefab, packing, unpacking and exporting it, saving it as a mod, etc, you can just treat it as a normal prefab. Once you're done, either save or pack the prefab. Packing is recommended, but there's no problem with just hitting save if you know what you're doing.

Finishing up

Pack the prefab. With a text editor, open

Local/BeamNG.drive/0.26/levels/italy/quickrace

You'll see a list of waypoints. This list must match the waypoint you have defined in your prefab.

Note that quick edits to pacenotes can be done directly with a text editor on the prefab file. No need to relaunch the game and open the map editor. Note, however, that if you mess something up, it'll be very hard to troubleshoot. When in doubt, backup first.

Common errors and tips
Waypoints in the prefab file and the json file must match. The spawn point must be named correctly, json and prefab must have the same number of waypoints, and their names must match.

If you make a mistake and create a dynamic field whose name has whitespace in it, the game will throw an "expected X, got nil" type of error, without telling you which pacenote is the cause of the issue. You're going to have to go through the text prefab file and check every single pacenote.

If you unpack all the prefabs for a map at the same time, you can quickly see which routes you've already used for a rally. This is useful when you want your rallys to cover the entirety of a map with no overlap.

Create a Time Trial (quickRace) with pacenotes
Suppose you want to do a new Time Trial with pacenotes for gridmap_v2.

1. Copy paste the folder structure for a Time Trial and all its files. These are

BeamNG.drive/0.24/levels/gridmap_v2/quickrace/testRally.json
BeamNG.drive/0.24/levels/gridmap_v2/quickrace/testRally.prefab
BeamNG.drive/0.24/levels/gridmap_v2/quickrace/testRally_forward.prefab
BeamNG.drive/0.24/levels/gridmap_v2/testRally.lua

2. Launch a Time Trial, open map editor, unpack the prefab, and edit waypoints and their pacenotes.

3. Pack the prefab. This should save the new prefab on top of the new one. Packed prefabs are relatively readable, so you can do quick edits to it with a text editor if needed (e.g., a quick edit to a pacenote).

4. Update the race order in testRally.json.

Random notes about saving pacenotes and prefabs
Suppose the Time Trial is published as a mod. If my mods' level folder is set up as follows
Code:
BeamNG.drive/mods/unpacked/rally/levels/gridmap_v2
                                    ├── rally.prefab
                                    └── scenarios
                                        ├── rally.json
                                        └── rally_thumb.jpg

then, upon saving the level from the F11 menu, the following file is created in my local level folder:

BeamNG.drive/0.24/levels/gridmap_v2/main/MissionGroup/rally_unpacked/items.level.json,

which is essentially a raw prefab. It shows up in the scene tree as rally_unpacked, and as far as I can tell overrides the prefab provided by the mod. If I pack it, a local prefab is created in the map's folder

BeamNG.drive/0.24/levels/gridmap_v2/rally.prefab

and the mission group subfolder disappears.

Doing recce (a.k.a changing the pacenotes you don't like)
Once the pacenotes are done, the fun just begins, because I want players to be able to tweak and personalize the notes, by allowing them to do their own recce.

upload_2022-3-2_21-30-12.png

Copy all the prefabs that end in _forward.prefab into your local beamng folder, recreating the correct structure.

Waypoint information is displayed in the console (~). Pause the game whenever you find a pacenote you want to change. Find the exact waypoint name in the console (it has all the necessary information), open prefab with a text editor, CTRL-F to the waypoint, and change the pacenote. See pic. The list of available calls is in the file AppData/Local/BeamNG.drive/0.24/mods/unpacked/pacenoteDirector/scripts/pacenotes/pacenotes.json.

You can also change the pacenotes by opening the F11 menu and unpacking the prefab. Don't forget to repack it.


How the mod works
I'm using the Pacenotes Core mod to utter the calls, and the game's built-in waypoint-based race logic to handle the scenario. In practice, you are playing a normal Time Trial, but with pacenotes. The pacenote director can also run on top of scenarios. It works as long as the prefab has waypoints, and waypoints have pacenotes in them.

Pacenotes are added to waypoints, which I'm also using to define rough track limits. During the race, the pacenote director figures out when to say the pacenotes and will calculate distance calls automatically. A distance call is the distance from the current pacenote to the next pacenote. If you marked two waypoints that are 100 meters away as, say, "3 left" and "crest", the co-driver will automatically say "3 left, 100 [PAUSE], crest ...". The director will utter a call T seconds before you cross the waypoint, basing the estimate on the current car speed and other stuff that you have control over. You can configure T in the config file.Released on the repo, see https://www.beamng.com/resources/pacenotedirector.21824/

Configuration
See repo link.

TUTORIAL: Make your own Time Trials with pacenotes
scroll down to section "Recce" if you just want to know how to change a couple of pacenotes and go on with your life

Create a new Time Trial with pacenotes
Creating a rally with pacenotes is effectively the same as creating a Time Trial with many waypoints. If you don't know how to create a Time Trial, you may want to look that up first (I will briefly explain that here though). In this guide, we'll name our new rally "myRally".

Preparing
Unpack the mod and find out where your local BeamNG folder is. In what follows, it is Local/BeamNG.drive/. Note that I use slashes instead of backslashes.

Getting started by cloning an existing rally
We'll copy one of the mods' rallies from the mod's folder to our local level folder. Go to

Local/BeamNG.drive/0.26/mods/unpacked/pacenoteDirector/levels/italy.

copy any one of the lua files (we'll use Castelletto.lua in this example), paste it to

Local/BeamNG.drive/0.26/levels/italy,

and rename the file you just pasted to myRally.lua. You'll need to create the folder if it doesn't exist already. This is the file that tells the game to load up the mod every time you play one of the rallies.

Go to the mod's italy/quickrace folder

Local/BeamNG.drive/0.26/mods/unpacked/pacenoteDirector/levels/italy/quickrace,

copy the following files
Castelletto.json
Castelletto_forward.prefab
Castelletto.prefab
and paste them into

Local/BeamNG.drive/0.26/levels/italy/quickrace. Rename the files you just pasted to
myRally.json
myRally_forward.prefab
myRally.prefab
1. has Stage info and waypoint order, 2. has waypoints and start/finish stage stuff, and 3. has barriers, stage clutter, and all that. You can use stage clutter to change a map quite a lot. You can add bridges, big stones, and other fun stuff to create new paths or block old ones. Use your imagination.

You may also add a thumbnail, myRally.jpg.

Open up myRally.json with a text editor and change the track name, description, etc.

Launch the map editor
Launch the game and start the Time Trial you just created. Don't worry if your car starts falling from the sky. It's just a waypoint name mismatch that you will fix soon.

Launch the F11 menu. Open the scene tree and look for the prefab. You'll find it after scrolling all the way down, in the MissionGroup group. It will be named myRally, and have a little package icon. Right-click, unpack it, and expand it so you can see the list of waypoints. The first thing you'll notice is that there are a lot of waypoints. This is because they serve multiple purposes, which I explain now.

upload_2022-3-2_21-32-31.png

Waypoints
1. Waypoints carry pacenotes describing features of the road such as corners, crests, and dips. They are placed at the features (e.g., at corner entry, at the beginning of a crest, or on a dip). I can't stress this enough: the whole point of this workflow is that you put a waypoint at a corner, and describe it in the pacenote field. The pacenote director will handle the timing.

upload_2022-3-2_21-29-29.png

2. Waypoints define the stage. Distances between any two points are calculated with respect to the rough outline of the track that is defined by the waypoints. The better the waypoints follow the road, the more accurate these distances will be. Examples of distances that are used by the mod are a) the distance between two pacenotes, b) the distance between your car and the next pacenote, c) total track length, d) distance traveled so far. There are more, but you get the idea: if there aren't enough waypoints, these distances will be inaccurate and the pacenote director will behave badly.

3. Waypoints act as a (very unsophisticated) track-cutting prevention system. Since you have to pass through every single waypoint to finish the track, skipping one will mess up your lap. For this reason, you should be generous and use large radius waypoints (significantly larger than the road width). More sophisticated systems such as time penalties and wrong way detection are a bit overkill for now, given the stage of the mod.

In your usual rally, many waypoints will be blank. An empty waypoint either does not have the pacenote dynamic field at all or has its value set to pacenote="empty".

upload_2022-3-2_21-29-51.png

Creating your own rally
Remove all the pacenotes from your prefab on the scene tree except the spawn point, start, finish, and the very first waypoint (shift+click to select multiple waypoints from the scene tree). These are usually named something_start, something_finish, and something_wp1. It's highly recommended that you rename the waypoints to something unique, for reasons that are beyond the scope of this tutorial. in this case, you can use my_rally_wp1, or myRallywp1 (anything al long as it ends in '1').

You need to change the spawn point name, in this case to myRally_standing_spawn. The part before _standing_spawn must always match the json filename (from myRally.json), otherwise, your car will spawn at the wrong place. Don't get too worried about names, you can always rename everything at the end by opening your prefab file with a text editor and doing find-replace. Just always be careful with the name of the standing spawn.

Your starting point now should be a prefab names myRally, with the following objects inside

myRally_standing_spawn
myRally_start
myRally_wp1
myRally_finish

Make sure the dynamic field in the first waypoint is set to "empty" (not crucial, but convenient, as you'll find out.) Copy the first pacenote, myRally_wp1. Here's your basic workflow, for the most part: Paste the waypoint (the pasted waypoint will be conveniently renamed to myRally_wp2), and navigate with the free camera to where you want to put the next waypoint (e.g., at a corner's entry), hit the shortcut for "move object to camera", and edit the pacenote dynamic field if you need to. Paste the next node, and do the same.

The last waypoint must be myRally_finish, and the first one must be myRally_start. Place them accordingly. myRally_standing_spawn is where your car will spawn, and should be in the middle of myRally_standing_spawn. Place it and rotate it so that your car will not spawn upside down.

Protip: re-map "move object to camera" to "V" from Options>Editor (or some other shortcut that's convenient to hit right after CTRL-V, because you're gonna be doing a lot of that).

The list of available calls is in the file AppData/Local/BeamNG.drive/0.24/mods/unpacked/pacenoteDirector/scripts/pacenotes/pacenotes.json.

Note: you have to press enter after writing the note in the field!

Note: blank nodes can be either pacenote="empty", or not have the pacenote field altogether.

Pacenotes and markers
The co-driver will always say the distance to the next pacenote after the call. For example, a few calls in a row will sound something like

"3 left 40", "6 right 100", "tightens bad 50", "line 300", etc.

Distances are calculated automatically. For medium and long corners, as well as hairpins, it's recommended that you add a "marker waypoint" to specify where the corner ends. Marker behavior is best explained with diagrams. This is done by adding the dynamic field marker to the waypoint. This is how markers work:

(P) = waypoint with pacenote
(P) = waypoint with pacenote
(M) = waypoint with marker
(PM) = waypoint with pacenote AND marker

Code:
case 1: No marker between 2 pacenotes
If the corner is very short or you're just describing a feature of the road with no relevant length (rock, kink...), just say the dist from the next corner or feature.
( P ) ----- ( ) ---- ( ) ----- ( ) ----- ( P )

case 2: one marker between 2 pacenotes.
If the corner is > 30 meters, you should mark the end of the corner. The only marker is interpreted as the end of the corner you just called.
( P ) ----- ( M ) ---- ( ) ----- ( ) ------ ( P )

You make a waypoint act as a marker by adding a dynamic field named "marker" to the waypoint. The content doesn't matter, but it'll be 0 by default. Also, note that putting a marker field on a non-empty pacenote does nothing. If this is confusing to you, look for a waypoint with a marker dynamic field in the examples. I'm sure it'll make sense once you see it in action.

upload_2022-3-2_21-31-49.png

If two pacenotes are closer than some cutoff distance, the co-driver will not say the distance, but it will add a link word at the beginning of the next call. The cutoff is specified in the settings/rallyconfig.ini configuration file. The cutoff and the link word can be configured. If you set the link word to "and", and the cutoff to 40, the utterance "3 left 40", "6 right 100" will become "3 left", "and 6 right 100". Look at the config file for the defaults and recommendations.

As far as saving the prefab, packing, unpacking and exporting it, saving it as a mod, etc, you can just treat it as a normal prefab. Once you're done, either save or pack the prefab. Packing is recommended, but there's no problem with just hitting save if you know what you're doing.

Finishing up

Pack the prefab. With a text editor, open

Local/BeamNG.drive/0.26/levels/italy/quickrace

You'll see a list of waypoints. This list must match the waypoint you have defined in your prefab.

Note that quick edits to pacenotes can be done directly with a text editor on the prefab file. No need to relaunch the game and open the map editor. Note, however, that if you mess something up, it'll be very hard to troubleshoot. When in doubt, backup first.

Common errors and tips
Waypoints in the prefab file and the json file must match. The spawn point must be named correctly, json and prefab must have the same number of waypoints, and their names must match.

If you make a mistake and create a dynamic field whose name has whitespace in it, the game will throw an "expected X, got nil" type of error, without telling you which pacenote is the cause of the issue. You're going to have to go through the text prefab file and check every single pacenote.

If you unpack all the prefabs for a map at the same time, you can quickly see which routes you've already used for a rally. This is useful when you want your rallys to cover the entirety of a map with no overlap.

Create a Time Trial (quickRace) with pacenotes
Suppose you want to do a new Time Trial with pacenotes for gridmap_v2.

1. Copy paste the folder structure for a Time Trial and all its files. These are

BeamNG.drive/0.24/levels/gridmap_v2/quickrace/testRally.json
BeamNG.drive/0.24/levels/gridmap_v2/quickrace/testRally.prefab
BeamNG.drive/0.24/levels/gridmap_v2/quickrace/testRally_forward.prefab
BeamNG.drive/0.24/levels/gridmap_v2/testRally.lua

2. Launch a Time Trial, open map editor, unpack the prefab, and edit waypoints and their pacenotes.

3. Pack the prefab. This should save the new prefab on top of the new one. Packed prefabs are relatively readable, so you can do quick edits to it with a text editor if needed (e.g., a quick edit to a pacenote).

4. Update the race order in testRally.json.

Random notes about saving pacenotes and prefabs
Suppose the Time Trial is published as a mod. If my mods' level folder is set up as follows
Code:
BeamNG.drive/mods/unpacked/rally/levels/gridmap_v2
                                    ├── rally.prefab
                                    └── scenarios
                                        ├── rally.json
                                        └── rally_thumb.jpg

then, upon saving the level from the F11 menu, the following file is created in my local level folder:

BeamNG.drive/0.24/levels/gridmap_v2/main/MissionGroup/rally_unpacked/items.level.json,

which is essentially a raw prefab. It shows up in the scene tree as rally_unpacked, and as far as I can tell overrides the prefab provided by the mod. If I pack it, a local prefab is created in the map's folder

BeamNG.drive/0.24/levels/gridmap_v2/rally.prefab

and the mission group subfolder disappears.

Doing recce (a.k.a changing the pacenotes you don't like)
Once the pacenotes are done, the fun just begins, because I want players to be able to tweak and personalize the notes, by allowing them to do their own recce.

upload_2022-3-2_21-30-12.png

Copy all the prefabs that end in _forward.prefab into your local beamng folder, recreating the correct structure.

Waypoint information is displayed in the console (~). Pause the game whenever you find a pacenote you want to change. Find the exact waypoint name in the console (it has all the necessary information), open prefab with a text editor, CTRL-F to the waypoint, and change the pacenote. See pic. The list of available calls is in the file AppData/Local/BeamNG.drive/0.24/mods/unpacked/pacenoteDirector/scripts/pacenotes/pacenotes.json.

You can also change the pacenotes by opening the F11 menu and unpacking the prefab. Don't forget to repack it.


How the mod works
I'm using the Pacenotes Core mod to utter the calls, and the game's built-in waypoint-based race logic to handle the scenario. In practice, you are playing a normal Time Trial, but with pacenotes. The pacenote director can also run on top of scenarios. It works as long as the prefab has waypoints, and waypoints have pacenotes in them.

Pacenotes are added to waypoints, which I'm also using to define rough track limits. During the race, the pacenote director figures out when to say the pacenotes and will calculate distance calls automatically. A distance call is the distance from the current pacenote to the next pacenote. If you marked two waypoints that are 100 meters away as, say, "3 left" and "crest", the co-driver will automatically say "3 left, 100 [PAUSE], crest ...". The director will utter a call T seconds before you cross the waypoint, basing the estimate on the current car speed and other stuff that you have control over. You can configure T in the config file.

