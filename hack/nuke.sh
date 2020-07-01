#!/bin/bash

source ./hack/utils.sh

remove-apiservices () {
  echo "Remove Orphaned Apiservices"
  for apiservice in `kubectl get apiservices 2>/dev/null | grep "False" | awk '{ print $1; }'`; do
    if [[ $apiservice =~ "clusterapi.io" ]] || [[ $apiservice =~ "clusterregistry.k8s.io" ]] || [[ $apiservice =~ "mcm.ibm.com" ]] || [[ $apiservice =~ "v1beta1.webhook.certmanager.k8s.io" ]] || [[ $apiservice =~ "hive.openshift.io" ]]; then
      kubectl delete apiservice $apiservice || true
    else
      echo "Skipping apiservice $apiservice"
    fi
  done
}

# Strip out finalizers. This will make orphans!
echo "Strip out finalizers"
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]' || true; done
for mch in $(oc get multiclusterhub | tail -n +2 | cut -f 1 -d ' '); do oc patch multiclusterhub $mch --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]' || true; done

kubectl delete -k ../multiclusterhub/ || true
kubectl delete -k ../acm-operator/ || true

oc project open-cluster-management
remove-apiservices
# cluster deployment cleanup now being done by clean-clusters.sh
# for deployment in $(oc get ClusterDeployment --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do echo "Deleting managed cluster $deployment... this may take a few minutes."; oc delete ClusterDeployment $deployment -n $deployment; echo "done."; done
for cluster in $(oc get Cluster --all-namespaces --ignore-not-found | tail -n +2 | cut -f 1 -d ' '); do oc delete Cluster $cluster && oc delete namespace $cluster --wait=false --ignore-not-found || true; done

# Deletes all subscriptions in the system
for subscription in $(oc get subscriptions.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc delete subscriptions.apps.open-cluster-management.io $subscription --wait=false --ignore-not-found || true; done
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]' || true; done

#Run through twice, first time initiate all the deletes, 2nd time wait. This makes it more likely if the user runs the finalizer patch there will be NO orphans
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc delete helmreleases.apps.open-cluster-management.io $helmrelease --wait=false --ignore-not-found || true; done
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc delete helmreleases.apps.open-cluster-management.io $helmrelease --ignore-not-found || true; done
for policy in $(oc get policies.policy.mcm.ibm.com | tail -n +2 | cut -f 1 -d ' '); do oc patch policies.policy.mcm.ibm.com $policy --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]' || true; oc delete policies.policy.mcm.ibm.com $policy --ignore-not-found || true; done

