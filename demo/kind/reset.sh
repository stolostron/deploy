#!/bin/bash

printf "This will reset the yaml manifests in this dir to be able to execute ./start.sh again.\n"
printf "To continue press ENTER:"
read -r CONTINUE
if [ "${CONTINUE}" == "" ]; then
    git checkout -- kind-cluster.yaml
    git checkout -- import/endpoint_operator.yaml
    git checkout -- import/endpoint.yaml
else
    printf "Reset Canceled"
fi