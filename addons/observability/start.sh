#!/bin/bash

TARGET_NAMESPACE=${TARGET_NAMESPACE:-"open-cluster-management"}

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
echo "* Testing connection to OCP cluster..."
HOST_URL=`oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "* Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 2
fi
VER=`oc version | grep "Client Version:"`
echo "* oc CLI ${VER}"

# read variables from file
if [ ! -f ./local.rc ]; then
    touch local.rc
fi

source local.rc

# bucket name
DEFAULT_BUCKET_NAME=${BUCKET_NAME}
if [ "${BUCKET_NAME}" == "" ]; then
    printf "Enter BUCKET NAME:\n"
    read -r BUCKET_NAME_CHOICE
    if [ "${BUCKET_NAME_CHOICE}" != "" ]; then
        BUCKET_NAME=${BUCKET_NAME_CHOICE}
        echo "" >> ./local.rc
        echo "BUCKET_NAME=${BUCKET_NAME}" >> ./local.rc
    fi
fi

BUCKET_NAME=${BUCKET_NAME}
printf "using bucket name: ${BUCKET_NAME}\n"

# snapshot
DEFAULT_SNAPSHOT=${SNAPSHOT}
if [ -f ../../snapshot.ver ]; then
    DEFAULT_SNAPSHOT=`cat ../../snapshot.ver`
    SNAPSHOT=${DEFAULT_SNAPSHOT}
    echo "" >> ./local.rc
    echo "SNAPSHOT=${DEFAULT_SNAPSHOT}" >> ./local.rc
fi

if [ "${SNAPSHOT}" == "" ]; then
    printf "Enter SNAPSHOT:\n"
    read -r SNAPSHOT_CHOICE
    if [ "${SNAPSHOT_CHOICE}" != "" ]; then
        SNAPSHOT=${SNAPSHOT_CHOICE}
        echo "" >> ./local.rc
        echo "SNAPSHOT=${SNAPSHOT}" >> ./local.rc
    fi
fi

SNAPSHOT=${SNAPSHOT}
printf "using snapshot: ${SNAPSHOT}\n"

# cloud region
DEFAULT_CLOUD_REGION="us-east-1"
if [ "${CLOUD_REGION}" == "" ]; then
    printf "Enter CLOUD REGION: (Press ENTER for default: ${DEFAULT_CLOUD_REGION})\n"
    read -r CLOUD_REGION_CHOICE
    if [ "${CLOUD_REGION_CHOICE}" != "" ]; then
        CLOUD_REGION=${CLOUD_REGION_CHOICE}
        echo "" >> ./local.rc
        echo "CLOUD_REGION=${CLOUD_REGION}" >> local.rc
    fi
fi

CLOUD_REGION=${CLOUD_REGION}
printf "using cloud region: ${CLOUD_REGION}\n"

# aws access key
DEFAULT_AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
if [ "${AWS_ACCESS_KEY}" == "" ]; then
    printf "Enter AWS ACCESS KEY:\n"
    read -r -s AWS_ACCESS_KEY_CHOICE
    if [ "${AWS_ACCESS_KEY_CHOICE}" != "" ]; then
        DEFAULT_AWS_ACCESS_KEY=${AWS_ACCESS_KEY_CHOICE}
        echo "" >> ./local.rc
        echo "AWS_ACCESS_KEY=${DEFAULT_AWS_ACCESS_KEY}" >> local.rc
    elif [ "${DEFAULT_AWS_ACCESS_KEY}" == "" ]; then
        echo "Please specify a valid aws access key to continue."
        exit 2
    fi
fi

AWS_ACCESS_KEY=${DEFAULT_AWS_ACCESS_KEY}
printf "using aws access key: ****\n"

# aws secret access key
DEFAULT_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
if [ "${AWS_SECRET_ACCESS_KEY}" == "" ]; then
    printf "Enter AWS SECRET ACCESS KEY:\n"
    read -r -s AWS_SECRET_ACCESS_KEY_CHOICE
    if [ "${AWS_SECRET_ACCESS_KEY_CHOICE}" != "" ]; then
        DEFAULT_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY_CHOICE}
        echo "" >> ./local.rc
        echo "AWS_SECRET_ACCESS_KEY=${DEFAULT_AWS_SECRET_ACCESS_KEY}" >> local.rc
    elif [ "${DEFAULT_AWS_SECRET_ACCESS_KEY}" == "" ]; then
        echo "Please specify a valid aws secret access key to continue."
        exit 2
    fi
fi

AWS_SECRET_ACCESS_KEY=${DEFAULT_AWS_SECRET_ACCESS_KEY}
printf "using aws secret access key: ****\n"

# pull-secret
if [ -f ../../prereqs/pull-secret.yaml ]; then
    cp ../../prereqs/pull-secret.yaml ./pull-secret.yaml
else
    kubectl get secret multiclusterhub-operator-pull-secret -n ${TARGET_NAMESPACE} --export -o yaml > pull-secret.yaml
fi

printf "* Applying SNAPSHOT (${SNAPSHOT}) to ./*.yaml\n"
${SED} -i "s/<SNAPSHOT>/${SNAPSHOT}/g" ./example-observability-cr.yaml

printf "* Applying BUCKET_NAME (${BUCKET_NAME}) to ./*.yaml\n"
${SED} -i "s/<BUCKET_NAME>/${BUCKET_NAME}/g" ./thanos.yaml

printf "* Applying CLOUD_REGION (${CLOUD_REGION}) to ./*.yaml\n"
${SED} -i "s/<CLOUD_REGION>/${CLOUD_REGION}/g" ./thanos.yaml

printf "* Applying AWS_ACCESS_KEY (****) to ./kustomization.yaml\n"
${SED} -i "s/<AWS_ACCESS_KEY>/${AWS_ACCESS_KEY}/g" ./thanos.yaml

printf "* Applying AWS_SECRET_ACCESS_KEY (****) to ./kustomization.yaml\n"
${SED} -i "s|<AWS_SECRET_ACCESS_KEY>|${AWS_SECRET_ACCESS_KEY}|g" ./thanos.yaml

echo "Ready to start deploying observability to your OCP cluster..."
echo "Press ENTER to continue"
read -r CONTINUE

kubectl apply -f namespace.yaml
kubectl apply -k .