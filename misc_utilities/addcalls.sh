# Samples to implement
SAMPLEDIR=./pacenotes
# Currently implemented pacenotes
PACENOTEFILE=./pacenotes.json
# Create file with the new calls. Merge this manually with PACENOTEFILE
TARGETFILE=./new_calls.json

rm $TARGETFILE
touch $TARGETFILE

for f in $SAMPLEDIR/*.ogg;
    do
        CALL=$(basename "$f" .ogg)

        if grep -q "\"$CALL\"" "$PACENOTEFILE";

        then
            echo \
                "Skipped '$CALL'"

        else
            echo -e "\
                \t\"$CALL\": {\n\
                \t\t\"file\": \"$CALL.ogg\"\n\
                \t},\
                " >> ./new_calls.json
            echo \
                "Added '$CALL'"

        fi
    done
echo -e \
"
=====================================
If skipped: already in '$PACENOTEFILE'.
If added: not found in '$PACENOTEFILE', written to '$TARGETFILE'.
Don't forget to merge the new calls manually.
"
