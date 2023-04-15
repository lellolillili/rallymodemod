#!/bin/zsh

# This script checks that all the pacenotes in the levels folder with respect to
# a specific co-driver and shows mistakes

CODRIVERNAME="RBR-French"
CODRIVERDIR=../art/codrivers/$CODRIVERNAME
SAMPLESDIR=$CODRIVERDIR/samples

rm /tmp/calls
touch /tmp/calls
rm /tmp/codriver
touch /tmp/codriver

SAMPLES=("")
for s in $SAMPLESDIR/*.ogg; do
    SAMPLE=`basename $s .ogg`
    echo $SAMPLE >> /tmp/codriver
done

PREFABS=("")
for f in ../levels/**/*_forward.prefab; do
    PREFABS+=($f)
    PACENOTE=`sed -nr 's/pacenote = \"(.*)\"\;/\1/p' $f`
    echo $PACENOTE >> /tmp/calls
done

# The matching algorithm is the same used by the mod.
lua ./call_to_samples.lua $CODRIVERDIR
