#!/bin/bash

# Copyright 2021 Red Hat Inc.

# Show the Red Hat Advanced Cluster Management version

# Global Variables with Defaults
TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"}

#This is needed for the deploy
echo "* Testing connection"
HOST_URL=`oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "ERROR: Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 2
fi

#Shorten to the basedomain
HOST_URL=${HOST_URL/apps./}

VERSION=`oc describe pod $(oc get pods -n ${TARGET_NAMESPACE} --no-headers -o custom-columns=":metadata.name" | grep acm-custom-registry) -n ${TARGET_NAMESPACE} | grep "Image:" | tail -n +1 | cut -f 2- -d ':' | tr -d '[:space:]'`

echo "#####"
echo "* Red Hat ACM ${HOST_URL} is running image version ${VERSION}"
echo "#####"
