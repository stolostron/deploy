#!/bin/bash
# Copyright Contributors to the Open Cluster Management project

set -e

DOWNSTREAM=${DOWNSTREAM:-"false"}
_REGISTRY="quay.io/stolostron"
_IMAGE_NAME="cmb-custom-registry"

if [ $DOWNSTREAM == "true" ]; then
    _REGISTRY="quay.io/acm-d"
    _IMAGE_NAME="mce-custom-registry"
fi

_REPO="${_REGISTRY}/${_IMAGE_NAME}"
_WEB_REPO="https://${_REPO}?tab=tags"


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

# This is needed for the deploy
echo "* Testing connection"
HOST_URL=`oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "ERROR: Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 2
fi
#Shorten to the basedomain
HOST_URL=${HOST_URL/apps./}
echo "* Using baseDomain: ${HOST_URL}"
VER=`oc version | grep "Client Version:"`
echo "* oc CLI ${VER}"

if [ -f ./snapshot.ver ]; then
    SNAPSHOT_CHOICE=`cat ./snapshot.ver`
elif [[ " $@ " =~ " --silent " ]]; then
    echo "ERROR: Silent mode will not work when ./snapshot.ver is missing"
    exit 1
fi

if [[ " $@ " =~ " --silent " ]]; then
    echo "* Silent mode"
else
    printf "Find snapshot tags @ ${_WEB_REPO}\nEnter SNAPSHOT TAG: \n"
    read -e -r SNAPSHOT_CHOICE
fi

if [[ ! -n "${SNAPSHOT_CHOICE}" ]]; then
    echo "ERROR: Make sure you are provide a valid SNAPSHOT"
    exit 1
else
    echo "SNAPSHOT_CHOICE is set to ${SNAPSHOT_CHOICE}"
fi

SUBSCRIPTION_CHANNEL_VERSION=$(echo ${SNAPSHOT_CHOICE} | ${SED} -nr "s/v{0,1}([0-9]+\.[0-9]+)\.{0,1}[0-9]*.*/\1/p")
if [[ ! ( $SUBSCRIPTION_CHANNEL_VERSION =~ [0-9]+\.[0-9]+ ) ]]; then
    echo "Failed to detect SUBSCRIPTION_CHANNEL_VERSION, we detected ${SUBSCRIPTION_CHANNEL_VERSION} which doesn't seem correct.  Try exporting SUBSCRIPTION_CHANNEL_VERSION and rerunning."
    exit 1
fi

OPERATOR_DIRECTORY=multiclusterengine/operator/
echo "* Applying SUBSCRIPTION_CHANNEL $SUBSCRIPTION_CHANNEL_VERSION to multiclusterengine-operator subscription"
${SED} -i "s|channel: .*$|channel: stable-${SUBSCRIPTION_CHANNEL_VERSION}|g" ./$OPERATOR_DIRECTORY/subscription.yaml

IMG="${_REPO}:${SNAPSHOT_CHOICE}" yq eval -i '.spec.image = env(IMG)' catalogsources/multicluster-engine.yaml
VER="${SNAPSHOT_CHOICE:0:3}" yq eval -i '.spec.channel = "stable-"+ env(VER)' multiclusterengine/operator/subscription.yaml
oc apply -f catalogsources/multicluster-engine.yaml
oc create ns multicluster-engine --dry-run=client -o yaml | oc apply -f -
oc apply -k $OPERATOR_DIRECTORY

CSVName=""
for run in {1..10}; do
  output=$(oc get sub multicluster-engine -n multicluster-engine -o jsonpath='{.status.currentCSV}' >> /dev/null && echo "exists" || echo "not found")
  if [ "$output" != "exists" ]; then
    sleep 2
    continue
  fi
  CSVName=$(oc get sub -n multicluster-engine multicluster-engine -o jsonpath='{.status.currentCSV}')
  if [ "$CSVName" != "" ]; then
    break
  fi
  sleep 10
done


_apiReady=0
echo "* Using CSV: ${CSVName}"
for run in {1..10}; do
  sleep 10
  output=$(oc get csv -n multicluster-engine $CSVName -o jsonpath='{.status.phase}' >> /dev/null && echo "exists" || echo "not found")
  if [ "$output" != "exists" ]; then
    continue
  fi
  phase=$(oc get csv -n multicluster-engine $CSVName -o jsonpath='{.status.phase}')
  if [ "$phase" == "Succeeded" ]; then
    _apiReady=1
    break
  fi
  echo "Waiting for CSV to be ready"
done

if [ $_apiReady -eq 1 ]; then
  oc apply -f multiclusterengine/multicluster_v1alpha1_multiclusterengine.yaml
  echo "multiclusterengine installed successfully"
else
  echo "multiclusterengine subscription could not install in the allotted time."
  exit 1
fi
