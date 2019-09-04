#!/usr/bin/env bash

# Display function usage
function usage(){
    echo >&2
    echo "Usage: $0 gs://BUCKET_NAME/" >&2
    echo "Prunes the fixity table of references to objects that were deleted in the bucket." >&2
    echo >&2
}

BUCKET_NAME=${1?$(usage)}
BUCKET_LIST=$(gsutil ls -r $1**)
HISTORY_TABLE=fixity_data.fixity_history
PRUNE_TABLE=fixity_data.fixity_history_prune$$
PRUNE_QUERY="\
SELECT DISTINCT a.* FROM $HISTORY_TABLE as a \
    INNER JOIN (SELECT object_url as ou FROM $PRUNE_TABLE) as p \
    ON a.object_url = p.ou \
UNION ALL \
SELECT b.* FROM $HISTORY_TABLE as b \
    WHERE STARTS_WITH(b.object_url, 'gs://')
    AND NOT STARTS_WITH(b.object_url, '$BUCKET_NAME') \
"

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

function run_prune_query {
    echo $PRUNE_QUERY | bq query --use_legacy_sql=false --replace --destination_table=fixity_data.fixity_history -n0
}

echo Making temporary table $PRUNE_TABLE ...
bq mk $PRUNE_TABLE object_url:string,md5:string,checked:timestamp
echo Inserting objects from the bucket listing into the table...
object_json | bq insert $PRUNE_TABLE
echo Running pruning query...
run_prune_query
echo Cleaning up temporary table $PRUNE_TABLE ...
bq rm -f $PRUNE_TABLE