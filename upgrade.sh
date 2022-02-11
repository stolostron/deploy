#!/bin/bash

# CONSTANTS
TOTAL_POD_COUNT_20X=55
TOTAL_POD_COUNT_21X=56
TOTAL_POD_COUNT_22X=60
POLL_DURATION_21X=1500

TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"}
NEXT_VERSION=${NEXT_VERSION:-"2.1.0"}

function waitForInstallPlan() {
    version=$1
    for i in `seq 1 10`; do
        oc get installplan -n ${TARGET_NAMESPACE} | grep "$version"
        if [ $? -eq 0 ]; then
          break
        fi
        echo 'waiting for installplan to show'
        sleep 10
    done
}

function waitForACMRegistryPod() {
    for i in `seq 1 30`; do
    	oc get po -n openshift-marketplace -lolm.catalogSource=acm-custom-registry -oyaml
        oc get po -n openshift-marketplace -lolm.catalogSource=acm-custom-registry -oyaml | grep "$NEXT_SNAPSHOT"
        if [ $? -eq 0 ]; then
          break
        fi
        echo 'waiting for subscription pod to use new image'
        oc get po -n openshift-marketplace -lolm.catalogSource=acm-custom-registry -oyaml | grep "$NEXT_SNAPSHOT"
        echo 'patch again'
        oc patch catalogsource acm-custom-registry -n openshift-marketplace --type=json -p '[{"op":"replace","path":"/spec/image","value":"'${CUSTOM_REGISTRY_REPO}'/acm-custom-registry:'${NEXT_SNAPSHOT}'"}]'

        sleep 20
    done
}

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

oc patch catalogsource acm-custom-registry -n openshift-marketplace --type=json -p '[{"op":"replace","path":"/spec/image","value":"'${CUSTOM_REGISTRY_REPO}'/acm-custom-registry:'${NEXT_SNAPSHOT}'"}]'
waitForACMRegistryPod
echo "Sleeping for 5 minutes to allow deployment to sync"
sleep 300

# this only changes the channel *IF* we are upgrading a Y version
CHANNEL_VERSION=$(echo ${NEXT_VERSION} | ${SED} -nr "s/v{0,1}([0-9]+\.[0-9]+)\.{0,1}[0-9]*.*/\1/p")
echo "* Applying channel 'release-${CHANNEL_VERSION}' to acm-operator-subscription subscription"
echo "* Applying startingCSV \'${STARTING_CSV}\' to acm-operator-subscription subscription"
oc patch subscription.operators.coreos.com acm-operator-subscription -n $TARGET_NAMESPACE --type "json" -p "[{\"op\":\"replace\",\"path\": \"/spec/channel\",\"value\":\"release-$CHANNEL_VERSION\"},{\"op\": \"replace\",\"path\":\"/spec/startingCSV\",\"value\":\"$STARTING_CSV\"}]"

# wait for install plan to be generated
waitForInstallPlan ${NEXT_VERSION}

# Find install plan for upgrade
INSTALL_PLAN=$(oc get InstallPlan -n ${TARGET_NAMESPACE} | grep ${STARTING_CSV} | awk '{print $1;}')
echo "* Found install plan ${INSTALL_PLAN}."

# Patch install plan to set approved to 'true'
echo "* Patching install plan ${INSTALL_PLAN} to set '/spec/approved' to 'true'"
oc patch InstallPlan $INSTALL_PLAN -n $TARGET_NAMESPACE --type "json" -p '[{"op": "replace","path": "/spec/approved","value":true}]'
echo 'wait 180 before checking pods'
sleep 180

# Change our expected pod count based on what version snapshot we detect, defaulting to 1.0 (smallest number of pods as of writing)
if [[ $NEXT_SNAPSHOT =~ v{0,1}2\.0\.[0-9]+.* ]]; then
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_20X}
elif [[ $NEXT_SNAPSHOT =~ v{0,1}2\.1\.[0-9]+.* ]]; then
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_21X}
else
    TOTAL_POD_COUNT=${TOTAL_POD_COUNT_22X}
    echo "Snapshot doesn't contain a version number we recognize, looking for the 2.2.X+ release pod count of ${TOTAL_POD_COUNT} if wait is selected."
fi

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

