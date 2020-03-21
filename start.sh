#!/bin/bash

# Copyright 2020 Red Hat Inc.

#Command Line param's
# ./start.sh -t, this exits after modifying the files but not apply any of the yaml
# ./start.sh --silent, this skips any questions, using the local files to apply the snapshot and secret
# ./start.sh --watch, this monitors for status during the main deploy of Red Hat ACM


function waitForPod() {
    FOUND=1
    MINUTE=0
    podName=$1
    ignore=$2
    runnings="$3"
    echo "Wait for ${podName} to reach running state (4min)."
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
    printf "#####\n\n"
}

# fix sed issue on mac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
SED="sed"
if [ "${OS}" == "darwin" ]; then
    SED="gsed"
    if [ ! -x "$(command -v ${SED})"  ]; then
       echo "This script requires $SED, but it was not found.  Perform \"brew install gnu-sed\" and try again."
       exit
    fi
fi

#TARGET_NAMESPACE should be adjustable in the future
TARGET_NAMESPACE=open-cluster-management

#This is needed for the deploy
echo "* Testing connection"
HOST_URL=`oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "* Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 2
fi
#Shorten to the basedomain
HOST_URL=${HOST_URL/apps./}
echo "* Using baseDomain: ${HOST_URL}"
VER=`oc version | grep "Client Version:"`
echo "* oc CLI ${VER}"

#echo "Pick a namepsace to deploy into"
#read -r TARGET_NAMESPACE
#if [ "$TARGET_NAMESPACE" == "" ]; then
#  TARGET_NAMESPACE=multicluster-system
#fi

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
elif [ "$1" == "--silent" ]; then
    echo "Silent mode will not work when ./snapshot.ver is missing"
    exit 1
fi

if [ "$1" != "--silent" ]; then
    printf "Find snapshot tags @ https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags\nEnter SNAPSHOT TAG: (Press ENTER for default: ${DEFAULT_SNAPSHOT})\n"
    read -r SNAPSHOT_CHOICE
    if [ "${SNAPSHOT_CHOICE}" != "" ]; then
        DEFAULT_SNAPSHOT=${SNAPSHOT_CHOICE}
        printf "${DEFAULT_SNAPSHOT}" > ./snapshot.ver
    fi
fi
if [ "${DEFAULT_SNAPSHOT}" == "MUST_PROVIDE_SNAPSHOT" ]; then
    echo "Please specify a valid snapshot tag to continue."
    exit 2
fi
printf "* Using: ${DEFAULT_SNAPSHOT}\n\n"

echo "* Applying SNAPSHOT to multiclusterhub-operator subscription"
${SED} -i "s/newTag: .*$/newTag: ${DEFAULT_SNAPSHOT}/g" ./multiclusterhub-operator/kustomization.yaml
echo "* Applying multicluster-hub-cr values"
${SED} -i "s/imageTagSuffix: .*$/imageTagSuffix: ${DEFAULT_SNAPSHOT/1.0.0-/}/" ./multiclusterhub/example-multiclusterhub-cr.yaml
${SED} -i "s/example-multiclusterhub/multiclusterhub/" ./multiclusterhub/example-multiclusterhub-cr.yaml

if [ "$1" == "-t" ]; then
    echo "* Test mode, see yaml files for updates"
    exit 0
fi

echo "##### Applying prerequisites"
oc apply -k prereqs/
printf "#####\n\n"

echo "##### Applying multicluster-hub-operator subscription #####"
oc apply -k multiclusterhub-operator/
waitForPod "multiclusterhub-operator" "registry" "1/1"
echo "Beginning deploy..."


echo "* Applying the multiclusterhub-operator to install Red Hat Advanced Cluster Management for Kubernetes"
oc apply -k multiclusterhub
waitForPod "multicluster-operators-application" "" "4/4"
#Issues #1025 = This is needed to work around the fact that the Subscription Operator incluses the clusters.clusterregistry.k8s.io
echo "Remove the clusters.clusterregistry.k8s.io CustomResourceDefinition"
oc get crd clusters.clusterregistry.k8s.io > /dev/null 2>&1
if [ $? -eq 0 ]; then
  oc delete crd clusters.clusterregistry.k8s.io
fi

COMPLETE=1
if [ "$1" == "--watch" ]; then
    for i in {1..60}; do
        clear
        oc -n ${TARGET_NAMESPACE} get pods
        CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
        whatsLeft=`oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" -e "1/1     Running" -e "2/2     Running" -e "3/3     Running" -e "4/4     Running" -e "READY   STATUS" | wc -l`
        if [ "$CONSOLE_URL" == "https://multicloud-console.apps.${HOST_URL}" ] && [ ${whatsLeft} -eq 0 ]; then
            COMPLETE=0
            break
        fi
        echo
        echo "Pods still NOT running  : ${whatsLeft}"
        echo "Detected ACM Console URL: https://${CONSOLE_URL}"
        sleep 10
    done
    if [ $COMPLETE -eq 1 ]; then
        echo "At least one pod failed to start..."
        oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" -e "1/1     Running" -e "2/2     Running" -e "3/3     Running" -e "4/4     Running"
        exit 1
    fi
    echo "#####"
    echo "* Red Hat ACM URL: $CONSOLE_URL"
    echo "#####"
    echo "Done!"
    exit 0
fi

echo "#####"
echo "* Red Hat ACM URL: https://multicloud-console.apps.${HOST_URL}"
echo "#####"
echo "Deploying, use \"watch oc -n ${TARGET_NAMESPACE} get pods\" to monitor progress. Expect around 36 pods"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "${OS}" == "darwin" ]; then
    if [ ! -x "$(command -v watch)"  ]; then
       echo "NOTE: watch executable not found.  Perform \"brew install watch\" to use the command above or use \"./start.sh --watch\" "
    fi
fi
