#!/bin/bash

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

./clean-clusters.sh

kubectl delete -k multiclusterhub/
./multiclusterhub/uninstall.sh

kubectl delete -k acm-operator/
./acm-operator/uninstall.sh

exit 0