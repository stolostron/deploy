#!/bin/bash

oc project open-cluster-management
for deployment in $(oc get Deployments -n open-cluster-management | cut -f 1 -d ' '); do oc delete Deployment $deployment -n open-cluster-management --ignore-not-found; done
oc delete subscription multiclusterhub-operator --ignore-not-found || true
oc delete subscription etcdoperator.v0.9.4 --ignore-not-found || true
oc delete subscription multicloud-operators-subscription.v0.1.2 --ignore-not-found || true
for subscription in $(oc get subscription.operators.coreos.com -n open-cluster-management | cut -f 1 -d ' '); do oc delete subscription.operators.coreos.com $subscription -n open-cluster-management --ignore-not-found; done
oc delete csv multiclusterhub-operator.v0.0.1 --ignore-not-found || true
oc delete csv multicloud-operators-subscription.v0.1.2 --ignore-not-found || true
oc delete csv multicluster-operators-subscription.v0.1.0 --ignore-not-found || true
oc delete crd placementrules.apps.open-cluster-management.io --ignore-not-found || true
oc delete crd multiclusterhubs.operators.open-cluster-management.io --ignore-not-found || true
oc delete crd channels.apps.open-cluster-management.io --ignore-not-found || true
oc delete crd deployables.apps.open-cluster-management.io --ignore-not-found || true
oc delete crd helmreleases.apps.open-cluster-management.io --ignore-not-found || true
oc delete crd subscriptions.apps.open-cluster-management.io --ignore-not-found || true
oc delete service multicluster-operators-subscription --ignore-not-found || true
for secret in $(oc get Secret -n open-cluster-management | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for configmap in $(oc get configmap -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n open-cluster-management --ignore-not-found; done
oc delete csv etcdoperator.v0.9.4 --ignore-not-found
oc delete crd etcdbackups.etcd.database.coreos.com --ignore-not-found || true
oc delete crd etcdclusters.etcd.database.coreos.com --ignore-not-found || true
oc delete crd etcdrestores.etcd.database.coreos.com --ignore-not-found || true
oc delete scc multicluster-scc --ignore-not-found || true
oc delete scc multicloud-scc --ignore-not-found || true
oc delete crd certificates.certmanager.k8s.io || true
oc delete crd certificaterequests.certmanager.k8s.io || true
oc delete crd challenges.certmanager.k8s.io || true
oc delete crd clusterissuers.certmanager.k8s.io || true
oc delete crd issuers.certmanager.k8s.io || true
oc delete crd orders.certmanager.k8s.io || true
oc delete clusterrolebinding cert-manager-webhook-auth-delegator || true
oc delete clusterRoles cert-manager-webhook-requester || true
oc delete mutatingwebhookconfiguration cert-manager-webhook || true