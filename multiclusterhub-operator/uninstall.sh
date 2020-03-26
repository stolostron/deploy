#!/bin/bash

oc project open-cluster-management
for deployment in $(oc get Deployments | cut -f 1 -d ' '); do oc delete Deployment $deployment --ignore-not-found; done
for subscription in $(oc get subscription | cut -f 1 -d ' '); do oc delete subscription $subscription --ignore-not-found; done
for role in $(oc get clusterrole | grep open-cluster-management | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for role in $(oc get clusterrole | grep multicluster | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
oc get csv | grep "multicluster" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get csv | grep "multicloud" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get crd | grep "open-cluster-management.io" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get service | grep "multicluster" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found || true
for secret in $(oc get Secret -n open-cluster-management | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for configmap in $(oc get configmap -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n open-cluster-management --ignore-not-found; done
oc get csv | grep "etcd" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get crd | grep "etcd" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get scc | grep "multicluster" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get scc | grep "multicloud" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get crd | grep "certmanager" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get clusterrole | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete clusterrole --wait=false --ignore-not-found || true
oc get clusterrolebinding | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete clusterrolebinding --wait=false --ignore-not-found || true
oc get mutatingwebhookconfiguration | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete mutatingwebhookconfiguration --wait=false --ignore-not-found || true
oc delete namespace open-cluster-management --wait=false