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
    echo "Usage: $0 OBJECT_PATH HASH" >&2
    echo "Inserts a fixity record with current time for given object with given hash. Does not upload any bytes or compare any hashes." >&2
    echo >&2
}

# Get args
OBJECT_PATH=${1?$(usage)}
HASH=${2?$(usage)}

echo \
    {  \
        \"object_url\": \""$OBJECT_PATH"\", \
        \"md5\":        \""$HASH"\", \
        \"checked\":    \""$(date -u +'%Y-%m-%dT%H:%M:%S+00:00')"\" \
    } | bq insert fixity_data.fixity_history
