# Basic samples

These the most common calls, needed for a minimum working codriver/test codriver
(might need a couple substitutions)

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
* bump
* care / watch 
* caution
* crest / brow
* cut
* dip
* dont cut / dont
* double caution 
* down / downhill
* in / stay in / keep in
* jump
* keep left
* keep middle
* keep out
* keep right
* late
* left
* line
* long
* left over bump
* left over crest
* left over jump
* middle over bump
* middle over crest
* middle over jump
* right over bump
* right over crest
* right over jump
* narrow
* opens
* over bump
* over crest
* over dip
* over jump
* minus
* plus
* right
* sharp
* short

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
