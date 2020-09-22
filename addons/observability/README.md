## Deploy ACM Observability

- Deploy ACM using the deploy repo [here](../../)
- Create an S3 Bucket
  - non-encrypted
  - no access points needed
- Run [start.sh](./start.sh) from the `addons/observability` folder.
  - provide s3 bucket name
  - provide cloud region where s3 bucket exists
  - provide snapshot to deploy (will use [snapshot.ver](../../snapshot.ver) from deploy repo by default)
  - provide AWS Access Key
  - provide AWS Secret Access Key

Script will apply values to `*.yaml` definitions in the current directory and apply them to the OCP cluster configured with `kubectl`.