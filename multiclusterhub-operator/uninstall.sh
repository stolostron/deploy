#!/bin/bash

oc project open-cluster-management

# Remove multicloudhub resources
oc delete subscriptions.operators.coreos.com multiclusterhub-operator --ignore-not-found
oc delete csv multiclusterhub-operator.v1.0.0 --ignore-not-found
oc delete catalogsource multiclusterhub-operator-registry --ignore-not-found
oc delete crd multiclusterhubs.operators.open-cluster-management.io --ignore-not-found

oc delete validatingwebhookconfiguration multiclusterhub-operator-validating-webhook --ignore-not-found
oc delete mutatingwebhookconfiguration multiclusterhub-operator-mutating-webhook --ignore-not-found

# Remove etcd resources
oc delete subscriptions.operators.coreos.com etcd-singlenamespace-alpha-community-operators-openshift-marketplace --ignore-not-found
oc get csv | grep "etcd" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found
oc get crd | grep "etcd" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found
oc get service | grep "etcd" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found

# Remove subscription operator resources
oc delete subscriptions.operators.coreos.com multicluster-operators-subscription-alpha-community-operators-openshift-marketplace --ignore-not-found
oc get csv | grep "multicluster-operators-subscription" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found
oc get crd | grep "multicluster-operators-subscription" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found
oc delete crd clusters.clusterregistry.k8s.io --ignore-not-found
oc delete crd channels.apps.open-cluster-management.io --ignore-not-found
oc delete crd subscriptions.apps.open-cluster-management.io --ignore-not-found
oc delete crd helmreleases.apps.open-cluster-management.io --ignore-not-found
oc delete crd deployables.apps.open-cluster-management.io --ignore-not-found
oc delete crd placementrules.apps.open-cluster-management.io --ignore-not-found
oc delete crd applications.app.k8s.io --ignore-not-found
oc delete crd clusters.clusterregistry.k8s.io --ignore-not-found
oc get service | grep "multicluster" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found

oc get scc | grep "multicluster" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found
oc get scc | grep "multicloud" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found

oc delete namespace open-cluster-management --wait=false
