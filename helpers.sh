#!/bin/bash
# Helpers utilized by the deploy project.  Useful bash functions we've built for re-use.

# Color codes for bash output
# 'export COLOR=false' to disable colorized output
BLUE='\e[36m';
GREEN='\e[32m';
RED='\e[31m';
YELLOW='\e[33m';
CLEAR='\e[39m';
if [[ "$COLOR" == "False" || "$COLOR" == "false" ]]; then
    BLUE='\e[39m';
    GREEN='\e[39m';
    RED='\e[39m';
    YELLOW='\e[39m';
fi

#### Error function for printing error messages to stderr
function errorf() {
    # A function to print a message to stderr
    printf >&2 "$@"
}

#### Wait for a pod to become available
function waitForPod() {
    # A function to wait for a pod to become ready.  Specialized to deploy purposes.
    # Arguments:
    #       podname ($1) - the name of the pod to poll for
    #       ignore  ($2) - pod names to ignore (grep string)
    FOUND=1
    MINUTE=0
    podName=$1
    ignore=$2
    running="\([0-9]\+\)\/\1"
    printf "${BLUE}Waiting for ${podName} to reach running state (4min).\n${CLEAR}"
    while [ ${FOUND} -eq 1 ]; do
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            printf "${YELLOW}Timeout waiting for the ${podName}. Try cleaning up using the uninstall scripts before running again.${CLEAR}\n"
            printf "${YELLOW}List of current pods:${CLEAR}\n"
            printf "${YELLOW}"
            oc -n ${TARGET_NAMESPACE} get pods
            printf "${CLEAR}"
            printf "${BLUE}You should see ${podName}, multiclusterhub-repo, and multicloud-operators-subscription pods.${CLEAR}\n"
            exit 1
        fi
        if [ "$ignore" == "" ]; then
            operatorPod=`oc -n ${TARGET_NAMESPACE} get pods | grep ${podName}`
        else
            operatorPod=`oc -n ${TARGET_NAMESPACE} get pods | grep ${podName} | grep -v ${ignore}`
        fi
        if [[ $(echo $operatorPod | grep "${running}") ]]; then
            printf "${BLUE}* ${podName} is running${CLEAR}\n"
            break
        elif [ "$operatorPod" == "" ]; then
            operatorPod="Waiting"
        fi
        printf "${BLUE}* STATUS: $operatorPod${CLEAR}\n"
        sleep 3
        (( MINUTE = MINUTE + 3 ))
    done
}

#### Poll for MCH Status
function poll_mch() {
    # A function to wait for the MCH to reach running status descriptively, timing out after POLL_DURATION
    # Uses a custom POLL_DURATION if the env var is set.
    mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase') 2> /dev/null
    acc=0
    POLL_DURATION=${POLL_DURATION:-"1500"}
    while [[ "$mch_status" != "Running" && $acc -le $POLL_DURATION ]]; do
        printf "${BLUE}Waited $acc/$POLL_DURATION seconds for MCH to reach Ready Status.  Current Status: $mch_status${CLEAR}\n"
        CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
        if [[ "$CONSOLE_URL" != "" ]]; then
            printf "${BLUE}Detected ACM Console URL: https://${CONSOLE_URL}${CLEAR}\n"
        fi;
        printf "${BLUE}#####${CLEAR}\n"
        component_list=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.components')
        printf "${BLUE}%-30s\t%-10s\t%-30s\t%-30s\n${CLEAR}" "COMPONENT" "STATUS" "TYPE" "REASON"
        for status_item in $(echo $component_list | jq -r 'keys | .[]'); do
            component=$(echo $component_list | jq -r --arg ITEM_NAME "$status_item" '.[$ITEM_NAME]')
            component_status="$(echo $component | jq -r '.status')";
            type="$(echo $component | jq -r '.type')";
            reason="$(echo $component | jq -r '.reason')";
            message="$(echo $component | jq -r '.message')";
            printf "${BLUE}%-30s\t%-10s\t%-30s\t%-30s${CLEAR}\n" "$status_item" "$component_status" "$type" "$reason"
        done
        echo ""
        acc=$((acc+30))
        sleep 30
        mch_status=$(oc get multiclusterhub --all-namespaces -o json | jq -r '.items[].status.phase') 2> /dev/null
    done;
    if [[ "$mch_status" != "Running" ]]; then
        COMPLETE=1
    else
        COMPLETE=0
        printf "${GREEN}MCH reached Running status after $acc seconds.${CLEAR}\n"
        CONSOLE_URL=`oc -n ${TARGET_NAMESPACE} get routes multicloud-console -o jsonpath='{.status.ingress[0].host}' 2> /dev/null`
        if [[ "$CONSOLE_URL" != "" ]]; then
            printf "${GREEN}Detected ACM Console URL: https://${CONSOLE_URL}${CLEAR}\n"
        fi;
        echo ""
    fi
}