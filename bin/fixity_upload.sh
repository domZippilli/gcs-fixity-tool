#!/usr/bin/env bash

# Display function usage
function usage(){
    echo >&2
    echo "Usage: $0 TARGET_GCS_PATH FILES_TO_UPLOAD" >&2
    echo "Uploads an object to GCS with hash confirmation, and then inserts a fixity check record upon completion." >&2
    echo >&2
}

# Get args
GCS_PATH=${1?$(usage)}
shift
FILES=${@?$(usage)}

# Define your Base64-encoded MD5 checksum here
function checksum(){
    cat $1 | openssl dgst -md5 -binary | openssl enc -base64
}

# Perform an upload to GCS with an MD5 checksum header.
function checksum_upload(){
    gsutil -h Content-MD5:$1 cp "$2" "$3"
}

# Begin uploading files, sending a JSON object reporting the checksummed
# upload to a BQ streaming insert
function upload_files() {
    for f in $FILES; do
        c=$(checksum "$f")
        checksum_upload $c $f $GCS_PATH
        echo \
            {  \
                \"object_url\": \""$GCS_PATH""$f"\", \
                \"md5\":        \""$c"\", \
                \"checked\":    \""$(date +'%Y-%m-%d %H:%M:%S%:z')"\" \
            }
    done 
}

upload_files | bq insert fixity_data.fixity_history 