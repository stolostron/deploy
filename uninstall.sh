#!/bin/bash

echo "This script will uninstall Open Cluster Management from the current OpenShift target cluster:"
oc cluster-info | head -n 1 | awk '{print $NF}'
echo ""

./clean-clusters.sh

kubectl delete -k multiclusterhub/ --ignore-not-found
./multiclusterhub/uninstall.sh

kubectl delete -k multiclusterhub-operator/ --ignore-not-found
./multiclusterhub-operator/uninstall.sh