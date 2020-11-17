#!/bin/bash

TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"}
NEXT_VERSION=${NEXT_VERSION:-"2.1.0"}

# setup starting csv variable using the $NEXT_VERSION parameter
STARTING_CSV="advanced-cluster-management.v${NEXT_VERSION}"

# fix sed issue on mac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
SED="sed"
if [ "${OS}" == "darwin" ]; then
    SED="gsed"
    if [ ! -x "$(command -v ${SED})"  ]; then
       echo "ERROR: $SED required, but not found."
       echo "Perform \"brew install gnu-sed\" and try again."
       exit 1
    fi
fi

# this only changes the channel *IF* we are upgrading a Y version
CHANNEL_VERSION=$(echo ${NEXT_VERSION} | ${SED} -nr "s/v{0,1}([0-9]+\.[0-9]+)\.{0,1}[0-9]*.*/\1/p")
echo "* Applying channel 'release-${CHANNEL_VERSION}' to acm-operator-subscription subscription"
oc patch subscription.operators.coreos.com acm-operator-subscription -n $TARGET_NAMESPACE --type "json" -p "[{\"op\": \"replace\",\"path\": \"/spec/channel\",\"value\":\"release-$CHANNEL_VERSION\"}]"

# wait for install plan to be generated
sleep 20

# Find install plan for upgrade
INSTALL_PLAN=$(oc get InstallPlan -n ${TARGET_NAMESPACE} | grep ${STARTING_CSV} | awk '{print $1;}')
echo "* Found install plan ${INSTALL_PLAN}."

# Patch install plan to set approved to 'true'
echo "* Patching install plan ${INSTALL_PLAN} to set '/spec/approved' to 'true'"
oc patch InstallPlan $INSTALL_PLAN -n $TARGET_NAMESPACE --type "json" -p '[{"op": "replace","path": "/spec/approved","value":true}]'