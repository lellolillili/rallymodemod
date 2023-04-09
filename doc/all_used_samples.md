# Basic samples

## Corner calls

Regardless of what's being used at the moment, these need to be in the co-driver

* acute left / tight hairpin left / handbrake left / 
* acute right / tight hairpin right / handbrake right / 
* hairpin left
* hairpin right
* 1 left
* 1 right
* 2 left
* 2 right
* 3 left
* 3 right
* 4 left
* 4 right
* 5 left
* 5 right
* 6 left
* 6 right
* flat left
* flat right
* turn left / square left
* turn right / square right
* 10 20 ... 1000


## List of used calls

call: #occurrences

## corners

It's good to get an idea how common each corner is. 
Note: "into CORNER", "and CORNER" are not in the list, but are good to add.

```
    R5E: 355
    R4E: 319
    L4E: 309
    L3E: 299
    L5E: 265
    R6E: 249
    R3E: 246
    L6E: 237
    L6P: 115
    R6P: 110
    LS: 81
    L0E: 73
    R0E: 67
    L2E: 64
    RS: 59
    R2E: 57
    L2P: 44
    R2P: 39
    L3M: 29
    L4P: 27
    R4P: 26
    R1E: 24
    R3M: 24
    R3P: 22
    L0M: 21
    R0M: 17
    L1E: 17
    R5M: 17
    L3P: 16
    R5P: 15
    L5M: 14
    R0P: 14
    L0P: 14
    L4M: 13
    L5P: 11
    R4M: 11
    L6M: 6
    L2M: 3
    R6M: 2
    L1P: 1
    R2M: 1
    L1M: 1
```

### not corners

Note: some of these are composite. Example: 
If you have samples for *tightens*, *long*, and *tightens long*, the codriver will use them appropriately. If you only have *tightens* and *long*, the co-driver will use *tightens*+*long*. Composite samples make the codriver sound more natural, and I recommend implementing as many as possible.


```
    tightens: 321
    long: 236
    dont cut: 228
    late: 221
    keep right: 161
    sharp: 149
    opens: 149
    keep left: 148
    crest: 114
    over crest: 114
    short: 112
    care: 102
    junction: 84
    cut: 82
    keep in: 78
    over dip: 60
    and: 60
    caution: 59
    opens long: 56
    drops: 56
    go straight: 55
    slowing: 53
    dip: 52
    over bump: 52
    brake: 44
    double tightens: 40
    into: 40
    narrows: 36
    bumpy: 33
    very long: 32
    line: 32
    bump: 32
    tightens long: 27
    keep middle: 25
    right: 25
    left: 23
    bridge: 23
    to finish: 23
    narrow: 21
    small cut: 20
    jump: 20
    downhill: 19
    over jump: 17
    onto tarmac: 16
    keep out: 16
    double caution: 15
    uphill: 15
    curb: 15
    muddy: 14
    onto gravel: 14
    twisty: 13
    rocks outside: 12
    middle over jump: 11
    long over crest: 11
    go wide: 10
    around bale: 10
    deceptive: 9
    to 2: 9
    to 3: 9
    up: 9
    around tree: 8
    at junction: 8
    down: 7
    to 4: 7
    5: 7
    minus: 7
    left over crest: 7
    to: 7
    onto bridge: 7
    through water splash: 6
    through tunnel: 6
    barrier outside: 6
    very late: 6
    through narrow gate: 5
    onto narrow bridge: 5
    opens very long: 4
    bad camber: 4
    round: 4
    small jump: 4
    slippy: 4
    sharp over crest: 4
    around pole: 4
    triple caution: 4
    late over crest: 4
    bumps: 4
    over kink: 4
    in: 3
    over bridge: 3
    opens over crest: 3
    onto dirt: 3
    wide out: 3
    big jump: 3
    hole: 3
    big cut: 3
    rocks in road: 3
    tight: 3
    rocks inside: 2
    middle over crest: 2
    slight right: 2
    then: 2
    at house: 2
    into dip: 2
    to 1: 2
    middle over bump: 2
    short over crest: 2
    over small jump: 2
    water: 2
    half long: 2
    dont: 2
    into bump: 2
    armco: 2
    tidy: 1
    plus: 1
    tarmac: 1
    maybe: 1
    after crest: 1
    100: 1
    go narrow: 1
    slight left: 1
    narrow bridge: 1
    long crest: 1
    continues over crest: 1
    small crest: 1
    into crest: 1
    into finish: 1
    tunnel: 1
```