for webhook in $(oc get validatingwebhookconfiguration | grep cert-manager | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found || true; done
for configmap in $(oc get configmap  | grep cert-manager | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found || true; done
for configmap in $(oc get configmap | grep ingress-controller | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found || true; done
for apiservice in $(oc get apiservice | grep mcm | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found || true; done
for apiservice in $(oc get apiservice | grep certmanager | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found || true; done
for apiservice in $(oc get apiservice | grep clusterapi.io | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found || true; done
for apiservice in $(oc get apiservice | grep clusterregistry.k8s.io | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found || true; done
for role in $(oc get clusterrole | grep multicluster-mongo | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep cert-manager | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep mcm | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep rcm | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep klusterlet | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep managedcluster | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep search | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep configmap-watcher | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep multicluster-mongo | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep cert-manager | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep mcm | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep rcm | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep klusterlet | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep managedcluster | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep search | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get clusterrolebinding | grep configmap-watcher | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found || true; done
for role in $(oc get serviceaccount | grep search | cut -f 1 -d ' '); do oc delete serviceaccount $role --ignore-not-found || true; done
for secret in $(oc get Secret | grep search | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret | grep multicloud | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep kui | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep search | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep sh.helm.release | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep topology| cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep console-chart | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done
for secret in $(oc get Secret | grep aws | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found || true; done

remove-apiservices
oc get crd | grep "hive" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get csv | grep "hive" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
for deployment in $(oc get deploy -n hive | grep hive | cut -f 1 -d ' '); do oc delete deploy $deployment --ignore-not-found || true; done
for apiservice in $(oc get apiservice | grep hive | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found || true; done
for role in $(oc get clusterrole | grep hive | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for rolebinding in $(oc get clusterrolebindings | grep hive | cut -f 1 -d ' '); do oc delete clusterrolebinding $rolebinding --ignore-not-found || true; done
for webhook in $(oc get validatingwebhookconfiguration | grep hive | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found || true; done
for configmap in $(oc get configmap -n hive | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep hive | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep console | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep kui | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep management-ingress | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep sh.helm.release.v1 | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
for secret in $(oc get Secret -n hive | grep topology | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found || true; done
oc delete namespace hive --wait=false || true

for deployment in $(oc get Deployments | cut -f 1 -d ' '); do oc delete Deployment $deployment --ignore-not-found || true; done
for subscription in $(oc get subscription | cut -f 1 -d ' '); do oc delete subscription $subscription --ignore-not-found || true; done
for role in $(oc get clusterrole | grep open-cluster-management | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
for role in $(oc get clusterrole | grep multicluster | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found || true; done
oc get csv | grep "multicluster" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get csv | grep "multicloud" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get crd | grep "open-cluster-management.io" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get crd | grep "acm.io" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true

oc delete consolelink acm-console-link || true
oc delete clusterrole search-collector || true
oc delete clusterrolebinding search-collector || true
oc delete oauthclient multicloudingress || true

oc get service | grep "multicluster" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found || true
for secret in $(oc get Secret -n open-cluster-management | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found || true; done
for configmap in $(oc get configmap -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n open-cluster-management --ignore-not-found || true; done
oc get csv | grep "etcd" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get crd | grep "etcd" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get scc | grep "multicluster" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get scc | grep "multicloud" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get scc | grep "kui-proxy" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get crd | grep "certmanager" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get crd | grep "mcm" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get crd | grep "ibm" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get clusterrole | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete clusterrole --wait=false --ignore-not-found || true
oc get clusterrolebinding | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete clusterrolebinding --wait=false --ignore-not-found || true
oc get mutatingwebhookconfiguration | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete mutatingwebhookconfiguration --wait=false --ignore-not-found || true

cd ../
echo DESTROY | ./uninstall.sh || true

# cert-manager cert-manager-webhook
for webhook in $(oc get validatingwebhookconfiguration | grep cert-manager | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found || true; done
for webhook in $(oc get mutatingwebhookconfiguration | grep "cert-manager" | cut -f 1 -d ' '); do oc delete mutatingwebhookconfiguration $webhook --ignore-not-found || true; done
for apiservice in $(oc get apiservice | grep certmanager | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found || true; done
oc delete crd certificates.certmanager.k8s.io || true
oc delete crd certificaterequests.certmanager.k8s.io || true
oc delete crd challenges.certmanager.k8s.io || true
oc delete crd clusterissuers.certmanager.k8s.io || true
oc delete crd issuers.certmanager.k8s.io || true
oc delete crd orders.certmanager.k8s.io || true
oc delete clusterrole cert-manager-webhook-requester || true
oc delete clusterrolebinding cert-manager-webhook-auth-delegator || true

# console-chart
oc delete consolelink acm-console-link || true
oc delete crd userpreferences.console.open-cluster-management.io || true
oc delete clusterrole aggregate-clusterimagesets-readonly || true
oc delete clusterrolebinding readonly-clusterimagesets || true

# multicloud-ingress
oc delete oauthclient multicloudingress || true

# rcm
# 1.x
oc delete crd endpointconfigs.multicloud.ibm.com || true
# 2.x
oc delete crd klusterletconfigs.agent.open-cluster-management.io || true

oc delete clusterrole rcm-controller || true
oc delete clusterrolebinding rcm-controller || true

# workaround for https://github.com/open-cluster-management/backlog/issues/2915
oc delete apiservice v1.admission.cluster.open-cluster-management.io v1beta1.proxy.open-cluster-management.io
oc delete ValidatingWebhookConfiguration managedclustervalidators.admission.cluster.open-cluster-management.io

# clean up the `-hub` namespace for 2.x
oc delete ns open-cluster-management-hub --wait=false

# clean up leftover cert-manager resources
oc delete rolebinding -n kube-system cert-manager-webhook-webhook-authentication-reader




# if we are on a managed-cluster let's remove it's stuff too
if [ -z "${OPERATOR_NAMESPACE}" ]; then
	OPERATOR_NAMESPACE="multicluster-endpoint"
fi

# Delete all endpoints.multicloud.ibm.com
kubectl delete endpoints.multicloud.ibm.com -n ${OPERATOR_NAMESPACE}  --all --timeout=60s || true

# Delete Deployment
kubectl delete deployment ibm-multicluster-endpoint-operator -n ${OPERATOR_NAMESPACE} || true

# Force delete all component CRDs if they still exist
component_crds=(
	applicationmanagers.multicloud.ibm.com
	certpoliciescontroller.multicloud.ibm.com
	ciscontrollers.multicloud.ibm.com
	connectionmanagers.multicloud.ibm.com
	iampoliciescontroller.multicloud.ibm.com
	policycontrollers.multicloud.ibm.com
	searchcollectors.multicloud.ibm.com
	serviceregistries.multicloud.ibm.com
	workmanagers.multicloud.ibm.com
	endpoints.multicloud.ibm.com
	clustermanagers.operator.open-cluster-management.io
	multiclusterhubs.operator.open-cluster-management.io
	klusterlets.operator.open-cluster-management.io
)

for crd in "${component_crds[@]}"; do
	echo "force delete all CustomResourceDefination ${crd} resources..."
	for resource in `kubectl get ${crd} -o name -n ${OPERATOR_NAMESPACE}`; do
		echo "attempt to delete ${crd} resource ${resource}..."
		kubectl delete ${resource} -n ${OPERATOR_NAMESPACE} --timeout=15s || true
		echo "force remove ${crd} resource ${resource}..."
		kubectl patch ${resource} -n ${OPERATOR_NAMESPACE} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' || true
	done
	echo "force delete all CustomResourceDefination ${crd} resources..."
	kubectl delete crd ${crd} || true
done

kubectl delete namespace ${OPERATOR_NAMESPACE} --wait=false || true

evict_all_wedged_crd
nuke_leaked_namespaces

