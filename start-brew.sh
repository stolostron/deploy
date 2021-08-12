#!/bin/bash

# Copyright 2020, 2021 Red Hat Inc.


# Based on the brew registry deploy process outlined in https://docs.engineering.redhat.com/display/CFC/Test


#-----BOOTSTRAP HELPERS-----#
source helpers.sh


#-----PREPARATION & VARS-----#
# Handle missing utilities, input validation, and preconfiguration

#### Fix sed on MacOS - we need gsed
OS=$(uname -s | tr '[:upper:]' '[:lower:]');
SED="sed";
if [ "${OS}" == "darwin" ]; then
    SED="gsed";
    if [ ! -x "$(command -v ${SED})"  ]; then
       errorf "${RED}ERROR: $SED required, but not found.${CLEAR}\n";
       printf "${BLUE}Perform \"brew install gnu-sed\" and try again.${CLEAR}";
       exit 1;
    fi;
fi;

#### Populate and/or Validate Parameters
# The catalogsource's image repo and name - CatalogSource will reference 'image: ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}'
# Make sure you know what you're doing if you edit the repo, this could mess up environment validation!
CATALOGSOURCE_REPO=${CATALOGSOURCE_REPO:-"brew.registry.redhat.io/rh-osbs"};
CATALOGSOURCE_BASE_REPO=$(echo ${CATALOGSOURCE_REPO} | awk 'BEGIN { FS = "/" } ; { print $1 }'); # Get just the base Registry for validation

# The catalogsource's image name - CatalogSource will reference 'image: ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}'
CATALOGSOURCE_IMAGE=${CATALOGSOURCE_IMAGE:-"iib-pub-pending"};

# The catalogsoruce's image tag - CatalogSource will reference 'image: ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}'
CATALOGSOURCE_TAG=${CATALOGSOURCE_TAG:-"v4.7"};

# The Namespace in which to deploy the operator and RHACM
TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"};

# ACM Release Channel to Deploy - we can't detect it because we don't have a snapshot from which to derive a release
SUBSCRIPTION_CHANNEL=${CHANNEL:-"release-2.3"};

# Name of the CatalogSource resource we'll create
CATALOGSOURCE_RESOURCE_NAME=${CATALOGSOURCE_RESOURCE_NAME:-"start-brew-iib"};

# Name of the Subscription resource we'll create
SUBSCRIPTION_NAME=${SUBSCRIPTION_NAME:-"start-brew-sub"};


#-----PREAMBLE-----#
#### Tell the user where we're about to operate
CLUSTER_API_URL=$(oc cluster-info | sed -n "s;.*\(https://api.*\:6443\).*;\1;p");
printf "Using cluster with api running at ${BLUE}$CLUSTER_API_URL${CLEAR}.\n";
printf "Targetting namespace ${YELLOW}${TARGET_NAMESPACE}${BLUE} for Operator Deploy${CLEAR}\n"
printf "ACM Deploy will use the CatalogSource image ${BLUE}${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}/${CATALOGSOURCE_TAG}${CLEAR} with release channel ${BLUE}${SUBSCRIPTION_CHANNEL}${CLEAR}\n"


#-----VALIDATE ENVIRONMENT-----#
# Verify that the environment is ready for a deploy from $CATALOGSOURCE_REPO

#### Validate that we have a non-null pull secret
if [[ $(oc get secret/pull-secret -n openshift-config -o json | jq -r '.data.".dockerconfigjson"' | base64 -d | jq -r --arg CS $CATALOGSOURCE_BASE_REPO '.auths[$CS].auth') != "null" ]]; then
    printf "${GREEN}secret/pull-secret in the openshift-config namespace is already configured with a pull secret for ${CATALOGSOURCE_BASE_REPO}.${CLEAR}\n";
else
    errorf "${RED}secret/pull-secret in the openshift-config namespace is not configured with a pull secret for ${CATALOGSOURCE_BASE_REPO}.  Exiting.${CLEAR}\n";
    errorf "${YELLOW}To update this pull secret, follow the process documented in https://docs.engineering.redhat.com/display/CFC/Test${CLEAR}\n";
    exit 1;
fi;