# Other calls

These are all the remaining calls that are used in default rallies. If a
co-driver desn't have a sample for these, we will need to specify a
substitution. 

* into "corners"
* after crest
* and
* armco
* around bale
* around pole
* around tree
* at crest
* at house
* at junction
* bad camber
* barrier outside
* big cut
* big jump
* keep middle
* brake
* bridge
* bumps
* bumpy
* continues over crest
* curb
* cut late
* cut over crest
* deceptive
* dont cut late
* dont cut long
* dont jump
* double tightens
* downhill
* drops
* go narrow
* go straight
* go wide
* half long
* hole
* into bridge
* into bump
* into crest
* into dip
* into junction
* into mud
* jump maybe
* junction
* long crest
* muddy
* narrow bridge
* narrows
* onto bridge
* onto dirt
* onto gravel
* onto narrow bridge
* onto tarmac
* open hairpin left
* open hairpin right
* opens long
* opens over crest
* opens very long
* over bridge
* over kink
* over small jump
* plus short
* rocks in road
* rocks inside
* rocks outside
* round
* sharp over crest
* slippy
* slowing
* small crest
* small cut
* small jump
* tarmac
* then
* through narrow gate
* through tunnel
* through water splash
* tidy
* tight
* tightens
* to 1
* to 2
* to 3
* to 4
* to 5
* to finish
* triple caution
* twisty
* up
* uphill
* very late
* very long
* wide out


### Substitutions

If we're sampling a co-driver from youtube, it's going to be hard to find
footage that has samples for "around bale", "around pole", "around tree". In
*codriver.ini*, we can just make our co-driver say "don't cut" instead, in the
sample substitution section of the config file.

    around bale >>> dont cut
    around pole >>> dont cut
    around tree >>> dont cut

Alternatively, we can just mute those pacenotes

    around bale >>> _
    around pole >>> _
    around tree >>> _

# script for text to speech 

left, left 1, left 2, left 3, left 4, left 5, left 6, left 7, left 8, left 9, left 10, left 11, left 12, left 13, left 14, hairpin left, handbrake left, chicane left entry, tight hairpin left, and left, right, right 1, right 2, right 3, right 4, right 5, right 6, right 7, right 8, right 9, right 10, right 11, right 12, right 13, right 14, hairpin right, handbrake right, chicane right entry, tight hairpin right, and right, left, into left 1, into left 2, into left 3, into left 4, into left 5, into left 6, into left 7, into left 8, into left 9, into left 10, into left 11, into left 12, into left 13, into left 14, into hairpin left, into handbrake left, into chicane left entry, into tight hairpin left, into and left, right, into right 1, into right 2, into right 3, into right 4, into right 5, into right 6, into right 7, into right 8, into right 9, into right 10, into right 11, into right 12, into right 13, into right 14, into hairpin right, into handbrake right, into chicane right entry, into tight hairpin right, and right, left, and left 1, and left 2, and left 3, and left 4, and left 5, and left 6, and left 7, and left 8, and left 9, and left 10, and left 11, and left 12, and left 13, and left 14, and hairpin left, and handbrake left, and chicane left entry, and tight hairpin left, and left, right, and right 1, and right 2, and right 3, and right 4, and right 5, and right 6, and right 7, and right 8, and right 9, and right 10, and right 11, and right 12, and right 13, and right 14, and hairpin right, and handbrake right, and chicane right entry, and tight hairpin right, and right,
