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
