#!/bin/bash

# Copyright 2020 Red Hat Inc.

#Command Line param's
# ./start.sh -t, this exits after modifying the files but not apply any of the yaml
# ./start.sh --silent, this skips any questions, using the local files to apply the snapshot and secret
# ./start.sh --watch, this monitors for status during the main deploy of Red Hat ACM

# CONSTANTS
TOTAL_POD_COUNT_1X=35
TOTAL_POD_COUNT_2X=55

function waitForPod() {
    FOUND=1
    MINUTE=0
    podName=$1
    ignore=$2
    running="$3"
    printf "\n#####\nWait for ${podName} to reach running state (4min).\n"
    while [ ${FOUND} -eq 1 ]; do
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            echo "Timeout waiting for the ${podName}. Try cleaning up using the uninstall scripts before running again."
            echo "List of current pods:"
            oc -n ${TARGET_NAMESPACE} get pods
            echo
            echo "You should see ${podName}, multiclusterhub-repo, and multicloud-operators-subscription pods"
            exit 1
        fi
        if [ "$ignore" == "" ]; then
            operatorPod=`oc -n ${TARGET_NAMESPACE} get pods | grep ${podName}`
        else
            operatorPod=`oc -n ${TARGET_NAMESPACE} get pods | grep ${podName} | grep -v ${ignore}`
        fi
        if [[ "$operatorPod" =~ "${running}     Running" ]]; then
            echo "* ${podName} is running"
            break
        elif [ "$operatorPod" == "" ]; then
            operatorPod="Waiting"
        fi
        echo "* STATUS: $operatorPod"
        sleep 3
        (( MINUTE = MINUTE + 3 ))
    done
}

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

# if using --watch option on mac make sure watch is installed
if [[ " $@ " =~ " --watch " ]]; then
    if [ ! -x "$(command -v watch)" ]; then
        echo "ERROR: watch required, but not found."
        if [ "${OS}" == "darwin" ]; then
            echo "Perform \"brew install watch\" and try again."
        fi
        exit 1
    fi
fi

#TARGET_NAMESPACE should be adjustable in the future
TARGET_NAMESPACE=open-cluster-management

#This is needed for the deploy
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

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

if [ ! -f ./prereqs/pull-secret.yaml ]; then
    echo "SECURITY NOTICE: The encrypted dockerconfigjson is stored in ./prereqs/pull-secret.yaml. If you want to change the value, delete the file and run start.sh"
    echo "Enter the encrypted .dockerconfigjson"
    read -r QUAY_TOKEN
    echo "Writing .prereqs/pull-secret.yaml"
cat <<EOF > ./prereqs/pull-secret.yaml
apiVersion: v1
data:
  .dockerconfigjson: ${QUAY_TOKEN}
kind: Secret
metadata:
  name: multiclusterhub-operator-pull-secret
type: kubernetes.io/dockerconfigjson
EOF

fi

DEFAULT_SNAPSHOT="MUST_PROVIDE_SNAPSHOT"
if [ -f ./snapshot.ver ]; then
    DEFAULT_SNAPSHOT=`cat ./snapshot.ver`
elif [[ " $@ " =~ " --silent " ]]; then
    echo "ERROR: Silent mode will not work when ./snapshot.ver is missing"
    exit 1
fi

if [[ " $@ " =~ " --silent " ]]; then
    echo "* Silent mode"
else
    printf "Find snapshot tags @ https://quay.io/repository/open-cluster-management/acm-custom-registry?tab=tags\nEnter SNAPSHOT TAG: (Press ENTER for default: ${DEFAULT_SNAPSHOT})\n"
    read -r SNAPSHOT_CHOICE
    if [ "${SNAPSHOT_CHOICE}" != "" ]; then
        DEFAULT_SNAPSHOT=${SNAPSHOT_CHOICE}
        printf "${DEFAULT_SNAPSHOT}" > ./snapshot.ver
    fi
fi
if [ "${DEFAULT_SNAPSHOT}" == "MUST_PROVIDE_SNAPSHOT" ]; then
    echo "ERROR: Please specify a valid snapshot tag to continue."
    exit 2
