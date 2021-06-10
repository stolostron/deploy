#!/bin/bash

# Parameters
# -k, --keep-providers Keeping all provider connections that are not in Advanced Cluster Management namespaces.


KEEP_PROVIDERS=0

# save args to pass to called scripts
args=("$@")

# Parse command line arguments
for arg in "$@"
do
    case $arg in
        -k|--keep-providers)
        KEEP_PROVIDERS=1
        shift
        ;;
        *)
        echo "Unrecognized argument: $1"
        shift
        ;;
    esac
done


# Make sure `oc login` has been done and `oc` command is working
echo "Testing connection"
oc version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 1
fi

VER=$(oc version | grep "Client Version:")

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

printf "\n"
echo "This script will uninstall Open Cluster Management from the current OpenShift target cluster:"
printf "\n"
oc cluster-info | head -n 1 | awk '{print $NF}'
printf "\n"

./clean-clusters.sh "$args"

kubectl delete -k multiclusterhub/
echo "Sleeping for 200 seconds to allow resources to finalize ..."
sleep 200

kubectl delete -k multicluster-hub-operator/
./multicluster-hub-operator/uninstall.sh

kubectl delete -k acm-operator/
./acm-operator/uninstall.sh

kubectl delete -k community-subscriptions/

echo "Cleaning up the open-cluster-management namespace.."
oc delete namespace open-cluster-management

exit 0
