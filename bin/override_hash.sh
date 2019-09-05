#!/usr/bin/env bash

# Display function usage
function usage(){
    echo >&2
    echo "Usage: $0 OBJECT_PATH HASH" >&2
    echo "Inserts a fixity record with current time for given object with given hash. Does not upload any bytes or compare any hashes." >&2
    echo >&2
}

# Get args
OBJECT_PATH=${1?$(usage)}
HASH=${2?$(usage)}

echo \
    {  \
        \"object_url\": \""$1"\", \
        \"md5\":        \""$2"\", \
        \"checked\":    \""$(date -u +'%Y-%m-%dT%H:%M:%S+00:00')"\" \
    } | bq insert fixity_data.fixity_history
