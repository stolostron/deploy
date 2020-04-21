#!/bin/bash

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# if using --watch option on mac make sure watch is installed
if [ ! -x "$(command -v jq)" ]; then
  echo "ERROR: jq required, but not found."
  if [ "${OS}" == "darwin" ]; then
    echo "Perform \"brew install jq\" and try again."
  fi
  exit 1
fi

oc project open-cluster-management

# cluster deployment cleanup now being done by clean-clusters.sh
# for deployment in $(oc get ClusterDeployment --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do echo "Deleting managed cluster $deployment... this may take a few minutes."; oc delete ClusterDeployment $deployment -n $deployment; echo "done."; done
# for cluster in $(oc get Cluster --all-namespaces --ignore-not-found | tail -n +2 | cut -f 1 -d ' '); do oc delete Cluster $cluster && oc delete namespace $cluster --wait=false --ignore-not-found; done

# Consider delete complete when all helmreleases are gone or CRD doesn't exist
for i in {1..10}; do
  oc get helmreleases.apps.open-cluster-management.io > /dev/null
  if [ $? -ne 0 ]; then
    break
  elif [ $(kubectl get helmreleases.apps.open-cluster-management.io --output json | jq -j '.items | length') == "0" ]; then 
    break
  else
    sleep 2
  fi
done

oc get helmreleases.apps.open-cluster-management.io > /dev/null
if [ $? -ne 0 ]; then
  echo
elif [ $(kubectl get helmreleases.apps.open-cluster-management.io --output json | jq -j '.items | length') == "0" ]; then 
  echo
else
  echo "Uninstall stuck... Striping out finalizers from helm releases..."
  for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; done

  # these objects get left-behind when uninstall has to strip finalizers from helm releases, clean them up manually

  # cert-manager cert-manager-webhook
  for webhook in $(oc get validatingwebhookconfiguration | grep cert-manager | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found; done
  for webhook in $(oc get mutatingwebhookconfiguration | grep "cert-manager" | cut -f 1 -d ' '); do oc delete mutatingwebhookconfiguration $webhook --ignore-not-found; done
  for apiservice in $(oc get apiservice | grep certmanager | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
  oc delete crd certificates.certmanager.k8s.io
  oc delete crd certificaterequests.certmanager.k8s.io
  oc delete crd challenges.certmanager.k8s.io
  oc delete crd clusterissuers.certmanager.k8s.io
  oc delete crd issuers.certmanager.k8s.io
  oc delete crd orders.certmanager.k8s.io
  oc delete clusterrole cert-manager-webhook-requester
  oc delete clusterrolebinding cert-manager-webhook-auth-delegator

  # console-chart
  oc delete consolelink acm-console-link
  oc delete crd userpreferences.console.acm.io

  # multicloud-ingress
  oc delete oauthclient multicloudingress

  # rcm
  oc delete crd endpointconfigs.multicloud.ibm.com
  oc delete clusterrole rcm-controller
  oc delete clusterrolebinding rcm-controller
fi


# Not seen on cluster
for apiservice in $(oc get apiservice | grep clusterapi.io | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for secret in $(oc get Secret | grep aws | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for role in $(oc get clusterrole | grep multicluster | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for rolebinding in $(oc get clusterrolebindings | grep multicluster | cut -f 1 -d ' '); do oc delete clusterrolebinding $rolebinding --ignore-not-found; done
for role in $(oc get clusterrole | grep mcm | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for rolebinding in $(oc get clusterrolebindings | grep mcm | cut -f 1 -d ' '); do oc delete clusterrolebinding $rolebinding --ignore-not-found; done


oc get policies.policy.mcm.ibm.com --all-namespaces | tail -n +2 | awk '{ print $2 " -n " $1 }' | xargs oc patch policies.policy.mcm.ibm.com --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]' || true
oc get policies.policy.mcm.ibm.com --all-namespaces | tail -n +2 | awk '{ print $2 " -n " $1 }' | xargs oc delete policies.policy.mcm.ibm.com --wait=false --ignore-not-found || true

# Issue https://github.com/open-cluster-management/backlog/issues/1286
oc delete crd compliances.compliance.mcm.ibm.com --wait=false --ignore-not-found || true
oc delete crd policies.policy.mcm.ibm.com --wait=false --ignore-not-found || true

# Issue https://github.com/open-cluster-management/backlog/issues/1794
oc delete crd searchservices.search.acm.com --wait=false --ignore-not-found || true

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
oc delete hiveconfig hive --ignore-not-found
oc delete namespace hive --wait=false --ignore-not-found

#Additonal cleanup
#oc delete crd userpreferences.console.acm.io --ignore-not-found || true
#oc delete ConsoleLink acm-console-link --ignore-not-found || true
#oc delete OAuthClient multicloudingress --ignore-not-found || true