COMPLETE=1
if [[ $NEXT_SNAPSHOT =~ v{0,1}2\.[1-9][0-9]*\.[0-9]+.* ]]; then
    echo ""
    echo "#####"
    mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase') 2> /dev/null
    acc=0
    while [[ "$mch_status" != "Running" && $acc -le $POLL_DURATION_21X ]]; do
        echo "Waited $acc/$POLL_DURATION_21X seconds for MCH to reach Ready Status.  Current Status: $mch_status"
        CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
        if [[ "$CONSOLE_URL" != "" ]]; then
            echo "Detected ACM Console URL: https://${CONSOLE_URL}"
        fi;
        if [[ "$DEBUG" == "true" ]]; then
            echo "#####"
            component_list=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.components')
            printf "%-30s\t%-10s\t%-30s\t%-30s\n" "COMPONENT" "STATUS" "TYPE" "REASON"
            for status_item in $(echo $component_list | jq -r 'keys | .[]'); do
                component=$(echo $component_list | jq -r --arg ITEM_NAME "$status_item" '.[$ITEM_NAME]')
                component_status="$(echo $component | jq -r '.status')";
                type="$(echo $component | jq -r '.type')";
                reason="$(echo $component | jq -r '.reason')";
                message="$(echo $component | jq -r '.message')";
                printf "%-30s\t%-10s\t%-30s\t%-30s\n" "$status_item" "$component_status" "$type" "$reason"
            done
        fi
        echo ""
        acc=$((acc+30))
        sleep 30
        mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase') 2> /dev/null
    done;
    if [[ "$mch_status" != "Running" ]]; then
        COMPLETE=1
    else
        COMPLETE=0
        echo "MCH reached Running status after $acc seconds."
        CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
        if [[ "$CONSOLE_URL" != "" ]]; then
            echo "Detected ACM Console URL: https://${CONSOLE_URL}"
        fi;
        echo ""
    fi
else
    for i in {1..90}; do
        clear
        oc -n ${TARGET_NAMESPACE} get pods
        CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
        whatsLeft=`oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" -e "1/1     Running" -e "2/2     Running" -e "3/3     Running" -e "4/4     Running" -e "READY   STATUS" | wc -l`
        RUNNING_PODS=$(oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" | tail -n +2 | wc -l | tr -d '[:space:]')
        if [ "https://$CONSOLE_URL" == "https://multicloud-console.apps.${HOST_URL}" ] && [ ${whatsLeft} -eq 0 ]; then
            if [ $RUNNING_PODS -ge ${TOTAL_POD_COUNT} ]; then
                COMPLETE=0
                break
            fi
        fi
        echo
        echo "Number of expected Pods : $RUNNING_PODS/$TOTAL_POD_COUNT"
        echo "Pods still NOT running  : ${whatsLeft}"
        echo "Detected ACM Console URL: https://${CONSOLE_URL}"
        sleep 10
    done
fi
if [ $COMPLETE -eq 1 ]; then
    if [[ $NEXT_SNAPSHOT =~ v{0,1}2\.[1-9][0-9]*\.[0-9]+.* ]]; then
        mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase')
        echo "MCH is in the following state: $mch_status"
        echo "The full MCH status is as follows:"
        component_list=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.components')
        printf "%-30s\t%-10s\t%-30s\t%-30s\n" "COMPONENT" "STATUS" "TYPE" "REASON"
        for status_item in $(echo $component_list | jq -r 'keys | .[]'); do
            component=$(echo $component_list | jq -r --arg ITEM_NAME "$status_item" '.[$ITEM_NAME]')
            component_status="$(echo $component | jq -r '.status')";
            type="$(echo $component | jq -r '.type')";
            reason="$(echo $component | jq -r '.reason')";
            message="$(echo $component | jq -r '.message')";
            printf "%-30s\t%-10s\t%-30s\t%-30s\n" "$status_item" "$component_status" "$type" "$reason"
        done
        echo ""
    else
        echo "At least one pod failed to start..."
        oc -n ${TARGET_NAMESPACE} get pods | grep -v -e "Completed" -e "1/1     Running" -e "2/2     Running" -e "3/3     Running" -e "4/4     Running" -e "5/5     Running"
    fi
    exit 1
else
    echo "#####"
    echo "* Red Hat ACM URL: https://$CONSOLE_URL"
    echo "#####"
fi
echo "Done!"
MCH_FINAL_VERSION_CHECK=`oc get mch -oyaml -n $TARGET_NAMESPACE | grep "currentVersion: $NEXT_VERSION" | wc -l`
if [[ $MCH_FINAL_VERSION_CHECK == 0 ]]; then
    MCH_FINAL_VERSION=`oc get mch -oyaml -n $TARGET_NAMESPACE | grep "currentVersion: [0-9"] | sed 's/[a-zA-Z:]*//g'`
    echo "Upgrade Failed to Complete: $MCH_FINAL_VERSION was found instead of $NEXT_VERSION"
    COMPLETE=1
fi
exit $COMPLETE
