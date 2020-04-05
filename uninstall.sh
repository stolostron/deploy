#!/bin/bash

VER=$(oc version | grep "Client Version:")

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

echo "This script will uninstall Open Cluster Management from the current OpenShift target cluster:"
printf "\n"
oc cluster-info | head -n 1 | awk '{print $NF}'
printf "\n"

./clean-clusters.sh

kubectl delete -k --ignore-not-found multiclusterhub/
./multiclusterhub/uninstall.sh

kubectl delete -k --ignore-not-found multiclusterhub-operator/
./multiclusterhub-operator/uninstall.sh
