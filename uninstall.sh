#!/bin/bash

# Parameters
# -k, --keep-providers Keeping all provider connections that are not in Advanced Cluster Management namespaces.


KEEP_PROVIDERS=0
OCM_NAMESPACE=open-cluster-management

# save args to pass to called scripts
args=("$@")

# Parse command line arguments
for arg in "$@"
do
    case $arg in
        -k|--keep-providers)
        KEEP_PROVIDERS=1
        shift
        ;;
        *)
        echo "Unrecognized argument: $1"
        shift
        ;;
    esac
done


# Make sure `oc login` has been done and `oc` command is working
echo "Testing connection"
oc version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Make sure you are logged into an OpenShift Container Platform before running this script"
    exit 1
fi

VER=$(oc version | grep "Client Version:")

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

printf "\n"
echo "This script will uninstall Open Cluster Management from the current OpenShift target cluster:"
printf "\n"
oc cluster-info | head -n 1 | awk '{print $NF}'
printf "\n"

if [ -z ${OCM_NAMESPACE+x} ]; 
then 
    echo "OCM_NAMESPACE must be set"
    exit 1
else 
    echo "Cleaning up resources in namespace: $OCM_NAMESPACE"
fi
oc delete mch --all -n $OCM_NAMESPACE
## Delete all helm charts in given namespace
helm ls --namespace $OCM_NAMESPACE | cut -f 1 | tail -n +2 | xargs -n 1 helm delete --namespace $OCM_NAMESPACE
oc delete apiservice v1.admission.cluster.open-cluster-management.io v1beta1.webhook.certmanager.k8s.io v1.admission.cluster.open-cluster-management.io v1.admission.work.open-cluster-management.io
oc delete clusterimageset --all
oc delete configmap -n $OCM_NAMESPACE cert-manager-controller cert-manager-cainjector-leader-election cert-manager-cainjector-leader-election-core
oc delete consolelink acm-console-link
oc delete crd klusterletaddonconfigs.agent.open-cluster-management.io placementbindings.policy.open-cluster-management.io policies.policy.open-cluster-management.io userpreferences.console.open-cluster-management.io
oc delete mutatingwebhookconfiguration cert-manager-webhook-v1alpha1
oc delete oauthclient multicloudingress
oc delete rolebinding -n kube-system cert-manager-webhook-webhook-authentication-reader
oc delete scc kui-proxy-scc
oc delete validatingwebhookconfiguration cert-manager-webhook-v1alpha1
exit 0

#./clean-clusters.sh "$args"

#kubectl delete -k multiclusterhub/
#echo "Sleeping for 200 seconds to allow resources to finalize ..."
#sleep 200

#kubectl delete -k multicluster-hub-operator/
#./multicluster-hub-operator/uninstall.sh

#kubectl delete -k acm-operator/
#./acm-operator/uninstall.sh

#kubectl delete -k community-subscriptions/

exit 0
