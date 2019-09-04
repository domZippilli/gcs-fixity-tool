#!/usr/bin/env bash

# Display function usage
function usage(){
    echo >&2
    echo "Usage: $0 gs://BUCKET_NAME/" >&2
    echo "Inserts an empty fixity record for all objects in the given bucket." >&2
    echo >&2
}

BUCKET_NAME=${1?$(usage)}
BUCKET_LIST=$(gsutil ls -r $1**)

function object_json {
    for i in $BUCKET_LIST; do
        echo \
            {  \
                \"object_url\": \""$i"\", \
                \"md5\":        null, \
                \"checked\":    null \
            } 
    done
}

object_json | tee /dev/tty | bq insert fixity_data.fixity_history
