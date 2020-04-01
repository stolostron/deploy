#!/bin/bash

oc project open-cluster-management

# cluster deployment cleanup now being done by clean-clusters.sh
# for deployment in $(oc get ClusterDeployment --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do echo "Deleting managed cluster $deployment... this may take a few minutes."; oc delete ClusterDeployment $deployment -n $deployment; echo "done."; done
for cluster in $(oc get Cluster --all-namespaces --ignore-not-found | tail -n +2 | cut -f 1 -d ' '); do oc delete Cluster $cluster && oc delete namespace $cluster --wait=false --ignore-not-found; done

# Consider delete complete when all helmreleases are gone
if oc explain helmreleases.apps.open-cluster-management.io; then
  echo "Wait until helmreleases are deleted..."
  until [[ $(kubectl get helmreleases.apps.open-cluster-management.io --output json | jq -j '.items | length') == "0" ]]; do sleep 2; done
fi

# Not seen on cluster
for apiservice in $(oc get apiservice | grep clusterapi.io | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for secret in $(oc get Secret | grep aws | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for policy in $(oc get policies.policy.mcm.ibm.com | tail -n +2 | cut -f 1 -d ' '); do oc patch policies.policy.mcm.ibm.com $policy --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; oc delete policies.policy.mcm.ibm.com $policy --ignore-not-found; done

# Issue https://github.com/open-cluster-management/backlog/issues/1286
oc delete crd compliances.compliance.mcm.ibm.com --ignore-not-found || true
oc delete crd policies.policy.mcm.ibm.com --ignore-not-found || true

# Working on in https://github.com/open-cluster-management/backlog/issues/786
for configmap in $(oc get configmap | grep ingress-controller | cut -f 1 -d ' '); do oc delete configmap $configmap --ignore-not-found; done

# Working on in https://github.com/open-cluster-management/backlog/issues/787
for secret in $(oc get Secret | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done

# Issue pending
oc delete mutatingwebhookconfiguration mcm-mutating-webhook --ignore-not-found


# Hive cleanup
oc get crd | grep "hive" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get csv | grep "hive" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
for deployment in $(oc get deploy -n hive | grep hive | cut -f 1 -d ' '); do oc delete deploy $deployment --ignore-not-found; done
for apiservice in $(oc get apiservice | grep hive | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for role in $(oc get clusterrole | grep hive | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for rolebinding in $(oc get clusterrolebindings | grep hive | cut -f 1 -d ' '); do oc delete clusterrolebinding $rolebinding --ignore-not-found; done
for webhook in $(oc get validatingwebhookconfiguration | grep hive | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found; done
for configmap in $(oc get configmap -n hive | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep hive | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
oc delete namespace hive --wait=false

#Additonal cleanup
#oc delete crd userpreferences.console.acm.io --ignore-not-found || true
#oc delete ConsoleLink acm-console-link --ignore-not-found || true
#oc delete OAuthClient multicloudingress --ignore-not-found || true
