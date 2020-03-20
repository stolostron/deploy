#!/bin/bash
# Copyright 2019 IBM Corporation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#####
# Copyright 2020 Red Hat Inc.


NAMESPACE=${NAMESPACE:-open-cluster-management}

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

# Currently not used
force-remove-subscriptions () {
  echo "Remove subscriptions"
  echo "FORCE Uninstall the Subscriptions"
  for helmsubscription in `kubectl -n $SUBSCRIPTION_CONTROLLER_NAMESPACE get subscription.app.ibm.com -o name 2> /dev/null`; do
      echo "Deleting $helmsubscription";
      kubectl delete $helmsubscription -n $SUBSCRIPTION_CONTROLLER_NAMESPACE --ignore-not-found --wait=false;
  done
}

force-remove-helmreleases () {
  echo "Force uninstall the helmreleases"
  for helmrelease in `kubectl -n $NAMESPACE get helmReleases -o name 2> /dev/null`; do
    kubectl patch ${helmrelease} --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'
    echo "Deleting $helmrelease";
    kubectl delete $helmrelease -n $NAMESPACE --ignore-not-found;
  done
}

force-remove-helmrelease-secrets () {
  for name in `oc get secrets -o name | grep multicluster-hub`; do
    oc delete $name
  done
}

remove-hive () {
  echo "Remove Red Hat hive"
  oc get validatingwebhookconfiguration | grep "hive" | awk '{ print $1 }' | xargs oc delete validatingwebhookconfiguration
  for cd in `oc get clusterDeployment --all-namespaces | grep -v NAMESPACE | awk '{ print $1 }'`; do
    oc -n $cd patch clusterDeployment/$cd --type json -p '[{ "op": "remove", "path":"/metadata/finalizers" }]'
  done
  oc get apiservice | grep "hive" | awk '{ print $1 }' | xargs oc delete apiservice
  oc get crd | grep "hive" | awk '{ print $1 }' | xargs oc delete crd --wait=false
  oc get clusterrole | grep "hive" | awk '{ print $1 }' | xargs oc delete clusterrole
  oc get clusterrolebindings | grep "hive" | awk '{ print $1 }' | xargs oc delete clusterrolebinding
  oc delete namespace hive
}

echo "Uninstall Red Hat Advanced Cluster Management for Kubernetes"
oc project ${NAMESPACE}
remove-apiservices
force-remove-subscriptions
oc delete -k multiclusterhub/ --ignore-not-found
force-remove-helmreleases $1
remove-apiservices
force-remove-helmrelease-secrets $1
oc delete -k multiclusterhub-operator/ --ignore-not-found
remove-hive
oc delete -k prereqs/ --ignore-not-found
