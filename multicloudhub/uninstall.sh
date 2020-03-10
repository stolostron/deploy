#!/bin/bash

oc project open-cluster-management
oc get helmreleases -o yaml | sed 's/\- app\.ibm\.com\/helmrelease//g' | oc apply -f - || true
oc delete helmreleases --all || trues
oc delete deploy -n hive hive-controllers || true
oc delete deploy -n hive hiveadmission || true