#!/bin/bash

TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"}
NEXT_VERSION=${NEXT_VERSION:-"2.1.0"}

# setup starting csv variable using the $NEXT_VERSION parameter
STARTING_CSV="advanced-cluster-management.v${NEXT_VERSION}"

# Find install plan for upgrade
INSTALL_PLAN=$(oc get InstallPlan -n ${TARGET_NAMESPACE} | grep ${STARTING_CSV} | awk '{print $1;}')
echo "* Found install plan ${INSTALL_PLAN}."

# Patch install plan to set approved to 'true'
echo "* Patching install plan ${INSTALL_PLAN} to set '/spec/approved' to 'true'"
oc patch InstallPlan $INSTALL_PLAN -n $TARGET_NAMESPACE --type "json" -p '[{"op": "replace","path": "/spec/approved","value":true}]'