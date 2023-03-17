# Rally mode - experimental

## Install

Remove/rename the other version. Extract into mods/unpacked

## Start a rally.

Open a rally - one of the time trial with pacenotes.
Restart once (press 'R') to start rallying.

## New time trials
They are the ones with just a black thumbnail. They are shorter than the old ones.

## Enable the new UI:
'SHIFT+CTRL+U', add apps, choose the Rally Mode UI app. Keep it nice and big and centered.

## Rally menu:
Anytime after the countdown starts, you can pause physics ('J') to open the rally menu. The menu is self explanatory.

Don't forget to hit "save" to save the options you modify.

## Config

### Advanced options

Open setting/rallyconfig.ini (it is created after you use the "save" button in the menu for the first time).

### Change co-driver

Open setting/rallyconfig.ini. In codriverDir, you can use any of the codrivers you find

mods/unpacked/art/codrivers

For the moment, you can test out

Alex Gelsomino (ripped from youtube)
Phil Mills (ripped from dirt rally)

At the moment UI doesnt work for these (for now). I'll fix upon release.

## Edit pacenotes

When rallying, pause, and check out the pacenote file name. Create the pacenote file ("filename.pnt") in the correct directory. Example:

in mods/unpacked/pacenotedirector/levels/

you have to have these files (note smallIslandRally_forward.pnt)
small_island
 ├── art
 ├── quickrace
 │   ├── smallIslandRally_forward.pnt
 │   ├── smallIslandRally_forward.prefab
 │   ├── smallIslandRally.jpg
 │   ├── smallIslandRally.json
 │   └── smallIslandRally.prefab
 └── smallIslandRally.lua

Pausing Physics will show pacenote information. Use that.

If you want to change pacenote 1 to something that Stu will read "caution left 3 minus", add the following line to the pnt file

1 - caution L3M;

### Corner codes:

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

If you use corner codes, the notes will be compatible with all co-drivers. If you don't, you can just write, instead,

1 - caution left 3 minus;

and the pacenote will only work with Stu.

Always check the console for pacenote errors. For example, it will tell you if you use an inexistent sample.
