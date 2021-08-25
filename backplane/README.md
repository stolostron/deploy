# Backplane Operator

Backplane operator installs and manages backplane components, such as cluster-manager, hive, and other core foundation resources.

## Prereqs

You must meet the following requirements to install the _backplane operator_:

- An OpenShift Container Platform (OCP) 4.3+ cluster available
  - You must have a default storage class defined
- `oc` (ver. 4.3+) & `kubectl` (ver. 1.16+) configured to connect to your OCP cluster
- `oc` is connected with adequate permissions to create new namespaces in your OCP cluster.


## Getting Started

To install the Backplane-Operator, call the helper script which will supervise the installation of backplane components. This script requires a SNAPSHOT tag as input.

1. Run the `./backplane/start.sh` script in the root directory of this repository
```
$ ./backplane/start.sh
```

2. When prompted for the SNAPSHOT tag, either press `Enter` to use the previous tag, or provide a new SNAPSHOT tag.
    - UPSTREAM snapshot tags - https://quay.io/repository/open-cluster-management/cmb-custom-registry?tab=tags

After the tag has been provided, the installation will continue. Currently the installation deploys and manages its components in the `backplane-operator-system` namespace which it creates.

## Uninstallation

To uninstall the Backplane-Operator, follow these steps:

1. Delete the backplaneconfig custom resource - 
```
$ oc delete backplaneconfig --all
```
2. Delete the Backplane-Operator CSV, Subscription, and namespace.

```
$ oc delete csv $(oc get sub backplane-operator -o jsonpath='{.status.currentCSV}')
$ oc delete sub backplane-operator
$ oc delete namespace backplane-operator-system
```