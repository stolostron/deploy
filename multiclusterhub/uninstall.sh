#!/bin/bash

oc project open-cluster-management
for deployment in $(oc get ClusterDeployment --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do echo "Deleting managed cluster $deployment... this may take a few minutes."; oc delete ClusterDeployment $deployment -n $deployment; echo "done."; done
for cluster in $(oc get Cluster --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do oc delete Cluster $cluster; done
oc delete apiservice clusterapi.io --ignore-not-found || true
oc delete apiservice clusterregistry.k8s.io --ignore-not-found || true
oc delete apiservice mcm.ibm.com --ignore-not-found || true
oc delete apiservice v1beta1.webhook.certmanager.k8s.io --ignore-not-found || true
for subscription in $(oc get subscriptions.app.ibm.com -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete subscriptions.app.ibm.com $subscription -n open-cluster-management --wait=false; done
for helmrelease in $(oc get helmreleases.app.ibm.com -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.app.ibm.com $helmrelease -n open-cluster-management --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; oc delete helmreleases.app.ibm.com $helmrelease -n open-cluster-management; done
for webhook in $(oc get validatingwebhookconfiguration | grep cert-manager | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook; done
oc delete deploy -n hive hive-controllers --ignore-not-found || true
oc delete deploy -n hive hiveadmission --ignore-not-found || true
oc get crd | grep "hive" | awk '{ print $1 }' | xargs oc delete crd --wait=false
oc get clusterrole | grep "hive" | awk '{ print $1 }' | xargs oc delete clusterrole
oc get clusterrolebindings | grep "hive" | awk '{ print $1 }' | xargs oc delete clusterrolebinding
for configmap in $(oc get configmap -n hive | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for webhook in $(oc get validatingwebhookconfiguration | grep hive | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found; done
