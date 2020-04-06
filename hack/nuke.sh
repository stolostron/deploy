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

# Strip out finalizers. This will make orphans!
echo "Strip out finalizers"
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; done
for mch in $(oc get multiclusterhub | tail -n +2 | cut -f 1 -d ' '); do oc patch multiclusterhub $mch --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; done

kubectl delete -k ../multiclusterhub/
kubectl delete -k ../multiclusterhub-operator/

oc project open-cluster-management
remove-apiservices
# cluster deployment cleanup now being done by clean-clusters.sh
# for deployment in $(oc get ClusterDeployment --all-namespaces | tail -n +2 | cut -f 1 -d ' '); do echo "Deleting managed cluster $deployment... this may take a few minutes."; oc delete ClusterDeployment $deployment -n $deployment; echo "done."; done
for cluster in $(oc get Cluster --all-namespaces --ignore-not-found | tail -n +2 | cut -f 1 -d ' '); do oc delete Cluster $cluster && oc delete namespace $cluster --wait=false --ignore-not-found; done

# Deletes all subscriptions in the system
for subscription in $(oc get subscriptions.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc delete subscriptions.apps.open-cluster-management.io $subscription --wait=false --ignore-not-found; done
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; done

#Run through twice, first time initiate all the deletes, 2nd time wait. This makes it more likely if the user runs the finalizer patch there will be NO orphans
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc delete helmreleases.apps.open-cluster-management.io $helmrelease --wait=false --ignore-not-found; done
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc delete helmreleases.apps.open-cluster-management.io $helmrelease --ignore-not-found; done
for policy in $(oc get policies.policy.mcm.ibm.com | tail -n +2 | cut -f 1 -d ' '); do oc patch policies.policy.mcm.ibm.com $policy --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; oc delete policies.policy.mcm.ibm.com $policy --ignore-not-found; done

for webhook in $(oc get validatingwebhookconfiguration | grep cert-manager | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found; done
for configmap in $(oc get configmap  | grep cert-manager | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for configmap in $(oc get configmap | grep ingress-controller | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for apiservice in $(oc get apiservice | grep mcm | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for apiservice in $(oc get apiservice | grep certmanager | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for apiservice in $(oc get apiservice | grep clusterapi.io | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for apiservice in $(oc get apiservice | grep clusterregistry.k8s.io | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for role in $(oc get clusterrole | grep multicluster-mongo | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for role in $(oc get clusterrole | grep cert-manager | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for role in $(oc get clusterrole | grep mcm | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for role in $(oc get clusterrole | grep rcm | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for role in $(oc get clusterrolebinding | grep multicluster-mongo | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found; done
for role in $(oc get clusterrolebinding | grep cert-manager | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found; done
for role in $(oc get clusterrolebinding | grep mcm | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found; done
for role in $(oc get clusterrolebinding | grep rcm | cut -f 1 -d ' '); do oc delete clusterrolebinding $role --ignore-not-found; done
for secret in $(oc get Secret | grep search | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret | grep multicloud | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep cert-manager | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep kui | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep search | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep sh.helm.release | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep topology| cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep console-chart | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done
for secret in $(oc get Secret | grep aws | cut -f 1 -d ' '); do oc delete Secret $secret --ignore-not-found; done

remove-apiservices
oc get crd | grep "hive" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get csv | grep "hive" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
for deployment in $(oc get deploy -n hive | grep hive | cut -f 1 -d ' '); do oc delete deploy $deployment --ignore-not-found; done
for apiservice in $(oc get apiservice | grep hive | cut -f 1 -d ' '); do oc delete apiservice $apiservice --ignore-not-found; done
for role in $(oc get clusterrole | grep hive | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for rolebinding in $(oc get clusterrolebindings | grep hive | cut -f 1 -d ' '); do oc delete clusterrolebinding $rolebinding --ignore-not-found; done
for webhook in $(oc get validatingwebhookconfiguration | grep hive | cut -f 1 -d ' '); do oc delete validatingwebhookconfiguration $webhook --ignore-not-found; done
for configmap in $(oc get configmap -n hive | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep hive | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep console | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep kui | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep management-ingress | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep sh.helm.release.v1 | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
for secret in $(oc get Secret -n hive | grep topology | cut -f 1 -d ' '); do oc delete Secret $secret -n hive --ignore-not-found; done
oc delete namespace hive --wait=false

for deployment in $(oc get Deployments | cut -f 1 -d ' '); do oc delete Deployment $deployment --ignore-not-found; done
for subscription in $(oc get subscription | cut -f 1 -d ' '); do oc delete subscription $subscription --ignore-not-found; done
for role in $(oc get clusterrole | grep open-cluster-management | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
for role in $(oc get clusterrole | grep multicluster | cut -f 1 -d ' '); do oc delete clusterrole $role --ignore-not-found; done
oc get csv | grep "multicluster" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get csv | grep "multicloud" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get crd | grep "open-cluster-management.io" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get crd | grep "acm.io" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true

oc delete consolelink acm-console-link
oc delete clusterrole search-collector
oc delete clusterrolebinding search-collector

oc get service | grep "multicluster" | awk '{ print $1 }' | xargs oc delete service --wait=false --ignore-not-found || true
for secret in $(oc get Secret -n open-cluster-management | grep multicluster | cut -f 1 -d ' '); do oc delete Secret $secret -n open-cluster-management --ignore-not-found; done
for configmap in $(oc get configmap -n open-cluster-management | tail -n +2 | cut -f 1 -d ' '); do oc delete configmap $configmap -n open-cluster-management --ignore-not-found; done
oc get csv | grep "etcd" | awk '{ print $1 }' | xargs oc delete csv --wait=false --ignore-not-found || true
oc get crd | grep "etcd" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get scc | grep "multicluster" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get scc | grep "multicloud" | awk '{ print $1 }' | xargs oc delete scc --wait=false --ignore-not-found || true
oc get crd | grep "certmanager" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get crd | grep "mcm" | awk '{ print $1 }' | xargs oc delete crd --wait=false --ignore-not-found || true
oc get clusterrole | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete clusterrole --wait=false --ignore-not-found || true
oc get clusterrolebinding | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete clusterrolebinding --wait=false --ignore-not-found || true
oc get mutatingwebhookconfiguration | grep "cert-manager" | awk '{ print $1 }' | xargs oc delete mutatingwebhookconfiguration --wait=false --ignore-not-found || true

cd ../
echo DESTROY | ./uninstall.sh