#### validate that the ICSP is configured for $CATALOGSOURCE_REPO
if [[ $(oc get imagecontentsourcepolicy -o json | jq -r '.items[].spec.repositoryDigestMirrors[].mirrors[]' | grep ${CATALOGSOURCE_BASE_REPO}) ]]; then
    printf "${GREEN}Cluster already configured with an ICSP targetting ${CATALOGSOURCE_BASE_REPO} as a mirror.${CLEAR}\n";
else
    errorf "${RED}ICSP not configured for ${CATALOGSOURCE_BASE_REPO}, exiting.${CLEAR}\n";
    errorf "${YELLOW}Apply the ICSP documented in https://docs.engineering.redhat.com/display/CFC/Test and re-run.${CLEAR}\n"
    exit 1
fi


#-----DISABLE OLD CATALOGSOURCE-----#
#### Disables the standard CatalogSource on the OpenShift cluster in preparation for our catalog deploy
printf "${BLUE}Disabling all pre-existing CatalogSource(s).\n${CLEAR}";
printf "${YELLOW}";
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources","value": true}]';
printf "${CLEAR}";


#-----CREATE THE NS-----#
#### Create NS
printf "${BLUE}Creating the NS ${TARGET_NAMESPACE}\n${CLEAR}";
printf "${YELLOW}"
oc create ns ${TARGET_NAMESPACE}
printf "${CLEAR}"


#-----DEPLOY THE CATALOGSOURCE-----#
#### Disables the standard CatalogSource on the OpenShift cluster in preparation for our catalog deploy
printf "${BLUE}Deploying the CatalogSource for ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}\n${CLEAR}";
printf "${YELLOW}"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: start-brew-iib
  namespace: ${TARGET_NAMESPACE}
spec:
  sourceType: grpc
  image: ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}
  displayName: Start Brew iib ${CATALOGSOURCE_TAG}
  publisher: grpc
EOF
printf "${CLEAR}"


#-----CREATING THE OPERATORGROUP-----#
#### Create an OperatorGroup
printf "${BLUE}Creating the 'default' OperatorGroup in ${TARGET_NAMESPACE}\n${CLEAR}";
printf "${YELLOW}"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: default
  namespace: ${TARGET_NAMESPACE}
spec:
  targetNamespaces:
  - ${TARGET_NAMESPACE}
EOF
printf "${CLEAR}"


#-----CREATE A SUBSCRIPTION TO THE NEW CATALOG SOURCE-----#
## Create the Subscription
printf "${BLUE}Creating the operator subscripton for ACM.\n${CLEAR}";
printf "${YELLOW}"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${SUBSCRIPTION_NAME}
  namespace: ${TARGET_NAMESPACE}
spec:
  channel: ${SUBSCRIPTION_CHANNEL}
  installPlanApproval: Automatic
  name: advanced-cluster-management
  source: ${CATALOGSOURCE_RESOURCE_NAME}
  sourceNamespace: ${TARGET_NAMESPACE}
EOF
printf "${CLEAR}"


#-----WAIIT FOR OPERATOR TO BECOME AVAILABLE-----#
#### Use our helper to wait for the operator
waitForPod "multiclusterhub-operator" "${SUBSCRIPTION_NAME}"


#-----CREATE A MULTICLUSTERHUB-----#
#### Create the Subscription
printf "${BLUE}Creating the operator subscripton for ACM.\n${CLEAR}";
printf "${YELLOW}"
oc apply -f - <<EOF
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: ${TARGET_NAMESPACE}
  annotations: {}
spec: {}
EOF
printf "${CLEAR}"


#-----WAIT FOR THE MCH INSTALL TO COMPLETE-----#
#### Use our helper to wait for the multicluster-operators-application to become ready
waitForPod "multicluster-operators-application" ""

#### Poll for the MCH status to become ready
printf "${BLUE}Polling MCH status.${CLEAR}\n"
poll_mch

#### Enable Search
printf "${BLUE}Enabling Search${CLEAR}\n"
printf "${YELLOW}"
oc set env deploy search-operator DEPLOY_REDISGRAPH="true" -n ${TARGET_NAMESPACE}
printf "${CLEAR}"


#-----FIN-----#
printf "${GREEN}Deploy Complete.\n${CLEAR}"
