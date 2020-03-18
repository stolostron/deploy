#!/bin/bash

oc project open-cluster-management
oc delete csv multiclusterhub-operator.v0.0.1 --ignore-not-found || true
oc delete csv etcdoperator.v0.9.4 --ignore-not-found || true
oc delete csv multicloud-operators-subscription.v0.1.2 --ignore-not-found || true
oc delete crd multiclusterhubs.operators.open-cluster-management.io --ignore-not-found || true
oc delete crd channels.app.ibm.com --ignore-not-found || true
oc delete crd deployables.app.ibm.com --ignore-not-found || true
oc delete crd helmreleases.app.ibm.com --ignore-not-found || true
oc delete crd subscriptions.app.ibm.com --ignore-not-found || true
for secret in $(oc get Secret -n open-cluster-management | grep multicluster-hub | cut -f 1 -d ' '); do oc delete $secret -n open-cluster-management --ignore-not-found; done
for configmap in $(oc get configmap -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n open-cluster-management --ignore-not-found; done
oc delete crd etcdbackups.etcd.database.coreos.com --ignore-not-found || true
oc delete crd etcdclusters.etcd.database.coreos.com --ignore-not-found || true
oc delete crd etcdrestores.etcd.database.coreos.com --ignore-not-found || true
oc delete scc multicluster-scc --ignore-not-found || true
oc delete scc multicloud-scc --ignore-not-found || true

# hive
oc delete csv hive -n hive $(oc get csv -n hive | tail -n +2 | cut -f 1 -d ' ') --ignore-not-found || true
