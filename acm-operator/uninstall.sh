#!/bin/bash

ocm_namespace="open-cluster-management"

oc project $ocm_namespace

operator_subscription="acm-operator-subscription"
operator_csv="advanced-cluster-management.v1.0.0"
custom_catalog_source="acm-custom-registry"
custom_registry_service="acm-custom-registry"
custom_registry_deployment="acm-custom-registry"

# Remove acm resources
oc delete subscriptions.operators.coreos.com $operator_subscription --ignore-not-found
oc delete csv $operator_csv --ignore-not-found

# Remove hub resources
oc delete crd multiclusterhubs.operators.open-cluster-management.io --ignore-not-found
oc delete validatingwebhookconfiguration multiclusterhub-operator-validating-webhook --ignore-not-found
oc delete mutatingwebhookconfiguration multiclusterhub-operator-mutating-webhook --ignore-not-found

# Remove etcd resources
oc delete subscriptions.operators.coreos.com etcd-singlenamespace-alpha-community-operators-openshift-marketplace --ignore-not-found
oc get csv | grep "etcd" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found
oc get crd | grep "etcd" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found
oc get service | grep "etcd" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found

# Remove subscription operator resources
# Note: No separate operator subscription to delete when installed via composite ACM CSV
# oc delete subscriptions.operators.coreos.com multicluster-operators-subscription-alpha-community-operators-openshift-marketplace --ignore-not-found
# oc get csv | grep "multicluster-operators-subscription" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found
oc delete crd clusters.clusterregistry.k8s.io --ignore-not-found
oc delete crd channels.apps.open-cluster-management.io --ignore-not-found
oc delete crd subscriptions.apps.open-cluster-management.io --ignore-not-found
oc delete crd helmreleases.apps.open-cluster-management.io --ignore-not-found
oc delete crd deployables.apps.open-cluster-management.io --ignore-not-found
oc delete crd placementrules.apps.open-cluster-management.io --ignore-not-found
oc delete crd applications.app.k8s.io --ignore-not-found
oc delete crd clusters.clusterregistry.k8s.io --ignore-not-found
oc get service | grep "multicluster" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found

# delete these objects via nuke script only
# oc get scc | grep "multicluster" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found
# oc get scc | grep "multicloud" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found

# Remove custom registry resources
oc delete catalogsource $custom_catalog_source --ignore-not-found
oc delete service $custom_registry_service --ignore-not-found
oc delete deployment $custom_registry_deployment --ignore-not-found

oc delete namespace $ocm_namespace --wait=false
