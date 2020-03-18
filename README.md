
# Deploy Open Cluster Management

#### Prereqs
- you have an OCP 4.3 cluster running somewhere
- you have oc & kubectl (ver. 1.16+) configured to connect to your running OCP 4.3 cluster
  *NOTE* if neither of these is true you can use [bootstrap](https://github.com/open-cluster-management/bootstrap) to stand up an OCP 4.x cluster running in AWS

This repo defines 3 directories:
  - `prereqs` - contains yaml definitions for prerequisite objects (like namespaces)
  - `multiclusterhub-operator` - contains yaml definitions for setting up a `CatalogSource` for `multiclusterhub-operator`
  - `multiclusterhub` - contains yaml definitions for creating an instance of `MultiClusterHub` object type

Each of the three directories contains a `kustomization.yaml` file that will apply the yaml definitions to your OCP instance using `kubectl apply -k .` when run within the requiste directory.

## Prepare to deploy MultiClusterHub Instance (ONCE)

1. clone this repo locally
  ```bash
  git clone https://github.com/open-cluster-management/deploy.git
  ```

2. cd into cloned dir `cd deploy`

3. generate quay-secret
   1. go to [https://quay.io/user/tpouyer?tab=settings](https://quay.io/user/tpouyer?tab=settings) replacing `tpouyer` with your username
   2. click on `Generate Encrypted Password`
   3. enter your quay.io password
   4. select `Kubernetes Secret` from left-hand menu
   5. click on `Download tpouyer-secret.yaml` except `tpouyer` will be your username
   6.  save secret file in the `prereqs` directory as `pull-secret.yaml`
   7.  edit `pull-secret.yaml` file and change the name to `multiclusterhub-operator-pull-secret`
      ```bash
      apiVersion: v1
      kind: Secret
      metadata:
        name: multiclusterhub-operator-pull-secret
      ...
      ```

## Deploy using the ./start.sh script
1. Run the `start.sh` script
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
2. Depending on your script Option choice, Red Hat ACM will be deployed or deploying. Use 'watch oc -n open-cluster-management get pods' to view the progress.

3. The script provides you with the `Red Hat Advanced Cluster Management for Kubernetes` URL

Note: This script can be run multiple times and will attempt to continue where it left off. It is also good practice to run the uninstall steps if you have a failure and have installed multiple times.

## Manually deploy
1. create the prereq objects by applying the yaml definitions contained in the `prereqs` dir:
  ```bash
  cd prereqs
  kubectl apply -k .
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
  cd multiclusterhub-operator
  kubectl apply -k .
  ```

4. Wait for subscription to be healthy:
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

5. Once the `open-cluster-management` CatalogSource is healthy you can deploy the `example-multiclusterhub-cr.yaml`
   - edit the `example-multiclusterhub-cr.yaml` file in the `mulitclusterhub` dir
     - set `ocpHost` to your clustername.basedomain name
     ```bash
     # clustername.basedomain in terraform.tfvars.json or run the following:
     oc -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'
     ```
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
    imageTagSuffix: "SNAPSHOT-2020-03-13-23-07-54"
    imagePullPolicy: Always
    imagePullSecret: multiclusterhub-operator-pull-secret
    ocpHost: "blue.demo.red-chesterfield.com"
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

6. Create the `example-multiclusterhub` objects by applying the yaml definitions contained in the `multiclusterhub` dir:
  ```bash
  cd multiclusterhub
  kubectl apply -k .
  ```

## To Delete a MultiClusterHub Instance

1. Delete the `example-multiclusterhub` objects by deleting the yaml definitions contained in the `multiclusterhub` dir:
  ```bash
  cd multiclusterhub
  kubectl delete -k .
  ```

2. Not all objects are currently being cleaned up by the `multiclusterhub-operator` upon deletion of a `multiclusterhub` instance... you can ensure all objects are cleaned up by executing the `uninstall.sh` script in the `multiclusterhub` dir:
  ```bash
  cd multiclusterhub
  ./uninstall.sh
  ```

After completing the steps above you can redeploy the `multiclusterhub` instance by simply running:
  ```bash
  cd multiclusterhub
  kubectl apply -k .
  ```

## To Delete the multiclusterhub-operator

1. Delete the `multiclusterhub-operator` objects by deleting the yaml definitions contained in the `multiclusterhub-operator` dir:
  ```bash
  cd multiclusterhub-operator
  kubectl delete -k .
  ```

2. Not all objects are currently being cleaned up by the `multiclusterhub-operator` upon deletion... you can ensure all objects are cleaned up by executing the `uninstall.sh` script in the `multiclusterhub-operator` dir:
  ```bash
  cd multiclusterhub-operator
  ./uninstall.sh
  ```

After completing the steps above you can redeploy the `multiclusterhub-operator` by simply running:
  ```bash
  cd multiclusterhub-operator
  kubectl apply -k .
  ```
## To Redeploy the multiclusterhub-operator

1. Repeat deployment steps starting at step 5 above under the [To Deploy a multiclusterHub Instance](#to-deploy-a-multiclusterhub-instance) section


## TL;DR

## Advanced Usage

Let's say you are working on an image used by one of the `helmreleases` deployed via the `multiclusterhub-operator`.  Let's say  you have a new version of one of those images and you'd like to deploy that image in a running environment. You can utilize this repo to help you do that.

### To Deploy a newer Image into your environment

You'll need to identify the subscription that was used to deploy the chart that owns your image... You can do that by querying OCP for `subscription.app.ibm.com` types:
```bash
oc get subscription.app.ibm.com
```

Once you have identified the name of the specific subscription that is responsible for deploying your helm chart you'll need to create a file with it's yaml contents.  Let's say we want to update the image reference for the `console-sub` subscription... we need to create a new dir with a name we can recognize like `console-sub`
```bash
mkdir console-sub
```

Now we need to dumpt the contents of the `console-sub` object into a file:
```bash
cd console-sub
oc get subscription.app.ibm.com console-sub -o yaml > subscription.yaml
```

Great... now let's create a new `kustomization.yaml` file in the `console-sub` directory:
```bash
cat <<EOF >>kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

generatorOptions:
  disableNameSuffixHash: true

# namespace to deploy all Resources to
namespace: open-cluster-management

resources:
- subscription.yaml
EOF
```

Now we have everything we need to be able to `patch` in our new image ref into the `console-sub` subscription object... You'll need to open the `subscription.yaml` file in an editor and look for the  `image:` references... you won't see a `tag:` reference under the `image:` reference due to the use of `imageTagPostfix:`... so you'll need to delete the `imageTagPostfix:` attribute and add new `tag:` attributes to each of the `image:` references with the values of the tags you want to use for each image:
```bash
...
spec:
  channel: open-cluster-management/charts-v1
  name: console-chart
  packageOverrides:
  - packageName: console-chart
    packageOverrides:
    - path: spec.values
      value: |
        pullSecret: "quay-secret"
        consoleui:
          image:
            repository: "quay.io/open-cluster-management/console-ui"
            tag: "1.0.0-823862ef548d1b3f659370f55a9f23c54e0c0113"
            pullPolicy: "Always"
        consoleapi:
          image:
            repository: "quay.io/open-cluster-management/console-api"
            tag: "1.0.0-73c0a58f5e00bfafabffd431dc8c25c7249189d0"
            pullPolicy: "Always"
        cfcRouterUrl: "https://management-ingress:443"
        consoleheader:
          image:
            repository: "quay.io/open-cluster-management/console-header"
            tag: "1.0.0-SNAPSHOT-2020-03-10-03-59-15"
            pullPolicy: "Always"
...
```

Once you've updated the `subscription.yaml` file with you're new tags you can simply apply the resource to your running environment:
```bash
cd console-sub
kubectl apply -k .
```

The `console-sub` subscription object will be `patched` with you changes and you should see the pods deployed via the `console-sub`'s helm chart start to redeploy and they will use your updated image references!

Keep in mind that if you require changes to your helm-chart this method will not work :-( This will only work for updating objects in your running environment that can by manipulated via kubectl... currently the `multiclusterhub-operator` deploys helm charts by deploying an image `multiclusterhub-operator-repo` that contains `tar gz` archives of each helm chart... that's not an easy update via `kubectl` but I'll work on a solution for that as well.