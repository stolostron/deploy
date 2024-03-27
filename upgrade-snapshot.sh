#!/bin/bash
# Copyright 2022.
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

DOWNSTREAM=${DOWNSTREAM:-"false"}

# Check availability of multicluster engine
echo "Verify connection and Advanced Cluster Management is present."
out=`oc get mch multiclusterhub -n open-cluster-management 2>&1`
if [ $? -ne 0 ]; then
  echo "Did not find the resource multiclusterhub. Make sure you are connected to the correct OpenShift."
  printf "\n${out}\n"
  exit 1
fi

REGISTRY=stolostron
IMAGE_NAME="acm-custom-registry"
if [ "${DOWNSTREAM}" == "true" ]; then
  REGISTRY="acm-d"
fi

# Support running the script while connected to the cluster as "snapshot=backplane-2.0-XX-YY-ZZ && ./upgrade.sh"
if [ "${snapshot}" == "" ]; then
  echo "Choose a snapshot to use from: https://quay.io/repository/${REGISTRY}/${IMAGE_NAME}?tab=tags&tag=latest"
  read snapshot
  if [ "${snapshot}" == "" ]; then
    echo "No snapshot provided"
    exit 1
  fi
fi

SNAPSHOT_PREFIX=${snapshot%%\-*}
echo "* Downstream: ${DOWNSTREAM}   Release Version: $SNAPSHOT_PREFIX"
if [[ (! $SNAPSHOT_PREFIX == *.*.*) && ("$DOWNSTREAM" != "true") ]]; then
    echo "ERROR: invalid SNAPSHOT format... snapshot must begin with 'X.0.0-' not '$SNAPSHOT_PREFIX', if DOWNSTREAM isn't set"
    exit 1
fi

echo "Check if MultiClusterObservability is running"
obs="false"
oc get MultiClusterObservability observability
if [ $? -eq 0 ]; then
  oc delete MultiClusterObservability observability
  obs="true"
fi

echo "Verify acm-custom-registry in openshift-marketplace."
oc get -n openshift-marketplace catalogsource acm-custom-registry > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "catalogSource is misisng"
  exit 1
fi

echo "Verify multiclusterengine-catalog in openshift-marketplace."
oc get -n openshift-marketplace catalogsource multiclusterengine-catalog > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "catalogSource is misisng"
  exit 1
fi

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: acm-custom-registry
  namespace: openshift-marketplace
spec:
  displayName: Advanced Cluster management
  image: quay.io/${REGISTRY}/${IMAGE_NAME}:${snapshot/v/}
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 10m
EOF
if [ $? -ne 0 ]; then
  echo "Error when attempting to update the acm-custom-registry CatalogSource in openshift-marketplace"
  exit 1
fi
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: multiclusterengine-catalog
  namespace: openshift-marketplace
spec:
  displayName: Multi-Cluster Engine
  image: quay.io/${REGISTRY}/cmb-custom-registry:${snapshot/v/}
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 10m
EOF
if [ $? -ne 0 ]; then
  echo "Error when attempting to update the multiclusterengine-catalog CatalogSource in openshift-marketplace"
  exit 1
fi

mceRef=`oc -n multicluster-engine get csv -o name | grep multicluster-engine.v`
if [ $? -eq 0 ]; then
  oc -n multicluster-engine delete ${mceRef}
  if [ $? -ne 0 ]; then
    exit 1
  fi
else
  echo WARNING: CSV with multicluster-engine was not found in project multicluster-engine.
fi

mceRef=`oc -n open-cluster-management get csv -o name | grep advanced-cluster-management.v`
if [ $? -eq 0 ]; then
  oc -n open-cluster-management delete ${mceRef}
  if [ $? -ne 0 ]; then
    exit 1
  fi
else
  echo WARNING: CSV with advanced-cluster-management was not found in project open-cluster-management.
fi

# We do not exit, because we still need to delete the subscription which may re-generate the CSV in specific failure scenarios
oc -n multicluster-engine get subscriptions.operators.coreos.com multicluster-engine
if [ $? -eq 0 ]; then
  oc -n multicluster-engine delete subscriptions.operators.coreos.com multicluster-engine
  if [ $? -ne 0 ]; then
    exit 1
  fi
else
  echo "WARNING: subscriptions.operators.coreos.com multicluster-engine not found"
fi

oc -n open-cluster-management get subscriptions.operators.coreos.com acm-operator-subscription
if [ $? -eq 0 ]; then
  oc -n open-cluster-management delete subscriptions.operators.coreos.com acm-operator-subscription
  if [ $? -ne 0 ]; then
    exit 1
  fi
else
  echo "WARNING: subscriptions.operators.coreos.com acm-operator-subscription not found"
fi

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/multicluster-engine.multicluster-engine: ""
  name: acm-operator-subscription
  namespace: open-cluster-management
spec:
  channel: release-${snapshot:0:3}
  installPlanApproval: Automatic
  name: advanced-cluster-management
  source: acm-custom-registry
  sourceNamespace: openshift-marketplace
EOF
if [ $? -ne 0 ]; then
  exit 1
fi

echo "Upgrade started."
if [[ "$@" == *"--watch"* ]]; then
  watch oc -n multicluster-engine get pods --sort-by=.metadata.creationTimestamp
fi

if [ "$obs" == "true" ]; then
echo "Enable MultiClusterObservability"
oc create -f - <<EOF
apiVersion: observability.open-cluster-management.io/v1beta2
kind: MultiClusterObservability
metadata:
  name: observability
spec:
  observabilityAddonSpec: {}
  storageConfig:
    metricObjectStorage:
      name: thanos-object-storage
      key: thanos.yaml
EOF
  if [ $? -ne 0 ]; then
    echo "Failed to re-enable Observability"
    exit 1
  fi
fi