fi
SNAPSHOT_PREFIX=${DEFAULT_SNAPSHOT%%\-*}

# Set the custom registry repo, defaulted to quay.io/open-cluster-management, but accomodate custom config focused on quay.io/acm-d for donwstream tests
CUSTOM_REGISTRY_REPO=${CUSTOM_REGISTRY_REPO:-"quay.io/open-cluster-management"}

# If the user sets the COMPOSITE_BUNDLE flag to "true", then set to the `acm` variants of variables, otherwise the multicluster-hub version.  
if [[ "$COMPOSITE_BUNDLE" == "true" ]]; then OPERATOR_DIRECTORY="dev/acm-operator"; else OPERATOR_DIRECTORY="dev/multicluster-hub-operator"; fi;
if [[ "$COMPOSITE_BUNDLE" == "true" ]]; then CUSTOM_REGISTRY_IMAGE="acm-custom-registry"; else CUSTOM_REGISTRY_IMAGE="multicluster-hub-custom-registry"; fi;

# Set the subscription channel if the variable wasn't defined as input, defaulted to snapshot-<release-version>
if [ -z "$SUBSCRIPTION_CHANNEL" ]; then
    SUBSCRIPTION_CHANNEL_VERSION=$(echo ${SNAPSHOT_PREFIX} | ${SED} -nr "s/v{0,1}([0-9]+\.[0-9]+)\.{0,1}[0-9]*.*/\1/p")
    if [[ "$COMPOSITE_BUNDLE" == "true" ]]; then 
        SUBSCRIPTION_CHANNEL_PREFIX="release"; 
    else 
        SUBSCRIPTION_CHANNEL_PREFIX="snapshot";
    fi;

    SUBSCRIPTION_CHANNEL="${SUBSCRIPTION_CHANNEL_PREFIX}-${SUBSCRIPTION_CHANNEL_VERSION}"

    if [[ ! ( $SUBSCRIPTION_CHANNEL_VERSION =~ [0-9]+\.[0-9]+ ) ]]; then
        echo "Failed to detect SUBSCRIPTION_CHANNEL, we detected ${SUBSCRIPTION_CHANNEL} which doesn't seem correct.  Try exporting SUBSCRIPTION_CHANNEL and rerunning."
        exit 1
    fi
fi

echo "* Downstream: ${DOWNSTREAM}   Release Version: $SNAPSHOT_PREFIX"
echo "* Composite Bundle: $COMPOSITE_BUNDLE   Image Registry (CUSTOM_REGISTRY_REPO): $CUSTOM_REGISTRY_REPO"
if [[ (! $SNAPSHOT_PREFIX == *.*.*) && ("$DOWNSTREAM" != "true") ]]; then
    echo "ERROR: invalid SNAPSHOT format... snapshot must begin with 'X.0.0-' not '$SNAPSHOT_PREFIX', if DOWNSTREAM isn't set"
    exit 1
fi

# Change our expected pod count based on what version snapshot we detect, defaulting to 1.0 (smallest number of pods as of writing)
if [[ $DEFAULT_SNAPSHOT == 1.0* ]]; then
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_1X}
elif [[ $DEFAULT_SNAPSHOT =~ v{0,1}2\.[0-9]+\.[0-9]+.* ]]; then
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_2X}
else
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_1X}
    echo "Snapshot doesn't contain a version number we recognize, looking for the 1.X release pod count of ${TOTAL_POD_COUNT} if wait is selected."
fi

printf "* Using: ${DEFAULT_SNAPSHOT}\n\n"

echo "* Applying SNAPSHOT to multiclusterhub-operator subscription"
${SED} -i "s/newTag: .*$/newTag: ${DEFAULT_SNAPSHOT}/g" ./$OPERATOR_DIRECTORY/kustomization.yaml
echo "* Applying CUSTOM_REGISTRY_REPO to multiclusterhub-operator subscription"
${SED} -i "s|newName: .*$|newName: ${CUSTOM_REGISTRY_REPO}/${CUSTOM_REGISTRY_IMAGE}|g" ./$OPERATOR_DIRECTORY/kustomization.yaml
#echo "* Applying SUBSCRIPTION_CHANNEL to multiclusterhub-operator subscription"
#${SED} -i "s|channel: .*$|channel: ${SUBSCRIPTION_CHANNEL}|g" ./$OPERATOR_DIRECTORY/subscription.yaml
echo "* Applying multicluster-hub-cr values"
${SED} -i "s/example-multiclusterhub/multiclusterhub/" ./multiclusterhub/example-multiclusterhub-cr.yaml
${SED} -i "s|\"mch-imageRepository\": .*$|\"mch-imageRepository\": \"${CUSTOM_REGISTRY_REPO}\"|g" ./multiclusterhub/example-multiclusterhub-cr.yaml

