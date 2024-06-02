# Notes

the AI pacenote mod (AIP) implemented so much stuff, very well, and we should start from there. 
The issue is that it uses external tools to speak. I'm not sure about pacenote direction (i.e., deciding *when* to speak).
AIP does not have the issue of figuring out what it can say given a pool of samples, so all of that is not implemented.

If we want to do stuff with voicevers, we will need all that. This approach is flexible in some aspects, but less flexible in others.

There are other benefits to the sample-based approach:
 * substitutions: this allows one to switch to different pacenote styles and languages without touching the pacenotes themselves. This means that pacenotes would be more shareable, and you can use your own conventions on whatever pacenotes you get.
 * pacenote granularity: we could write crazy detailed pacenotes and adjust the granularity. Beginners might prefer just 1 to 6, long, tightens, but experts might prefer more detailed pacenotes. If we have a set of samples, it's easy to associate a granularity index to each sample, and decide whether to use it to build the call depending on that.
 * adjustable voice acting: samples could have different versions: smooth, rough, fast, chill etc, and we could build the pacenote with that information (this is what Dirt rally does, and it's very immersive.) 
 
 One thing to note is that text-to-speech is only going to get better, and AIP does speed-adjustment and decent intonation adjustment (with clever use of punctuation). I don't see how it could do roughness though. Sometimes talking too fast makes it sound a bit silly, but I think this is not hard to fix (just split the notes more reasonably, for example). It may or may not be feasible, but it is at least conceivable that one could train a text-to-speech AI to sound like a voice-acted rally co-driver. 

## Pacenote making

## For players

I think the only thing that AIP is missing is a simplified way to create pacenotes. Currently, it's easy, but not as much as it could be. I think there's room for improvement. It shouldn't be too hard to make the process even more streamlined, by removing the driving. From the documentation and youtube videos, it still looks like making your own pacenotes is a whole thing. 

I think all we need is implement rally creation as a recce-mode minigame that takes care of all the world/mission editor stuff under the hood. Just drop the driveline at all times, smooth it out with road snapping, and make it possible to rewind, go back, and add the pacenote after you've driven the corner. This would even make it possible to drive the stage at speed on the very first time, which is great for the impatient. 

Same, but with a free camera that kind of loosely snaps to the road instead, if you just want to focus on the pacenotes first, and drive later.

## For content creators

### Ultrafast stage creation

Why is this important: the edge of our competitors is that they have so many stages. I think we need to be able to generate as many rallies as possible from each map. I think I did a pretty good job in italy, utah and jungle island. In particular, I think Italy has almost as many unique rallies as we need to make it a proper rally weekend. Other maps are small, unfortunately, and we need to squeeze as many unique rallies as possible out of them.

We just needs a few additions to the rally editor:
 * attach a driveline drawer to the free camera (hotkey to activate/deactivate driveline recording)
 * driveline smoother: snap driveline to the road
 * hotkey to drop a pacenote, hotkey to drop a marker
This would make the process super easy: you just hover over the road (not worrying about being super accurate), dropping pacenotes in your own time, stopping to have a look around, resume driveline recording, write down the note if you want or leave it for the recce. Then, for proper recce, you'd use what's already in AIP, just drive, and pause physics and edit whatever note you disagree with.

## Rally stage making
 * I was reading through AIP's documentation, and I noticed that the author also noticed how time consuming the stage decoration part is. If we're going for immersion and accessibility, we're going to need at the very least some stage decorations. We have a driveline and we can snap stuff to road we could use that, at the very least we could automatically add some decorations to junctions and rally beginning and rally end. 
 * Again, the snaproad is super powerful and can be used for this as well. Just use a hotkey to "drive" the free camera along the driveline, and have a small menu with common rally assets. For example, you can click on barrier, and it drops a barrier parallel to the snaproad and snapped to ground. Same with small variations on rally signage and all that. (this system can be applied to other mission types as well!).

all of this could translate into a very simple workflow where you just hover on the track and increase or decrease the driveline incrementally, stop to add a pacenote, a marker, or a rally asset. You could do everything in one go, and refine the pacenotes by driving at speed and pausing and modifying. all of this can be implemented as a driving minigame as well, instead of a rally editor thing.

# other 
        
## How do I
 * draw a freggin shpere?
 * find the correct height for spawn purposes. otherwise I spawn in the middle
   of the waypoint, which can sometimes be under or over the ground.
 * load all rally prefabs without having to save them to the scenetree. or maybe how do i save to scenetree from lua?

# Write here or forget
load the mod from freeroam. just launch from the console
```
extensions.loadAtRoot("ge/extensions/scenario/rallyMode", "scenario")
```
i think you can reload the extension like this
```
extensions.loadAtRoot("scenario_rallyMode")
```


# Things I'd like to know
 * how do i reload the extension for debugging purposes? 
 * can i add custom variables to the json files? I'd like to write the prefab prefix in there, for example.


# Suggestions for Johnson

"left/right/middle over jump"
"left/right/middle over crest"
"tightens over crest"
"tightens late"
"opens and tightens"
"tunnel"

# John

jump symbol

# Time trials:

Johnson valley loop - test & add clutter
Johnson SSS - do pacenotes 

# General

* After you have "at junction" change all the "junction acute/1/2/3 l/r" into "acute/1/2/3 at junction".

========================================

# TODO: Next release

* merge the distance call into the actual call, so you can use phrases with
  distances in them, e.g., 30 right, continues over 30, etc
* "options" field
  1. timing adjustments
  2. repeat option: repeats the pacenote
  3. breath stuff does nothing 
* Double check the positioning of all pacenotes. Sometimes you put waypoints in the middle of a corner, which is wrong.
* Rally start with nicer countdown and possibility of a jump-start. Look at dragrace.lua. There's an implementation of jump start detection there.
* Shakedown: Jungle Rock Island - Fucked
* Shakedown: Norte-Portino - Fucked (should work now)
    Removed both, cause I couldn't figure it out. Maybe you can find an old version on git and try fixing it again. 

========================================
# Samples

## Alex Gelsomino

* "right.ogg" is missing.
* consider creating "keep left", "keep right", "keep middle", "keep out", "keep in".
