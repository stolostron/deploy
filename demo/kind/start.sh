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

DEFAULT_SNAPSHOT="MUST_PROVIDE_SNAPSHOT"
if [ -f ../../snapshot.ver ]; then
    DEFAULT_SNAPSHOT=`cat ../../snapshot.ver`
fi

echo "This script will install kind (https://kind.sigs.k8s.io/) on your machine."
echo "You must have go already installed on your machine."
echo "To continue installing kind press ENTER:"
read -r CONTINUE

GO111MODULE="on" go get sigs.k8s.io/kind@v0.7.0

printf "Enter a CLUSTER NAME: (press ENTER to use default)\n"
read -r CLUSTER_NAME_CHOICE
if [ "${CLUSTER_NAME_CHOICE}" != "" ]; then
    CLUSTER_NAME=${CLUSTER_NAME_CHOICE}
fi

CLUSTER_NAME=${CLUSTER_NAME}
printf "using cluster name: ${CLUSTER_NAME}\n"

${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./kind-cluster.yaml
${SED} -i "s/<CLUSTER_NAME>/${CLUSTER_NAME}/g" ./import/endpoint.yaml

${SED} -i "s/newTag: .*$/newTag: ${DEFAULT_SNAPSHOT}/g" ./import/kustomization.yaml
${SED} -i "s/<SNAPSHOT>/${DEFAULT_SNAPSHOT/1.0.0/}/g" ./import/endpoint_operator.yaml

printf "Ready to create kind cluster on your machine... Press ENTER to continue: "
read -r CONTINUE

# copy kubeconfig to import folder
cp ~/.kube/config ./import/kubeconfig

echo "Creating kind cluster (${CLUSTER_NAME}) on your machine..."
kind create cluster --name=${CLUSTER_NAME}

kubectl apply -f kind-cluster.yaml
kubectl config use-context kind-${CLUSTER_NAME}
kubectl apply -k import/

printf "\n"
echo "You can now use kubectl with your kind cluster."
echo "To list your configured clusters use:"
printf "\n"
echo "kubectl config get-contexts"
printf "\n"
echo "To switch between your configured clusters use:"
printf "\n"
echo "kubectl config use-context xxxx"
printf "\n"