if [[ " $@ " =~ " -t " ]]; then
    echo "* Test mode, see yaml files for updates"
    exit 0
fi

printf "\n##### Creating the $TARGET_NAMESPACE namespace\n"
kubectl create ns $TARGET_NAMESPACE

seconds=0
while [ -z $(kubectl get sa -n $TARGET_NAMESPACE -o name default) ]; do
    echo "--- waiting for namespace: $TARGET_NAMESPACE to create with default service account ---"
    sleep 10
    (( seconds=seconds+10 ))
    if [ "$seconds" -gt 60 ]; then
        echo "--- waited 60 seconds for namespace: $TARGET_NAMESPACE but it never came up with default service account, exiting ---"
        exit 1;
    fi
done;

if [[ "$COMPOSITE_BUNDLE" != "true" ]]; then
    printf "\n##### Applying community operator subscriptions\n"
    oc apply -k community-subscriptions -n ${TARGET_NAMESPACE} 
fi

printf "\n##### Applying prerequisites\n"
kubectl apply --openapi-patch=true -k prereqs/

printf "\n##### Applying $OPERATOR_DIRECTORY subscription #####\n"
kubectl apply -k $OPERATOR_DIRECTORY/
#waitForPod "multiclusterhub-operator" "${CUSTOM_REGISTRY_IMAGE}" "1/1"
printf "\n* Beginning deploy...\n"

printf "\n##### Give registry two minutes to come up ######\n"
sleep 120

echo "* Deploy Installer Test Image for the install/uninstall of Red Hat Advanced Cluster Management for Kubernetes"

set -e

SUBSCRIPTION_NAME="advanced-cluster-management"
PULL_SECRET_NAME="multiclusterhub-operator-pull-secret"

if [ ! -z "$INSTALLER_IMAGE_TAG_OVERRIDE" ]; then
  INSTALLER_IMAGE_TAG="$INSTALLER_IMAGE_TAG_OVERRIDE"
else
  INSTALLER_IMAGE_TAG="$DEFAULT_SNAPSHOT"
fi

docker run --network host \
	--env pullSecret=${PULL_SECRET_NAME} \
	--env source=${CUSTOM_REGISTRY_IMAGE} \
	--env channel=${SUBSCRIPTION_CHANNEL} \
	--env sourceNamespace=${TARGET_NAMESPACE} \
	--env name=${SUBSCRIPTION_NAME} \
	--env TEST_MODE=${TEST_MODE} \
	--env full_test_suite="false" \
	--env waitInMinutes=10 \
	--env mchImageRepository=${CUSTOM_REGISTRY_REPO} \
	--volume ${KUBECONFIG}:/opt/.kube/config \
	--volume ${RESULTS_DIR}:/go/src/github.com/open-cluster-management/multicloudhub-operator/test/results/ \
	quay.io/open-cluster-management/multiclusterhub-operator-tests:${INSTALLER_IMAGE_TAG}

ls -la ${RESULTS_DIR}

echo "#####"
echo "* Red Hat ACM URL: https://multicloud-console.apps.${HOST_URL}"
echo "#####"
if [ "${OS}" == "darwin" ]; then
    if [ ! -x "$(command -v watch)" ]; then
       echo "NOTE: watch executable not found.  Perform \"brew install watch\" to use the command above or use \"./start.sh --watch\" "
    fi
else
  echo "Deploying, use \"watch oc -n ${TARGET_NAMESPACE} get pods\" to monitor progress. Expect around ${TOTAL_POD_COUNT} pods"
fi


