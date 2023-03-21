# Edit existing pacenotes

If you just want to know how to change a couple of pacenotes and go on with your life, this is explained in the main page.


# Make your own Time Trials with pacenotes

Creating a rally with pacenotes is effectively the same as creating a Time Trial with many waypoints. If you don't know how to do that, you may want to look that up first, but I will give you just enough information to get by below. 

In this guide, we will create a new rally for Italy. You can adapt this guide to any other map: just copy and paste various stuff into the right directory. It'll make sense as you read on.


### Preparing

Unpack the mod and find out where your local BeamNG folder is. You need to unpack the mod so you can copy-paste some of it content. If you hate unpacked mods for whatever reason, you can always just extract the files you need from the zipfile and place them in the correct directory. In what follows, the local beamng folder will be *Local/BeamNG.drive/*. Note that I use slashes instead of backslashes (because of reasons).


### Cloning an existing rally

The easiest way is to duplicate an existing rally and modify it where needed. Existing rallies for Italy are in the directories:

    Local/BeamNG.drive/0.xx/mods/unpacked/rallymodemod/levels/italy < lua file 
    Local/BeamNG.drive/0.xx/mods/unpacked/rallymodemod/levels/italy/quickrace < prefabs, picture, route (optional: custom pacenotes)

We'll use a rally from Italy as a blueprint, say, *Castelletto*, but you can use whatever. Copy the following files:

    Local/BeamNG.drive/0.xx/mods/unpacked/rallymodemod/levels/italy/Castelletto.lua
                                                                   /quickrace/Castelletto.json
                                                                             /Castelletto_forward.prefab
                                                                             /Castelletto.prefab

Rename the files you just pasted to *myRally* in one of two places:

1. A new local mod containing all your custom rallies

        Local/BeamNG.drive/0.xx/mods/unpacked/MYCUSTOMRALLIES/levels/italy/myRally.lua
                                                                          /quickrace/myRally.json
                                                                                    /myRally_forward.prefab
                                                                                    /myRally.prefab

2. Your local *levels* folder

        Local/BeamNG.drive/0.xx/levels/italy/myRally.lua
                                            /quickrace/myRally.json
                                                       myRally_forward.prefab
                                                       myRally.prefab

We are creating another rally in Italy, but you can place these files in any other level's folder. You'll need to create the folder if it doesn't exist already. 

*myRally.lua* is the file that tells the game to load up the mod every time you start the time trial.
You can paste these 4 files, respecting the hierarchy, in: 

*myRally.json* is the race file: it specifies the order of the waypoints. The number of waypoints in this file must match the number of waypoints in the prefab. Open this file with a text editor and change the track name, description, etc.

*myRally_forward.prefab* this is where the waypoints go. Pacenotes are added to the waypoints. 

*myRally.prefab* this is where stage clutter goes. Race start, barriers, and all that. You can use stage clutter to change a map quite a lot. You can add bridges, big stones, and other fun stuff to create new paths or block old ones. Use your imagination. 

You may also add a thumbnail, *myRally.jpg*, in the quickrace folder.


### World editor

Launch the map where your rally takes place in free roaming and launch the world editor (F11). 

From the asset browser, go to the folder where you copied the files and import the prefab files. Right click on them, and do "import at origin" (or something like that).

Open the scene tree and look for the prefabs you just imported. Right click each of them and unpack them. One is named myRally, and the other is named myRally_forward. Expand myRally, remove all the stage clutter you don't need, and repack the prefab. In this guide I will not explain how to add stage clutter, it's pretty easy. Basically, once you've set up the rally, you can decorate it further. It's useful to keep all this stuff in a separate prefab file, instead of mixing up waypoints and stage objects. 

Expand myRally_forward, so you can see the list of waypoints. The first thing you'll notice is that there are a lot of waypoints. This is because they serve multiple purposes, which I explain now.

![first pic](pics/fig1.jpg)

#### Waypoints

1. Waypoints carry pacenotes describing features of the road such as corners, crests, and dips. They are placed **at** the features (e.g., at corner **entry**, at the **beginning** of a crest, or dip). I can't stress this enough: the whole point of this workflow is that you put a waypoint at the start of a corner, and describe it in the pacenote field. The pacenote director will handle the timing. You can place any number of additional point wherever, but it is very important that at least every single jump/dip/crest/junction/etc has one waypoint right where the feature begins.

![second pic](pics/fig2.jpg)

2. Waypoints define the stage. Distances are calculated with respect to the rough outline of the track that is defined by the waypoints. The better the waypoints follow the road, the more accurate these distances will be. Obviously, the more waypoints there are, the better the outline is. The mod calculates a lot of distances: including a) the distance between two pacenotes, b) the distance between your car and the next pacenote, c) total track length, d) distance traveled so far. There are more, but you get the idea: if there aren't enough waypoints, these distances will be inaccurate and the pacenote director will misbehave. Be liberal with waypoints. 

3. Waypoints act as a (very unsophisticated) track-cutting prevention system. Since you have to pass through every single waypoint to finish the race, skipping one will mess up your lap. For this reason, you should be generous and use large radius waypoints (significantly larger than the road width). The size of waypoints is set on the scale parameter - 15m is a good size, but it depends on how large or narrow the road is. 

In your usual rally, many waypoints will be blank. An empty waypoint either does not have the pacenote dynamic field at all or has its value set to pacenote="empty".

![third pic](pics/fig3.jpg)

### Creating your own rally
Remove all the waypoints from your prefab (*myRally_forward*) from the scene tree except the spawn point, start, finish, and the very first waypoint (Shift+Click to select multiple waypoints from the scene tree, and DEL to delete them). These are usually named something like *some_rally_start*, *some_rally_finish*, and *some_rally_wp1*. It's highly recommended that you rename the waypoints to something unique. In this case, for the first waypoint you can use *my_rally_wp1*, (anything as long as it ends in '1'), and for the start and finish you can use *my_rally_start* and *my_rally_finish*.

You need to change the spawn point name, in this case to *myRally_standing_spawn*. The part before *_standing_spawn* must **always match the json filename** (in this case it is *myRally.json*), otherwise, your car will spawn at the wrong place. Don't get too worried about names, you can always rename everything at the end by opening your prefab file with a text editor and doing find-replace, but always be careful with the name of the standing spawn.

Your starting point now should be a prefab names *myRally_forward*, with the following objects inside

    myRally_standing_spawn
    my_rally_start
    my_rally_wp1
    my_rally_finish

Make sure the dynamic field in the first waypoint is set to "empty" (not crucial, but convenient, as you'll find out.) You will find the dynamic field in the object inspector menu. Copy the first pacenote, *myRally_wp1*. Here's your basic workflow, for the most part: Paste the waypoint (the pasted waypoint will be  automatically renamed to *myRally_wp2*) and navigate with the free camera to where you want to place the next waypoint (e.g., at a corner's entry). Hit the shortcut for *move object to camera*, and edit the pacenote dynamic field if you need to. For example, if the waypoint is at a corner's entry, you can put a pacenote there. Paste the next node, move to camera, and keep going until the end. You have to press enter after writing the note in the field!
Protip: remap "move object to camera" to "V" from *Options>Editor* (or some other shortcut that's convenient to hit right after CTRL-V, because you're gonna be doing a lot of that).

The last waypoint must be *myRally_finish*, and the first one must be *myRally_start*. Place them accordingly. *myRally_standing_spawn* is where your car will spawn. Place it and rotate it so that your car will not spawn upside down.


### OK, what are the pacenotes?

It depends on the co-driver and the samples that they have available, but if you're planning on sharing your notes, you can be extra safe and use [this list](doc/all_available_calls.md). This list guarantees that your pacenotes will work with any co-driver that comes with the experimental and official releases. It will become more useful as I add more co-drivers. 

If you know you're always going to be using the same co-driver, you can use anything sample you can find in its sample folder. Stu has a crapload of samples, but Alex Gelsomino sounds cooler. Have a look here for the list of all the samples

* [Stu's samples](/art/codrivers/Stu/samples)
* [Alex Gelsomino's samples](/art/codrivers/Alex Gelsomino/samples)

### Pacenotes and markers
The co-driver will always tell the distance to the next pacenote after each call. For example: 

    "3 left 40", "6 right 100", "tightens bad 50", "line 300", etc.

Distances are calculated automatically. For medium and long corners, as well as hairpins, it's recommended that you add a "marker waypoint" to specify where the corner ends. You can make a waypoint act as a marker by creating a dynamic field "marker". The value is not important, just set it to 0. Marker behavior is best explained with diagrams. 

    (P) = waypoint with pacenote
    (P) = waypoint with pacenote
    (M) = waypoint with marker
    (PM) = waypoint with pacenote AND marker

Code:
case 1: No marker between 2 pacenotes
If the corner is very short or you're just describing a feature of the road with no relevant length (rock, kink...), just say the distance from the next corner or feature.

    ( P1 ) ----- ( ) ---- ( ) ----- ( ) ----- ( P2 )
     10m         50m      60m       70m         80m

    Call: "P1 70, P2 ..."

case 2: one marker between 2 pacenotes.
If the corner is > 30 meters, you should mark the end of the corner. The only marker is interpreted as the end of the corner you just called.

    ( P1 ) ----- ( M ) ---- ( ) ----- ( ) ----- ( P2 )
     10m         50m        60m       70m         80m

    Call: "P1 50, P2 ..."

If this is confusing to you, look for a waypoint with a marker dynamic field in the examples. I'm sure it'll make sense once you see it in action.

![fourth pic](pics/fig4.jpg)

If two pacenotes are closer than some cutoff distance, the co-driver will not say the distance, but it will add a link word at the beginning of the next call. The cutoff is specified in your local version of *settings/rallyconfig.ini*. In fact, both the cutoff and the link word can be configured. If you set the link word to "and", and the cutoff to 40, the pacenotes "3 left 40", "6 right 100" will become "3 left", "and 6 right 100". 

### Finishing up (or saving your work for later)

Once you're done, either save the map or pack the prefab. Packing the prefab is the recommended way, but there's no problem with just hitting save if you know what you're doing.

If you want to make the Time Trial playable, the waypoint list and names in the json must match the number and name of the waypoints in the forward prefab. You can edit the json with a text editor. If our example, this file is *myRally.json*.

Note that quick edits to the pacenotes can be done directly with a text editor on *myRally_forward.prefab* file. No need to relaunch the game and open the map editor. Note, however, that if you mess something up, it can be very hard to troubleshoot. When in doubt, backup first.

### Common errors and tips

You can look at the console for error messages. It will tell you if you misspelled a pacenote.

If you make a mistake and create a dynamic field whose name has whitespace in it, the game will throw an "expected X, got nil" type of error, without telling you which pacenote is the cause of the issue. You're going to have to go through the text prefab file and check every single pacenote.

If you unpack all the prefabs for a map at the same time, you can quickly see which routes you've already used for a rally. This is useful when you want your rallies to cover the entirety of a map with no overlap.

Create a Time Trial (quickRace) with pacenotes
Suppose you want to do a new Time Trial with pacenotes for gridmap_v2.

# Random notes about saving pacenotes and prefabs

Suppose the Time Trial is published as a mod. If my mods' level folder is set up as follows

    BeamNG.drive/mods/unpacked/rally/levels/gridmap_v2
                                           /rally.prefab
                                           /scenarios/
                                                     /rally.json
                                                     /rally_thumb.jpg

then, upon saving the level from the F11 menu, the following file is created in my local level folder:

    BeamNG.drive/0.24/levels/gridmap_v2/main/MissionGroup/rally_unpacked/items.level.json,

which is essentially a raw prefab. It shows up in the scene tree as *rally_unpacked*, and as far as I can tell overrides the prefab provided by the mod. If I pack it, a local prefab is created in local map's folder

    BeamNG.drive/0.24/levels/gridmap_v2/rally.prefab

and the mission group subfolder disappears.

