#!/bin/bash

printf "This will reset the yaml manifests in this dir to be able to execute ./start.sh again.\n"
printf "To continue press ENTER:"
read -r CONTINUE
if [ "${CONTINUE}" == "" ]; then
    git checkout -- cluster-deployment.yaml
    git checkout -- managed-cluster.yaml
    git checkout -- klusterlet-addon-config.yaml
    git checkout -- imageset.yaml
    git checkout -- install-config.yaml
    git checkout -- kustomization.yaml
    git checkout -- machine-pool.yaml
    git checkout -- namespace.yaml
else
    printf "Reset Canceled"
fi