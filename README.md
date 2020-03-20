
# Deploy Open Cluster Management

Here you will find a set of k8s yaml definitions that can be used to deploy Open Cluster Management (`OCM`) on OpenShift.

Note that the org `github.com/open-cluster-management` is the upstream staging area for a new product to be introduced, named "Red Hat Advanced Cluster Management for Kubernetes (`RHACM4K` pronounced \`rack-um-4k\` or for short `RHACM` pronounced \`rack-um\`)". The GitHub org and product are currently distinct from the SaaS offering named "Red Hat OpenShift Cluster Manager" but will ultimately co-exist/share technology as needed. Core technology such as [github.com/openshift/hive](https://github.com/openshift/hive) is already shared between the two offerings.

You can find our __work-in-progress__ documentation [here](https://github.com/open-cluster-management/rhacm-docs/blob/doc_stage/summary.md).  Please read through the docs to find information on what Open Cluster Management is and how you can use it. Oh and please submit PR's for any issues you may find or clarifications you might suggest.

You can find information on how to contribute to this project and our docs project in our [CONTRIBUTING.md](CONTRIBUTING.md) doc.

Let's get started...

#### Prereqs
- you have an OCP 4.3+ cluster available
- you have oc & kubectl (ver. 1.16+) configured to connect to your running OCP 4.3+ cluster
- you're oc is configured with adequet permissions to create new namespaces in your OCP cluster.

This repo defines 3 directories:
  - `prereqs` - contains yaml definitions for prerequisite objects (namespaces and pull-secrets)
  - `multiclusterhub-operator` - contains yaml definitions for setting up a `CatalogSource` for `multiclusterhub-operator`
  - `multiclusterhub` - contains yaml definitions for creating an instance of `MultiClusterHub` object type

Each of the three directories contains a `kustomization.yaml` file that will apply the yaml definitions to your OCP instance using `kubectl apply`.

## Prepare to deploy MultiClusterHub Instance (do these tasks only ONCE)

1. clone this repo locally
    ```bash
    git clone https://github.com/open-cluster-management/deploy.git
    ```

2. generate a pull-secret
   1. ensure you have access to the quay org by following this link:  [open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags)
   2. if you do not have access to the [open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags) org in quay.io you can request access on our Slack Channel [#forum-acm]([https://](https://coreos.slack.com/archives/CTDEY6EEA)).
   3. go to [https://quay.io/user/tpouyer?tab=settings](https://quay.io/user/tpouyer?tab=settings) replacing `tpouyer` with your username
   4. click on `Generate Encrypted Password`
   5. enter your quay.io password
   6. select `Kubernetes Secret` from left-hand menu
   7. click on `Download tpouyer-secret.yaml` except `tpouyer` will be your username
   8.  save secret file in the `prereqs` directory as `pull-secret.yaml`
   9.  edit `pull-secret.yaml` file and change the name to `multiclusterhub-operator-pull-secret`
      ```bash
      apiVersion: v1
      kind: Secret
      metadata:
        name: multiclusterhub-operator-pull-secret
      ...
      ```

## Deploy using the ./start.sh script

We've added a very simple `start.sh` script to make your life easier... if you want to deploy `OCM` the __"hard way"__ you can find the instructions for deploying `OCM` using nothing but `oc` commands [here](#manually-deploy-using-only-oc-commands).

1. Run the `start.sh` script (see )
Options:  (Only use one at a time)
```
-t modify the YAML but exit before apply the resources
--silent, skip all prompting, uses the previous configuration
--watch, will monitor the main Red Hat ACM pod deployments for up to 10min
```

2. When prompted for the SNAPSHOT tag, either press `Enter` to use the previous tag, or provide a new tag.<br>
Example:  (_Find snapshot tags here:_ https://quay.io/open-cluster-management/multiclusterhub-operator-index)
```bash
1.0.0-SNAPSHOT-2020-03-13-23-07-54
```
2. Depending on your script Option choice, `OCM` will be deployed or deploying. Use 'watch oc -n open-cluster-management get pods' to view the progress.

3. The script provides you with the `Open Cluster Management` URL

Note: This script can be run multiple times and will attempt to continue where it left off. It is also good practice to run the `uninstall.sh` script if you have a failure and have installed multiple times.

## Manually deploy using only `oc` commands

1. generate quay-secret
   1. ensure you have access to the quay org by following this link:  [open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags)
   2. if you do not have access to the [open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags) org in quay.io you can request access on our Slack Channel [#forum-acm]([https://](https://coreos.slack.com/archives/CTDEY6EEA)).
   3. go to [https://quay.io/user/tpouyer?tab=settings](https://quay.io/user/tpouyer?tab=settings) replacing `tpouyer` with your username
   4. click on `Generate Encrypted Password`
   5. enter your quay.io password
   6. select `Kubernetes Secret` from left-hand menu
   7. click on `Download tpouyer-secret.yaml` except `tpouyer` will be your username
   8.  save secret file in the `prereqs` directory as `pull-secret.yaml`
   9.  edit `pull-secret.yaml` file and change the name to `multiclusterhub-operator-pull-secret`
      ```bash
      apiVersion: v1
      kind: Secret
      metadata:
        name: multiclusterhub-operator-pull-secret
      ...
      ```

2. create the prereq objects by applying the yaml definitions contained in the `prereqs` dir:
  ```bash
  kubectl apply --openapi-patch=true -k prereqs/
  ```

3. update the `kustomization.yaml` file in the `multiclusterhub-operator` dir to set `newTag`
  You can find a snapshot tag by viewing the list of tags available [here](https://quay.io/open-cluster-management/multiclusterhub-operator-index) Use a tag that has the word `SNAPSHOT` in it.
    ```bash
    namespace: open-cluster-management

    images: # updates operator.yaml with the dev image
      - name: multiclusterhub-operator-index
        newName: quay.io/open-cluster-management/multiclusterhub-operator-index
        newTag: "1.0.0-SNAPSHOT-2020-03-13-23-07-54"
    ```

4. create the `multiclusterhub-operator` objects by applying the yaml definitions contained in the `multiclusterhub-operator` dir:
    ```bash
    kubectl apply -k multiclusterhub-operator/
    ```

5. Wait for subscription to be healthy:
    ```bash
    oc get subscription multiclusterhub-operator-bundle --namespace open-cluster-management -o yaml
    ...
    status:
      catalogHealth:
      - catalogSourceRef:
          apiVersion: operators.coreos.com/v1alpha1
          kind: CatalogSource
          name: open-cluster-management
          namespace: open-cluster-management
          resourceVersion: "1123089"
          uid: f6da232b-e7c1-4fc6-958a-6fb1777e728c
        healthy: true
        ...
    ```

6. Once the `open-cluster-management` CatalogSource is healthy you can deploy the `example-multiclusterhub-cr.yaml`
   - edit the `example-multiclusterhub-cr.yaml` file in the `mulitclusterhub` dir
     - set `imageTagSuffix` to the snapshot value used in the `kustomization.yaml` file in the `multiclusterhub-operator` dir above<br>_**Note:** Make sure to remove the VERSION 1.0.0-, from the newTag value taken from kustomization.yaml**_
    ```bash
    apiVersion: operators.open-cluster-management.io/v1alpha1
    kind: MultiClusterHub
    metadata:
      name: example-multiclusterhub
      namespace: open-cluster-management
    spec:
      version: latest
      imageRepository: "quay.io/open-cluster-management"
      imageTagSuffix: "SNAPSHOT-2020-03-17-21-24-18"
      imagePullPolicy: Always
      imagePullSecret: multiclusterhub-operator-pull-secret
      foundation:
        apiserver:
          configuration:
            http2-max-streams-per-connection: "1000"
          replicas: 1
          apiserverSecret: "mcm-apiserver-self-signed-secrets"
          klusterletSecret: "mcm-klusterlet-self-signed-secrets"
        controller:
          configuration:
            enable-rbac: "true"
            enable-service-registry: "true"
          replicas: 1
      mongo:
        endpoints: mongo-0.mongo.open-cluster-management
        replicaSet: rs0
      hive:
        additionalCertificateAuthorities:
          - name: letsencrypt-ca
        managedDomains:
          - s1.openshiftapps.com
        globalPullSecret:
          name: private-secret
        failedProvisionConfig:
          skipGatherLogs: true
    ```

7. create the `example-multiclusterhub` objects by applying the yaml definitions contained in the `multiclusterhub` dir:
    ```bash
    kubectl apply -k multiclusterhub/
    ```

## To Delete a MultiClusterHub Instance

1. Delete the `example-multiclusterhub` objects by deleting the yaml definitions contained in the `multiclusterhub` dir:
    ```bash
    kubectl delete -k multiclusterhub/
    ```

2. Not all objects are currently being cleaned up by the `multiclusterhub-operator` upon deletion of a `multiclusterhub` instance... you can ensure all objects are cleaned up by executing the `uninstall.sh` script in the `multiclusterhub` dir:
    ```bash
    ./multiclusterhub/uninstall.sh
    ```

After completing the steps above you can redeploy the `multiclusterhub` instance by simply running:
    ```bash
    kubectl apply -k multiclusterhub/
    ```

## To Delete the multiclusterhub-operator

1. Delete the `multiclusterhub-operator` objects by deleting the yaml definitions contained in the `multiclusterhub-operator` dir:
    ```bash
    kubectl delete -k multiclusterhub-operator/
    ```

2. Not all objects are currently being cleaned up by the `multiclusterhub-operator` upon deletion... you can ensure all objects are cleaned up by executing the `uninstall.sh` script in the `multiclusterhub-operator` dir:
    ```bash
    ./multiclusterhub-operator/uninstall.sh
    ```

After completing the steps above you can redeploy the `multiclusterhub-operator` by simply running:
    ```bash
    kubectl apply -k multiclusterhub-operator/
    ```

## To Redeploy the multiclusterhub-operator

1. Repeat deployment steps starting at step 5 above under the [To Deploy a multiclusterHub Instance](#to-deploy-a-multiclusterhub-instance) section
