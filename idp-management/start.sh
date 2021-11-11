#!/bin/bash
# Copyright Contributors to the Open Cluster Management project

set -e
set -x
DOWNSTREAM=${DOWNSTREAM:-"false"}
_REGISTRY="quay.io/identitatem"
_IMAGE_NAME="idp-mgmt-operator-catalog"

if [ $DOWNSTREAM == "true" ]; then
  #    _REGISTRY="quay.io/acm-d"
  #    _IMAGE_NAME="mce-custom-registry"
  echo "DOWNSTREAM option is not yet supported"
  exit 1
    _REGISTRY="brew.registry.redhat.io"
    _IMAGE_NAME="rh-osbs"
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

printf "Find image tags @ ${_WEB_REPO}\nEnter IMAGE TAG: \n"
read -e -r SNAPSHOT_CHOICE

if [[ ! -n "${SNAPSHOT_CHOICE}" ]]; then
    echo "ERROR: Make sure you are provide a valid IMAGE TAG"
    exit 1
else
    echo "CHOICE is set to ${SNAPSHOT_CHOICE}"
fi

IMG="${_REPO}:${SNAPSHOT_CHOICE}" yq eval -i '.spec.image = env(IMG)' idp-management/operator/catalogsource.yaml

oc create ns idp-mgmt-config --dry-run=client -o yaml | oc apply -f -
oc apply -k idp-management/operator/

CSVName=""
for run in {1..10}; do
  output=$(oc get sub idp-mgmt-config -n idp-mgmt-config -o jsonpath='{.status.currentCSV}' >> /dev/null && echo "exists" || echo "not found")
  if [ "$output" != "exists" ]; then
    sleep 2
    continue
  fi
  CSVName=$(oc get sub -n idp-mgmt-config idp-mgmt-config -o jsonpath='{.status.currentCSV}')
  if [ "$CSVName" != "" ]; then
    break
  fi
  sleep 10
done


_apiReady=0
echo "* Using CSV: ${CSVName}"
for run in {1..10}; do
  sleep 10
  output=$(oc get csv -n idp-mgmt-config $CSVName -o jsonpath='{.status.phase}' >> /dev/null && echo "exists" || echo "not found")
  if [ "$output" != "exists" ]; then
    continue
  fi
  phase=$(oc get csv -n idp-mgmt-config $CSVName -o jsonpath='{.status.phase}')
  if [ "$phase" == "Succeeded" ]; then
    _apiReady=1
    break
  fi
  echo "Waiting for CSV to be ready"
done

if [ $_apiReady -eq 1 ]; then
  echo "identity configuration management installed successfully"
else
  echo "identity configuration management subscription could not install in the allotted time."
  exit 1
fi
