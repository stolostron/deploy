#!/bin/bash
# This script can be used to easily change the image used by the mutlicluster-observability-operator
# by editing the ClusterServiceVersion resource. It only works with tags coming from
# https://quay.io/stolostron/multicluster-observability-operator and it will always
# use the image's digest.
set -euo pipefail

read -p "Please indicate the tag of your custom MCO image (https://quay.io/stolostron/multicluster-observability-operator): " mco_image_tag

digest=$(curl -I -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://quay.io/v2/stolostron/multicluster-observability-operator/manifests/$mco_image_tag" | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')

echo "Fetched digest from Quay: $digest"

pr_image="quay.io/stolostron/multicluster-observability-operator@$digest"
echo "Will deploy PR image: $pr_image"

csv_name=$(oc get -n open-cluster-management csv --selector operators.coreos.com/advanced-cluster-management.open-cluster-management -o json | jq -r '.items[0].metadata.name')
echo "Will use CSV with name: $csv_name"

read -p "Do you want to proceed? [y/N] " answer

case $answer in
[yY]*)
    echo "Proceeding."
    ;;
[nN]* | "")
    echo "Aborting."
    exit 1
    ;;
*)
    echo "Invalid answer. Exiting."
    exit 1
    ;;
esac

temp_folder=$(mktemp -d)
csv_path="$temp_folder"/acm.csv.yaml

oc get -n open-cluster-management csv "$csv_name" -o yaml >"$csv_path"

sed -i'' -E "s|value: registry\\.redhat\\.io/rhacm2/multicluster-observability-rhel8-operator@(.*)\$|value: $pr_image|g" "$csv_path"
sed -i'' -E "s|image: registry\\.redhat\\.io/rhacm2/multicluster-observability-rhel8-operator@(.*)\$|value: $pr_image|g" "$csv_path"

sed -i'' -E "s|value: quay\\.io/stolostron/multicluster-observability-operator@([^\"]*)\$|value: $pr_image|g" "$csv_path"
sed -i'' -E "s|image: quay\\.io/stolostron/multicluster-observability-operator@([^\"]*)\$|image: $pr_image|g" "$csv_path"

oc apply -f "$csv_path" -n open-cluster-management
rm -rf "$temp_folder"

echo "ClusterServiceVersion for ACM patched. Please wait for the reconciliation loop to update pods"
