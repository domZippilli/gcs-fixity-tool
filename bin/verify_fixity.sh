#!/usr/bin/env bash

if [ -z $(which parallel) ]; then
  echo This will be much faster if GNU Parallel is installed.
  echo Most Linux distributions and Homebrew will have
  echo the \"parallel\" package in their default repositories.
  echo For more info, see https://www.gnu.org/software/parallel/
fi

# TODO: Set query timediff values to what is actually desired, such as YEAR, 1
TIMEDIFF_UNIT="SECOND"
TIMEDIFF_QTY="1"
QUERY="SELECT a.object_url, b.md5 FROM (SELECT \
  object_url, MAX(checked) as last_check \
  FROM fixity_data.fixity_history \
  WHERE BYTE_LENGTH(object_url) > 0 \
  GROUP BY object_url) as a \
LEFT JOIN fixity_data.fixity_history as b ON a.object_url = b.object_url AND a.last_check = b.checked \
WHERE last_check IS NULL OR TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_check, "$TIMEDIFF_UNIT") > "$TIMEDIFF_QTY" \
ORDER BY a.object_url"
# Maximum records reviewed in a single execution
MAX_RECORDS=$((10**6))

# Define your Base64-encoded MD5 checksum here
function checksum(){
    openssl dgst -md5 -binary | openssl enc -base64
}

# Get the objects that are due for verification
function get_objects_and_hashes_to_verify {
    echo Querying BigQuery fixity database up to $MAX_RECORDS records... >&2
    bq -q --format csv query -n$MAX_RECORDS --use_legacy_sql=false "$QUERY" | tail -n+2 -f
    echo Query complete. >&2
}

# Get last hash and bytes for the object. Hash downloaded bytes. Confirm match and record, or raise an alert of mismatch.
function verify_object {
    o=$(echo "$1" | cut -d"," -f1)
    lasthash=$(echo "$1" | cut -d"," -f2)

    echo Verifying fixity for: $o
    echo Last Check MD5 Hash:"    "${lasthash:-"<EMPTY>"}

    newhash=$(gsutil cat $o | checksum)
    echo Download MD5 Hash:"      "$newhash

    if [ -z $lasthash ] || [ $newhash == $lasthash ]; then
      echo Hashes match, or last hash is empty. Storing new fixity check record.
      echo \
            {  \
                \"object_url\": \""$o"\", \
                \"md5\":        \""$newhash"\", \
                \"checked\":    \""$(date -u +'%Y-%m-%dT%H:%M:%S+00:00')"\" \
            } | bq insert fixity_data.fixity_history 
    else
      echo !!!HASH MISMATCH!!!
      echo $o MAY BE CORRUPT
      exit 127
    fi
}

export -f checksum get_objects_and_hashes_to_verify verify_object

function map {
  func=$1
  data=$2
if [ -z $(which parallel) ]
then
  # Proceed serially
  for i in $($data); do
    $func $i
  done
else
  # Proceed in parallel
  $($data) | parallel -j 200% --delay .25 $func
fi
}

# Run the verification in parallel over the records with GNU Parallel.
map verify_object get_objects_and_hashes_to_verify

echo "Fixity up to date for all objects in table."