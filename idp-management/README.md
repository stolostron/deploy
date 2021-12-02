# identity configuration management for Kubernetes

Identity configuration management for Kubernetes enhances the capabilities of Red Hat Advanced Cluster Management or the multicluster engine for Kubernetes by enabling OpenShift administrators to define their identity provider configuration once in the management hub cluster.  Using simple placement rules, that same configuration can be used across multiple clusters within the fleet.


## Prereqs

You must meet the following requirements to install the _identity configuration management_:

- An OpenShift Container Platform (OCP) 4.8.12+ cluster available
- A signed certificate in use by the hub cluster, see https://identitatem.github.io/idp-mgmt-docs/requirements.html#security-requirements
- ACM 2.4 or MCE 1.0
  - You must have a default storage class defined
- `oc` (ver. 4.6+) configured to connect to your OCP cluster
- `oc` is connected with adequate permissions to create new namespaces in your OCP cluster.


## Getting Started

To install `identity configuration management`, call the helper script, `start.sh`, which will supervise the installation. This script requires a IMAGE tag as input.

0. Follow these presteps if deploying identity configuration management downstream builds:
    1. Follow steps [here](../README.md#deploying-downstream-builds-snapshots-for-product-quality-engineering) to set up ImageContentSourcePolicy and configure the global pull secret.
    2. Set the following environment variable -
    ```bash
    export DOWNSTREAM=true
    ```

1. Run the `./idp-management/start.sh` script in the root directory of this repository
```
$ ./idp-management/start.sh
```

2. When prompted for the IMAGE tag, either press `Enter` to use the previous tag, or provide a new IMAGE tag.
    - UPSTREAM snapshot tags - https://quay.io/repository/identitatem/idp-mgmt-operator-catalog?tab=tags
    - DOWNSTREAM snapshot tags - TODO - For now use: brew.registry.redhat.io/rh-osbs/iib:132957

After the tag has been provided, the installation will continue. Currently the installation deploys and manages its components in the `idp-mgmt-config` namespace which it creates.

## Uninstallation

To uninstall the `identity configuration management`, follow these steps:

1. Delete any remaining AuthRealm custom resource
```
$ oc delete authrealm --all
```
2. Delete the `identity configuration management` CSV, Subscription, and namespace.

```
$ oc delete csv -n idp-mgmt-config $(oc get sub idp-mgmt-operator-product -n idp-mgmt-config -o jsonpath='{.status.currentCSV}')
$ oc delete sub -n idp-mgmt-config idp-mgmt-operator-product
$ oc delete namespace idp-mgmt-config
```
