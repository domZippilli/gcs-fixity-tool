#!/usr/bin/env bash

# Display function usage
function usage(){
    echo >&2
    echo "Usage: $0 gs://BUCKET_NAME/" >&2
    echo "Inserts an empty fixity record for all objects in the given bucket." >&2
    echo >&2
}

BUCKET_NAME=${1?$(usage)}

function get_bucket_list {
    echo Getting bucket list... >&2
    gsutil ls -r $1** | tail -n+0 -f
    echo Bucket listing complete. >&2
}

function object_json {
    for i in $(get_bucket_list $BUCKET_NAME); do
        echo \
            {  \
                \"object_url\": \""$i"\", \
                \"md5\":        null, \
                \"checked\":    null \
            } 
    done
}

echo Starting BQ insert stream...
object_json | tee /dev/tty | bq insert fixity_data.fixity_history
echo BQ insert complete.