#!/bin/bash

oc project open-cluster-management
oc delete csv multicloudhub-operator.v0.0.1 || true
oc delete csv etcdoperator.v0.9.4 || true
oc delete csv multicloud-operators-subscription.v0.1.2 || true
oc delete crd multicloudhubs.operators.multicloud.ibm.com || true
oc delete crd channels.app.ibm.com || true
oc delete crd deployables.app.ibm.com || true
oc delete crd helmreleases.app.ibm.com || true
oc delete crd subscriptions.app.ibm.com || true
for configmap in $(oc get configmap -n open-cluster-management | cut -f 1 -d ' '); do oc delete configmap $configmap -n open-cluster-management; done
oc delete crd etcdbackups.etcd.database.coreos.com || true
oc delete crd etcdclusters.etcd.database.coreos.com || true
oc delete crd etcdrestores.etcd.database.coreos.com || true
oc delete apiservice v1.admission.hive.openshift.io || true
oc delete apiservice v1.hive.openshift.io || true
oc delete apiservice v1beta1.webhook.certmanager.k8s.io || true
for webhook in $(oc get validatingwebhookconfiguration | grep hive | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook; done
for configmap in $(oc get configmap -n hive | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive; done
oc delete scc multicloud-scc || true