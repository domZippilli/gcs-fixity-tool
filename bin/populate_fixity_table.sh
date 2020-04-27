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