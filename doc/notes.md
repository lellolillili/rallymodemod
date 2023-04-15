# Time trials:

Johnson valley loop - test & add clutter
Johnson SSS - do pacenotes 

Shakedown: Jungle Rock Island - Fucked 
Shakedown: San Toltego - Fucked 

Shakedown: Norte-Portino - Fucked (should work now)

<<<<<<< HEAD
# General

* After you have "at junction" change all the "junction acute/1/2/3 l/r" into "acute/1/2/3 at junction".
* Merge the distance call into the actual call, so you can use phrases with distances in them, e.g., 30 right, continues over 30, etc
=======
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
>>>>>>> origin/main
* "options" field
  1. timing adjustments
  2. repeat option: repeats the pacenote
* Double check the positioning of all pacenotes. Sometimes you put waypoints in the middle of a corner, which is wrong.
* Rally start with nicer countdown and possibility of a jump-start. Look at dragrace.lua. There's an implementation of jump start detection there.

<<<<<<< HEAD
=======
========================================
# Samples

# Alex Gelsomino

* "right.ogg" is missing.
* consider creating "keep left", "keep right", "keep middle", "keep out", "keep in".

# Phil Mills

do a general trim. I think some samples have a very long leading silence.

>>>>>>> origin/main
## Stu

* I think "5 left tightens is weird"
* The new samples sound different (i think it's the sample rate)
