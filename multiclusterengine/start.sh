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

printf "Find snapshot tags @ ${_WEB_REPO}\nEnter SNAPSHOT TAG: \n"
read -e -r SNAPSHOT_CHOICE

if [[ ! -n "${SNAPSHOT_CHOICE}" ]]; then
    echo "ERROR: Make sure you are provide a valid SNAPSHOT"
    exit 1
else 
    echo "SNAPSHOT_CHOICE is set to ${SNAPSHOT_CHOICE}"
fi

IMG="${_REPO}:${SNAPSHOT_CHOICE}" yq eval -i '.spec.image = env(IMG)' catalogsources/multicluster-engine.yaml
VER="${SNAPSHOT_CHOICE:0:3}" yq eval -i '.spec.channel = "stable-"+ env(VER)' multiclusterengine/operator/subscription.yaml
oc apply -f catalogsources/multicluster-engine.yaml
oc create ns multicluster-engine --dry-run=client -o yaml | oc apply -f -
oc apply -k multiclusterengine/operator/

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
