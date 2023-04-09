# Pre-release testing

## TODO: 
* Say that you need to restart the game (I think) after changing the voice

## Time trials:
Shakedown: Jungle Rock Island - Fucked 
Shakedown: San Toltego - Fucked 

Shakedown: Norte-Portino - Fucked (should work now)

### Phil Mills
* TODO: pictures

# Changelog 
* Reimplemented audio system and UI. Via config files, you can now personalize both 
  * you can now change the volume of the co-driver's voice voice
  * what the co-driver says, what symbols are used, use custom samples, use custom symbols.
* Edit pacenotes by just adding simple plain text files.
* At startup, do a dry run and see if you're using missing files
* Detect wrong dynamic fields automatically (this was a real pain to fix)
* Agnostic corners for compatibility with multiple voices

========================================

# TODO: Next release

* there are occasional "turn left/right" to "SL/SR" everywhere.
* symbols.ini should be in the codriver folder
* merge the distance call into the actual call, so you can use phrases with distances in them, e.g., 30 right, continues over 30, etc
* "options" field
  1. timing adjustments
  2. repeat option: repeats the pacenote
* Use the new samples. I think there's pacenotes that can be edited to make use of the new samples.
* To finish?
* Some junctions in the old time trials are hard to see. Use oskier arrows.
* Double check the positioning of all pacenotes. Sometimes you put waypoints in the middle of a corner, which is wrong.

==========================================

# TODO

* Rally start with nicer countdown and possibility of a jump-start. Look at dragrace.lua. There's an implementation of jump start detection there.

========================================
# Samples

# Alex Gelsomino

* "right.ogg" is missing.
* consider creating "keep left", "keep right", "keep middle", "keep out", "keep in".

# Phil Mills

do a general trim. I think some samples have a very long leading silence.

## Stu

* I think "5 left tightens is weird"
* The new samples sound different (i think it's the sample rate)
* redo (i've deleted them from pacenotes.json for now)
* long opens, tightens long, care narrows
* around rock, around rocks (and add them to utah)

Do more "into X", "and Y".

========================================

# Time trials

### New italian shakedowns
see feedback on discord.
Castelletto shakedown: spawn falls from the sky

## Check that these below have been implemented, they are old notes.

Change all "like keep" into "line"

### Oskier gravel

### Utah tarmac
13.1 km

After you have "at junction" change all the "junction acute/1/2/3 l/r" into "acute/1/2/3 at junction".

# Elferrito Dirt:
12.6 km

## Fastello castelletto

Remove right/left
add a care narrows early on
50 - add nopause
