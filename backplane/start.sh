#!/bin/bash
# Copyright Contributors to the Open Cluster Management project

set -e

_IMAGE_NAME="cmb-custom-registry"
_WEB_REPO="https://quay.io/repository/open-cluster-management/${_IMAGE_NAME}?tab=tags"
_REPO="quay.io/open-cluster-management/${_IMAGE_NAME}"

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

IMG="${_REPO}:${SNAPSHOT_CHOICE}" yq eval -i '.spec.image = env(IMG)' backplane/operator/catalogsource.yaml
oc create ns backplane-operator-system --dry-run=client -o yaml | oc apply -f -
oc apply -k backplane/operator/

CSVName=""
for run in {1..10}; do
  output=$(oc get sub backplane-operator -o jsonpath='{.status.currentCSV}' >> /dev/null && echo "exists" || echo "not found")
  if [ "$output" != "exists" ]; then
    sleep 2
    continue
  fi
  CSVName=$(oc get sub backplane-operator -o jsonpath='{.status.currentCSV}')
  if [ "$CSVName" != "" ]; then
    break
  fi
  sleep 10
done


_apiReady=0
echo "* Using CSV: ${CSVName}"
for run in {1..10}; do
  sleep 10
  output=$(oc get csv $CSVName -o jsonpath='{.status.phase}' >> /dev/null && echo "exists" || echo "not found")
  if [ "$output" != "exists" ]; then
    continue
  fi
  phase=$(oc get csv $CSVName -o jsonpath='{.status.phase}')
  if [ "$phase" == "Succeeded" ]; then
    _apiReady=1
    break
  fi
  echo "Waiting for CSV to be ready"
done

if [ $_apiReady -eq 1 ]; then
  oc apply -f backplane/backplane_v1alpha1_backplaneconfig.yaml
  echo "backplaneconfig installed successfully"
else
  echo "backplaneconfig subscription could not install in the allotted time."
  exit 1
fi
