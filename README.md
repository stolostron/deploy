
# Deploy Open Cluster Management (OCM)

### Welcome!

You might be asking yourself "What is Open Cluster Management", well... the org `github.com/open-cluster-management` is the upstream staging area for a new product to be introduced, named "Red Hat Advanced Cluster Management for Kubernetes (`RHACM4K` pronounced \`rack-um-4k\` or for short `RHACM` pronounced \`rack-um\`)".

>The GitHub org and product are currently distinct from the SaaS offering named "Red Hat OpenShift Cluster Manager" but will ultimately co-exist/share technology as needed. Core technology such as [github.com/openshift/hive](https://github.com/openshift/hive) is already shared between the two offerings.

Kubernetes provides a platform for deploying and managing containers in a standard, consistent control plane. However, as applications workloads move from development to production, they often require multiple fit for purpose Kubernetes clusters to support DevOps pipelines. Users, such as administrators and site reliability engineers, face challenges as they work across a range of environments, including multiple data centers, private clouds, and public clouds that run Kubernetes clusters. Red Hat Advanced Cluster Management for Kubernetes provides the tools and capabilities to address these common challenges.

Red Hat Advanced Cluster Management for Kubernetes provides end-to-end management visibility and control to manage your Kubernetes environment. Take control of your application modernization program with management capabilities for cluster creation, application lifecycle, and provide security and compliance for all of them across data centers and hybrid cloud environments. Clusters and applications are all visible and managed from a single console, with built-in security policies. Run your operations from anywhere that Red Hat OpenShift runs, and manage any Kubernetes cluster in your fleet.

With Red Hat Advanced Cluster Management for Kubernetes:

  - Work across a range of environments, including multiple data centers, private clouds and public clouds that run Kubernetes clusters.
  - Easily create Kubernetes clusters and offer cluster lifecycle management in a single console.
  - Enforce policies at the target clusters using Kubernetes-supported custom resource definitions.
  - Deploy and maintain day-two operations of business applications distributed across your cluster landscape.

## Let's get started...

You can find our __work-in-progress__ documentation [here](https://github.com/open-cluster-management/rhacm-docs/blob/doc_prod/README.md).  Please read through the docs to find out how you can use OCM. Oh and please submit issues for any problems you may find or clarifications you might suggest.

You can find information on how to contribute to this project and our docs project in our [CONTRIBUTING.md](CONTRIBUTING.md) doc.

#### Prereqs
- an OpenShift Container Platform (OCP) 4.3+ cluster available
  - must have a default storage class defined
- `oc` (ver. 4.3+) & `kubectl` (ver. 1.16+) configured to connect to your OCP cluster
- `oc` is connected with adequate permissions to create new namespaces in your OCP cluster.
- macOS users:
   - `gsed` is required. Install using `brew install gnu-sed`
   - `watch` is optional. Install using `brew install watch`

#### Repo Structure and Organization
This repo contains 3 directories:
  - `prereqs` - yaml definitions for prerequisite objects (namespaces and pull-secrets)
  - `multiclusterhub-operator` - yaml definitions for setting up a `CatalogSource` for our operator
  - `multiclusterhub` - yaml definitions for creating an instance of `MultiClusterHub`

Each of the three directories contains a `kustomization.yaml` file that will apply the yaml definitions to your OCP instance using `kubectl apply -k`.

You will find __helper__ scripts in the root of this repo:
  - `start.sh` - takes the edge off having to hand edit yaml files
  - `uninstall.sh` - we're not perfect yet... includes additional scripting to ensure we clean up our mess on your OCP cluster.

You have two choices of installation...
  - [the easy way](#deploy-using-the-startsh-script-the-easy-way) - using the provided `start.sh` script which will hand hold you through the process
  - [the hard way](#manually-deploy-using-kubectl-commands-the-hard-way) - using nothing but `oc` commands and you'll need to edit some yaml

Either way you choose to go you're gonna need a `pull-secret`... we are still in early development stage and yes we do plan on open sourcing all of our code but... lawyers, gotta do some more due diligence before we can open up to the world.  In the mean time you'll require access to our built images residing in our private [quay.io/open-cluster-management](https://quay.io/open-cluster-management) org. Please follow the instructions [Prepare to deploy Open Cluster Management Instance](#prepare-to-deploy-open-cluster-management-instance-only-do-once) to get your `pull-secret` setup.

## Prepare to deploy Open Cluster Management Instance (only do once)

1. clone this repo locally
    ```bash
    git clone https://github.com/open-cluster-management/deploy.git
    ```

2. generate your pull-secret
   - ensure you have access to the quay org ([open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags))
     - to request access to [open-cluster-management](https://quay.io/repository/open-cluster-management/multiclusterhub-operator-index?tab=tags) in quay.io please contact us on our Slack Channel [#forum-acm](https://coreos.slack.com/archives/CTDEY6EEA)).
   - go to [https://quay.io/user/tpouyer?tab=settings](https://quay.io/user/tpouyer?tab=settings) replacing `tpouyer` with your username
   - click on `Generate Encrypted Password`
   - enter your quay.io password
   - select `Kubernetes Secret` from left-hand menu
   - click on `Download tpouyer-secret.yaml` except `tpouyer` will be your username
   - save secret file in the `prereqs` directory as `pull-secret.yaml`
   - edit `pull-secret.yaml` file and change the name to `multiclusterhub-operator-pull-secret`
      ```bash
      apiVersion: v1
      kind: Secret
      metadata:
        name: multiclusterhub-operator-pull-secret
      ...
      ```

## Deploy using the ./start.sh script (the easy way)

We've added a very simple `start.sh` script to make your life easier... if you want to deploy `OCM` the __"hard way"__ you can find the instructions for deploying `OCM` using nothing but `oc` commands [here](#manually-deploy-using-oc-commands-the-hard-way).

1. Run the `start.sh` script (see )
Options:  (Only use one at a time)
```
-t modify the YAML but exit before apply the resources
--silent, skip all prompting, uses the previous configuration
--watch, will monitor the main Red Hat ACM pod deployments for up to 10min

$>: ./start.sh --watch
```

2. When prompted for the SNAPSHOT tag, either press `Enter` to use the previous tag, or provide a new SNAPSHOT tag.<br>
Example:  (_Find snapshot tags here:_ https://quay.io/open-cluster-management/multiclusterhub-operator-index)
```bash
1.0.0-SNAPSHOT-2020-03-13-23-07-54
```
  NOTE: To change the default SNAPSHOT tag, edit `snapshot.ver`, which contains a single line that specifies the SNAPSHOT tag.  This method of updating the default SNAPSHOT tag is useful when using the `--silent` option.
2. Depending on your script Option choice, `OCM` will be deployed or deploying. Use 'watch oc -n open-cluster-management get pods' to view the progress.

3. The script provides you with the `Open Cluster Management` URL

Note: This script can be run multiple times and will attempt to continue where it left off. It is also good practice to run the `uninstall.sh` script if you have a failure and have installed multiple times.

## Manually deploy using `kubectl` commands (the hard way)

1. create the prereq objects by applying the yaml definitions contained in the `prereqs` dir:
  ```bash
  kubectl apply --openapi-patch=true -k prereqs/
  ```

2. update the `kustomization.yaml` file in the `multiclusterhub-operator` dir to set `newTag`
  You can find a snapshot tag by viewing the list of tags available [here](https://quay.io/open-cluster-management/multiclusterhub-operator-index) Use a tag that has the word `SNAPSHOT` in it.
    ```bash
    namespace: open-cluster-management

    images: # updates operator.yaml with the dev image
      - name: multiclusterhub-operator-index
        newName: quay.io/open-cluster-management/multiclusterhub-operator-index
        newTag: "1.0.0-SNAPSHOT-2020-03-13-23-07-54"
    ```

3. create the `multiclusterhub-operator` objects by applying the yaml definitions contained in the `multiclusterhub-operator` dir:
    ```bash
    kubectl apply -k multiclusterhub-operator/
    ```

4. Wait for subscription to be healthy:
    ```bash
    oc get subscription.operators.coreos.com multiclusterhub-operator-bundle --namespace open-cluster-management -o yaml
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

5. Once the `open-cluster-management` CatalogSource is healthy you can deploy the `example-multiclusterhub-cr.yaml`
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

6. create the `example-multiclusterhub` objects by applying the yaml definitions contained in the `multiclusterhub` dir:
    ```bash
    kubectl apply -k multiclusterhub/
    ```

## To Delete a MultiClusterHub Instance (the easy way)

1. run the `uninstall.sh` script in the root of this repo

## To Delete a MultiClusterHub Instance (the hard way)

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

## To Delete the multiclusterhub-operator (the easy way)

1. run the `clean-clusters.sh` script, and enter `DESTROY` to delete any Hive deployments and detach all imported clusters
2. run the `uninstall.sh` script in the root of this repo

### Troubleshooting
1. If uninstall hangs on the helmRelease delete, you can run this command to move it along.  This is distructive and can result in orphaned objects.
```bash
for helmrelease in $(oc get helmreleases.apps.open-cluster-management.io | tail -n +2 | cut -f 1 -d ' '); do oc patch helmreleases.apps.open-cluster-management.io $helmrelease --type json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'; done
```

## To Delete the multiclusterhub-operator (the hard way)

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
