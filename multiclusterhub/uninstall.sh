#!/bin/bash

remove-apiservices () {
  echo "Remove Orphaned Apiservices"
  for apiservice in `kubectl get apiservices 2>/dev/null | grep "False" | awk '{ print $1; }'`; do
    if [[ $apiservice =~ "clusterapi.io" ]] || [[ $apiservice =~ "clusterregistry.k8s.io" ]] || [[ $apiservice =~ "mcm.ibm.com" ]] || [[ $apiservice =~ "v1beta1.webhook.certmanager.k8s.io" ]] || [[ $apiservice =~ "hive.openshift.io" ]]; then
      kubectl delete apiservice $apiservice
    else
      echo "Skipping apiservice $apiservice"
    fi
  done
}

oc project open-cluster-management
remove-apiservices
for deployment in $(oc get ClusterDeployment --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do echo "Deleting managed cluster $deployment... this may take a few minutes."; oc delete ClusterDeployment $deployment -n $deployment; echo "done."; done
for cluster in $(oc get Cluster.clusterregistry.k8s.io --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do oc delete Cluster $cluster && oc delete namespace $cluster --wait=false; done
oc delete appsub --all --ignore-not-found || true
oc delete crd endpointconfigs.multicloud.ibm.com --ignore-not-found || true
for subscription in $(oc get subscriptions.apps.open-cluster-management.io -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete subscriptions.apps.open-cluster-management.io $subscription -n open-cluster-management --wait=false; done
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease -n open-cluster-management --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; oc delete helmreleases.apps.open-cluster-management.io $helmrelease -n open-cluster-management; done
for webhook in $(oc get validatingwebhookconfiguration | grep cert-manager | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook; done
for configmap in $(oc get configmap -n open-cluster-management  | grep cert-manager | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for configmap in $(oc get configmap -n open-cluster-management | grep ingress-controller | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
oc delete apiservice clusterapi.io --ignore-not-found || true
oc delete apiservice clusterregistry.k8s.io --ignore-not-found || true
oc delete apiservice mcm.ibm.com --ignore-not-found || true
oc delete apiservice mcm-apiserver --ignore-not-found || true
oc delete apiservice v1beta1.webhook.certmanager.k8s.io --ignore-not-found || true
for secret in $(oc get Secret -n open-cluster-management | grep search | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep multicloud | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep kui | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep search | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep sh.helm.release | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep topology| cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep console-chart | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for secret in $(oc get Secret -n open-cluster-management | grep aws | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done

remove-apiservices
oc get apiservice | grep "hive" | awk '{ print $1 }' | xargs oc delete apiservice
oc get crd | grep "hive" | awk '{ print $1 }' | xargs oc delete crd --wait=false
oc delete csv hive -n hive $(oc get csv -n hive | tail -n +2 | cut -f 1 -d ' ') --ignore-not-found || true
oc delete deploy hive-controllers -n hive -n hive --ignore-not-found || true
oc delete deploy hiveadmission -n hive -n hive --ignore-not-found || true
oc delete apiservice hiveadmission -n hive --ignore-not-found || true
oc get clusterrole | grep "hive" | awk '{ print $1 }' | xargs oc delete clusterrole
oc get clusterrolebindings | grep "hive" | awk '{ print $1 }' | xargs oc delete clusterrolebinding
for webhook in $(oc get validatingwebhookconfiguration | grep hive | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found; done
for configmap in $(oc get configmap -n hive | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep hive | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep console | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep kui | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep management-ingress | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep sh.helm.release.v1 | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep topology | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
oc delete namespace hive --wait=false

#Additonal cleanup
oc delete crd userpreferences.console.acm.io --ignore-not-found || true
oc delete ConsoleLink acm-console-link --ignore-not-found || true
oc delete OAuthClient multicloudingress --ignore-not-found || true
