# Cleanup Offline Managed Cluster
When detaching an offline managed cluster on your hub, the resources imported on managed cluster will not be removed.

To properly cleanup your managed cluster, you can use a hack script we provided [/hack/cleanup-managed-cluster.sh](/hack/cleanup-managed-cluster.sh)

Steps:
1. make sure you have `oc` cli, and make sure you have KUBECONFIG set up properly for your managed cluster
    - if you run `oc get ns | grep open-cluster-management-agent` you should see two namespaces:
    ```
    open-cluster-management-agent         Active   10m
    open-cluster-management-agent-addon   Active   10m
    ```
2. run the script `./cleanup-managed-cluster.sh`
3. run `oc get ns | grep open-cluster-management-agent` to see both namespace are properly removed