#!/usr/bin/env bash
# Copyright 2020 Google, Inc. All Rights Reserved

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
        chk=$(checksum "$f")
        checksum_upload $chk $f $GCS_PATH
        echo \
            {  \
                \"object_url\": \""$GCS_PATH""$f"\", \
                \"md5\":        \""$chk"\", \
                \"checked\":    \""$(date -u +'%Y-%m-%dT%H:%M:%S+00:00')"\" \
            }
    done 
}

upload_files | bq insert fixity_data.fixity_history 