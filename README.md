# Fixity Verification and Recording Utilities

“Fixity, in the preservation sense, means the assurance that a digital file has remained unchanged, i.e. fixed.”

Though Google Cloud Storage has numerous built-in steps to guard against and correct "bit rot," up to a 99.999999999% data durability guarantee, some customers need to verify data integrity themselves. This solution is for such customers.

It includes a Google Cloud Deployment manager template to make a BigQuery database for storing Cloud Storage archive fixity data, and scripts to automate fixity checks.

# Prerequisites

## Local
- Install [gcloud](https://cloud.google.com/sdk)
- Install [GNU Parallel](https://www.gnu.org/software/parallel/). For example, run `sudo apt install parallel` on Debian/Ubuntu.

## Google Cloud Platform
- Create a (GCP project)[https://cloud.google.com/resource-manager/docs/creating-managing-projects]
- Ensure the BigQuery and Deployment Manager APIs are enabled in the [API Library](https://console.cloud.google.com/apis/library).
- Grant the [`roles/bigquery.dataEditor`, `roles/bigquery.dataOwner` or `roles/bigquery.admin`](https://cloud.google.com/bigquery/docs/access-control) IAM roles to the user or service account you'll be using (check `gcloud info` if you're not sure)
- Similarly, grant `roles/storage.objectViewer` at a minimum. If you also wish to upload objects with a checksum using this utility, you will need `roles/storage.objectAdmin`.

# Installation
From the root directory of this repository, run:

```shell
alias dm="gcloud deployment-manager"
dm deployments create fixitydb --config fixity.yaml
```
Done!

# Initializing

## If you already have data in GCS
You will need to populate the fixity table with entries for every object. Do this by running `bin/populate_fixity_table.sh`. Usage is as follows:

`./populate_fixity_table.sh gs://BUCKET_NAME/`

This will get a listing of all objects in the bucket and perform a streaming insert of null/empty fixity checks into the database for them. If this is the only record of the object in the DB, it will be flagged for a fixity check on the next verification run.

You can also run this script if many objects are later uploaded without fixity records created for them. It will not break the fixity record for existing objects, as they will have non-null entries that will override any null entries added, even if they are added later.

## If you do not have data in GCS
Time to start uploading! Use `bin/fixity_upload.sh`. Usage is as follows:

`./fixity_upload.sh TARGET_GCS_PATH FILES_TO_UPLOAD`

You can specify multiple files, such as:

`./fixity_upload.sh gs://mybucket/clips clips/1 clips/2`

You can use a glob to upload many files, such as:

`./fixity_upload.sh gs://mybucket/clips clips/*`

This script will perform a local checksum of the file and upload it to GCS with the checksum present in the `Content-MD5` header. GCS will checksum the uploaded bytes reject the upload if it doesn't match the header. Since a local and remote checksum are performed, this script finally adds a fixity verification record for the object with the current date and time.

This process is repeated for each file given. Files are processed serially, so for many small files this can be slow, and for large servers not all resources may be put to use. Consider sharding the file content you wish to upload and perform multiple fixity_upload.sh commands, either manually, or with xargs, GNU Parallel, or similar.

# Verifying Fixity
Simply run `bin/verify_fixity.sh`. The script interrogates the BigQuery fixity history table for the most recent verification of all objects, and returns the ones that are older than a certain threshold, along with their last recorded hash.

It then takes that list and performs the following for each:
  - Store the hash from the last fixity check in memory
  - Get the object data, hash it, and store this hash in memory
  - Compare the hashes
      - If they match, record a new verification record
      - If they do not match, exit with an error

# Overriding the latest hash
For testing purposes or other kinds of error recovery, you can use the script at `bin/override_hash.sh` to override the latest hash for an object. Usage is as follows:

`bin/override_hash.sh OBJECT_PATH HASH`

So, for example, to force a hash error on an object, you can run:

`bin/override_hash.sh gs://YOUR_BUCKET/YOUR_OBJECT foo`

This will set the hash to `foo`, which will almost definitely not match a hex-encoded MD5 string, causing the next fixity check of the object to fail.

Similarly, if your fixity record has been corrupted with the wrong hash (such as during a test), you can override the hash to the download hash value calculated during the fixity check to correct it.

`bin/override_hash.sh gs://YOUR_BUCKET/YOUR_OBJECT YOUR_HASH`

# Pruning the history table
If you delete some of your archive, or more likely reorganize it, the fixity table will contain many object URLs that are no longer valid. Such entries will cause validation errors when running the verification script. 

If you expect these errors and can confirm they are false positives, you can run:

`bin/prune_fixity_table.sh BUCKET_NAME`

This will:
    - Create a temporary table
    - List the bucket into the table
    - SELECT...
        - A DISTINCT INNER JOIN of the temp table and the history table, preserving all unique entries for objects currently found
        - UNION these results with all records in the history table for other buckets, discarding any URLs that do not begin with 'gs://'
    - Overwrite the history table with this result set
    - Remove the temporary table

## Important Disclaimer

This code is written by a Googler, but this project is not supported by Google in any way. As the `LICENSE` file says, this work is offered to you on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License.

## License

Apache 2.0 - See [the LICENSE](/LICENSE) for more information.

## Copyright

Copyright 2020 Google, Inc.
