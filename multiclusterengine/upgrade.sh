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

# Check availability of multicluster engine
echo "Verify connection and Multicluster Engine is present."
out=`oc get mce multiclusterengine-sample 2>&1`
if [ $? -ne 0 ]; then
  echo "Did not find the resource multiclusterengine-sample. Make sure you are connected to the correct OpenShift."
  printf "\n${out}\n"
  exit 1
fi

# Support running the script while connected to the cluster as "snapshot=backplane-2.0-XX-YY-ZZ && ./upgrade.sh"
if [ "${snapshot}" == "" ]; then
  echo "Choose a snapshot to use from: https://quay.io/repository/stolostron/cmb-custom-registry?tab=tags&tag=latest"
  read snapshot
  if [ "${snapshot}" == "" ]; then
    echo "No snapshot provided"
    exit 1
  fi
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
  name: multiclusterengine-catalog
  namespace: openshift-marketplace
spec:
  displayName: MultiCluster Engine
  image: quay.io/stolostron/cmb-custom-registry:${snapshot}
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

# We do not exit, because we still the the subscription check which may re-generate the CSV in specific failure scenarios
oc -n multicluster-engine delete subscription multicluster-engine
if [ $? -ne 0 ]; then
  exit 1
fi

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/multicluster-engine.multicluster-engine: ""
  name: multicluster-engine
  namespace: multicluster-engine
spec:
  channel: stable-${snapshot:0:3}
  installPlanApproval: Automatic
  name: multicluster-engine
  source: multiclusterengine-catalog
  sourceNamespace: openshift-marketplace
EOF
if [ $? -ne 0 ]; then
  exit 1
fi

echo "Upgrade complete."
if [[ "$@" == *"--watch"* ]]; then
  watch oc -n multicluster-engine get pods --sort-by=.metadata.creationTimestamp
fi