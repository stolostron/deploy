# MultiCluster Engine Operator

Multicluster engine operator installs and manages multicluster components, such as cluster-manager, hive, and other core foundation resources.

## Prereqs

You must meet the following requirements to install the _MultiCluster Engine_:

- An OpenShift Container Platform (OCP) 4.3+ cluster available
  - You must have a default storage class defined
- `oc` (ver. 4.3+) & `kubectl` (ver. 1.16+) configured to connect to your OCP cluster
- `oc` is connected with adequate permissions to create new namespaces in your OCP cluster.


## Getting Started

To install the MultiCluster Engine, call the helper script which will supervise the installation of multicluster components. This script requires a SNAPSHOT tag as input.

0. Follow these presteps if deploying MultiCluster Engine downstream builds:
    1. Follow steps [here](../README.md#deploying-downstream-builds-snapshots-for-product-quality-engineering) to set up ImageContentSourcePolicy and configure the global pull secret.
    2. Set the following environment variable -
    ```bash
    export DOWNSTREAM=true
    ```

1. Run the `./multiclusterengine/start.sh` script in the root directory of this repository
```
$ ./multiclusterengine/start.sh
```

2. When prompted for the SNAPSHOT tag, either press `Enter` to use the previous tag, or provide a new SNAPSHOT tag.
    - UPSTREAM snapshot tags - https://quay.io/repository/stolostron/cmb-custom-registry?tab=tags
    - DOWNSTREAM snapshot tags - https://quay.io/repository/acm-d/mce-custom-registry?tag=latest&tab=tags

After the tag has been provided, the installation will continue. Currently the installation deploys and manages its components in the `multicluster-engine` namespace which it creates.

## Upgrading (Development only)
You can upgrade you UPSTREAM Multicluster Engine with the upgade.sh script.

### Run interactive
1. Run the script
   ```bash
   # Use the optional --watch parameter
   ./upgrade.sh
   ```
2. You will be prompted to enter the snapshot, make sure you choose a `2.0.0-BACKPLANE-...` snapshot
3. If you added the `--watch` parameter, a watch on the pods will start, so you can see the changes.
   * You will ALWAYS see the `multicluster-engine-operator-...` pods (two of them) restart.
   * Any other images that are new to the snapshot will be restarted
   * The pods are sorted with NEWEST last
   * When the `multicluster-engine-operator` restarts, it will apply any CRD changes
4. Press ctrl-c to end the watch!

### Run with no input
1. Run the script, including the snapshot
   ```bash
   export snapshot=2.0.0-BACKPLANE-2022-04-29-01-53-52 && ./upgrade.sh
   ```
2. The upgrade is performed, but the script does not WAIT for any pod change to occur

## Uninstallation

To uninstall the MultiCluster Engine, follow these steps:

1. Delete the multiclusterengine custom resource - 
```
$ oc delete multiclusterengine --all
```
2. Delete the MultiCluster Engine CSV, Subscription, and namespace.

```
$ oc delete csv $(oc get sub multicluster-engine -o jsonpath='{.status.currentCSV}')
$ oc delete sub multicluster-engine
$ oc delete namespace multicluster-engine
```