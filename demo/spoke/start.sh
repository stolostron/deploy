#!/bin/bash

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

#This is needed for the deploy
echo "* Testing connection"
HOST_URL=`oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "* Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 2
fi
#Shorten to the basedomain
HOST_URL=${HOST_URL/apps./}
echo "* Using host url: ${HOST_URL}"
VER=`oc version | grep "Client Version:"`
echo "* oc CLI ${VER}"

# read variables from file
if [ ! -f ./local.rc ]; then
    touch local.rc
fi

source local.rc

# cluster name
DEFAULT_CLUSTER_NAME=${CLUSTER_NAME}
if [ "${CLUSTER_NAME}" == "" ]; then
    printf "Enter CLUSTER NAME:\n"
    read -r CLUSTER_NAME_CHOICE
    if [ "${CLUSTER_NAME_CHOICE}" != "" ]; then
        DEFAULT_CLUSTER_NAME=${CLUSTER_NAME_CHOICE}
        echo "CLUSTER_NAME=${DEFAULT_CLUSTER_NAME}" >> ./local.rc
    elif [ "${DEFAULT_CLUSTER_NAME}" == "" ]; then
        echo "Please specify a valid cluster name to continue."
        exit 2
    fi
fi

CLUSTER_NAME=${CLUSTER_NAME}-$RANDOM
printf "using cluster name: ${CLUSTER_NAME}\n"


# cloud region
DEFAULT_CLOUD_REGION="us-east-1"
if [ "${CLOUD_REGION}" == "" ]; then
    printf "Enter CLOUD REGION: (Press ENTER for default: ${DEFAULT_CLOUD_REGION})\n"
    read -r CLOUD_REGION_CHOICE
    if [ "${CLOUD_REGION_CHOICE}" != "" ]; then
        CLOUD_REGION=${CLOUD_REGION_CHOICE}
        echo "CLOUD_REGION=${CLOUD_REGION}" >> local.rc
    fi
fi

CLOUD_REGION=${CLOUD_REGION}
printf "using cloud region: ${CLOUD_REGION}\n"

# aws access key
DEFAULT_AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
if [ "${AWS_ACCESS_KEY}" == "" ]; then
    printf "Enter AWS ACCESS KEY:\n"
    read -r AWS_ACCESS_KEY_CHOICE
    if [ "${AWS_ACCESS_KEY_CHOICE}" != "" ]; then
        DEFAULT_AWS_ACCESS_KEY=${AWS_ACCESS_KEY_CHOICE}
        echo "AWS_ACCESS_KEY=${DEFAULT_AWS_ACCESS_KEY}" >> local.rc
    elif [ "${DEFAULT_AWS_ACCESS_KEY}" == "" ]; then
        echo "Please specify a valid aws access key to continue."
        exit 2
    fi
fi

AWS_ACCESS_KEY=${DEFAULT_AWS_ACCESS_KEY}
printf "using aws access key: ${AWS_ACCESS_KEY}\n"

# aws secret access key
DEFAULT_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
if [ "${AWS_SECRET_ACCESS_KEY}" == "" ]; then
    printf "Enter AWS SECRET ACCESS KEY:\n"
    read -r AWS_SECRET_ACCESS_KEY_CHOICE
    if [ "${AWS_SECRET_ACCESS_KEY_CHOICE}" != "" ]; then
        DEFAULT_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY_CHOICE}
        echo "AWS_SECRET_ACCESS_KEY=${DEFAULT_AWS_SECRET_ACCESS_KEY}" >> local.rc
    elif [ "${DEFAULT_AWS_SECRET_ACCESS_KEY}" == "" ]; then
        echo "Please specify a valid aws secret access key to continue."
        exit 2
    fi
fi

AWS_SECRET_ACCESS_KEY=${DEFAULT_AWS_SECRET_ACCESS_KEY}
printf "using aws secret access key: ${AWS_SECRET_ACCESS_KEY}\n"

# ocp pull secret
if [ "${OCP_PULL_SECRET}" == "" ]; then
    printf "OCP PULL SECRET not set... Please specify OCP_PULL_SECRET in ./local.rc"
    printf "You can download or copy it directly from this link: https://cloud.redhat.com/openshift/install/pull-secret"
    exit 2
fi

printf "using ocp pull secret.\n"

# ssh keys
if [ ! -f ./ssh-privatekey ]; then
    printf "No default ssh-privatekey file found in $(pwd).\n"
    printf "To generate ssh keys in this dir press ENTER."
    read -r SSH_KEYS_CHOICE
    if [ "${SSH_KEYS_CHOICE}" == "" ]; then
        printf "Generating ssh keys..."
        ssh-keygen -f ssh-privatekey -t rsa -Pqo
    else
        printf "No default ssh-privatekey found and user choose not to generate keys..."
        printf "SSH keys are required. exiting."
        exit 2
    fi
fi

printf "* Applying HOST_URL (${HOST_URL}) to ./*.yaml\n"
${SED} -i "s/<HOST_URL>/${HOST_URL}/g" ./cluster-deployment.yaml
${SED} -i "s/<HOST_URL>/${HOST_URL}/g" ./install-config.yaml

printf "* Applying CLUSTER_NAME (${CLUSTER_NAME}) to ./*.yaml\n"
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./cluster-deployment.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./cluster.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./endpoint-config.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./install-config.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./kustomization.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./machine-pool.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./namespace.yaml

printf "* Applying CLOUD_REGION (${CLOUD_REGION}) to ./*.yaml\n"
${SED} -i "s/<CLOUD_REGION>/${CLOUD_REGION}/g" ./cluster-deployment.yaml
${SED} -i "s/<CLOUD_REGION>/${CLOUD_REGION}/g" ./install-config.yaml

printf "* Applying AWS_ACCESS_KEY (${AWS_ACCESS_KEY}) to ./kustomization.yaml\n"
${SED} -i "s/<AWS_ACCESS_KEY>/${AWS_ACCESS_KEY}/g" ./kustomization.yaml

printf "* Applying AWS_SECRET_ACCESS_KEY (${AWS_SECRET_ACCESS_KEY}) to ./kustomization.yaml\n"
${SED} -i "s/<AWS_SECRET_ACCESS_KEY>/${AWS_SECRET_ACCESS_KEY}/g" ./kustomization.yaml

printf "* Applying OCP_PULL_SECRET to ./kustomization.yaml\n"
${SED} -i "s/<OCP_PULL_SECRET>/${OCP_PULL_SECRET}/g" ./kustomization.yaml