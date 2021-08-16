# Deploying from the Brew Registry

This document overviews the deploy process for ACM from the Brew Registry both using our automation and manually!  The first few steps focus on preparing the cluster for deploy and are common between the automatic and manual deploy methods, so we'll document "The Easy Way" and "The Manual Way" after your cluster is prepared.  

Our auomation, along with this documentation, follows the [official brew deploy documentation](https://docs.engineering.redhat.com/display/CFC/Test).  

## Preparing Your Cluster

### Step 0: Get a Pull Secret for the Brew Registry

The definitive source on this process is the [official brew deploy documentation](https://docs.engineering.redhat.com/display/CFC/Test) and the [employee token manager documentation](https://source.redhat.com/groups/public/teamnado/wiki/brew_registry#obtaining-registry-tokens), but at time of writing, you can get a pull secret for brew.registry.redhat.io via:
```
# Get a Kerberos Ticket
kinit (username)@IPA.REDHAT.COM

# Create token if you don't have one or want a new one:
curl --negotiate -u : -X POST -H 'Content-Type: application/json'          \
    --data '{"description":"(describe what the token will be used for)"}' \
    https://employee-token-manager.registry.redhat.com/v1/tokens -s | jq

# or...

# Query a token you already have:
curl --negotiate -u : \
    https://employee-token-manager.registry.redhat.com/v1/tokens -s | jq
```

### Step 1: Patch the OCP Cluster Pull Secret

#### I Have Podman!

```
# Grab the pull secret off of your OpenShift cluster:
oc get secret/pull-secret -n openshift-config -o json | jq -r '.data.".dockerconfigjson"' | base64 -d > authfile

# Login to the brew registry using your user/pass from Step 0 and this "authfile" to add the token to the pull-secret/authfile
podman login --authfile authfile --username "(username)" --password "(password)" brew.registry.redhat.io

# Write the pull secret (authfile) back to your OpenShift cluster
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=authfile
```

#### I Don't Have Podman!

```
# Grab the pull secret off of your OpenShift cluster:
oc get secret/pull-secret -n openshift-config -o json | jq -r '.data.".dockerconfigjson"' | base64 -d > authfile

#### Manually edit authfile to include the pull secret you acquired in step 0 for brew by encoding the user/pass ####
#### In the end you should have a new entry in the pull secret for brew.registry.redhat.io ####

# Write the pull secret (authfile) back to your OpenShift cluster
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=authfile
```

### Step 2: Deploy an ImageContentSourcePolicy (ICSP)

You need to deploy an ImageContentSourcePolicy (ICSP) to add a Brew as a mirror for requests to other Red Hat registry variants.  The definitive source for this ICSP is, of course, the [official brew deploy documentation](https://docs.engineering.redhat.com/display/CFC/Test), but at the time of writing you can apply the ICSP as follows:

```
oc apply -f - <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: brew-registry
spec:
  repositoryDigestMirrors:
  - mirrors:
    - brew.registry.redhat.io
    source: registry.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry.stage.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry-proxy.engineering.redhat.com
EOF
```

## Deploying ACM from Brew

### The Easy Way (RECOMMNDED)

Run `./brew-start.sh` for a simple deploy experience.  

This does the same thing as the manual steps documented below, only documented and with additional error checking!

You can optionally set these configuration parameters (defaults shown at time of writing, may not remain up to date):
```
# Define your CatalogSource (CatalogSource will reference 'image: ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}')
CATALOGSOURCE_REPO      -   The repo that holds the CatalogSource image, default: "brew.registry.redhat.io/rh-osbs"
CATALOGSOURCE_IMAGE     -   The name of the CatalogSource image found in CATALOGSOURCE_REPO, default: "iib-pub-pending"
CATALOGSOURCE_TAG       -   The tag on the Catalog image to use, default: "v4.7"

# MultiCluster Operator Subscription Channel
SUBSCRIPTION_CHANNEL    -   The subscription channel used for the MCH operator, default: "release-2.3"

# Deploy Config
TARGET_NAMESPACE        -   The namespace in which to deploy the CatalogSoruce, Operator, and MultiClusterHub, default: "open-cluster-management"

# Naming
CATALOGSOURCE_RESOURCE_NAME -   The name of the CatalogSource resource, default: "start-brew-iib"
SUBSCRIPTION_NAME           -   The name of the Subscription resource, default: "start-brew-sub"
```

### The Hard Way (NOT recomended)

#### Step 0: Disable Old CatalogSources

```
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources","value": true}]'
```

#### Step 1: Create the open-cluster-management Namespace

```
oc create ns open-cluster-management
```

#### Step 2: Add the Custom CatalogSource

```
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: start-brew-iib
  namespace: ${TARGET_NAMESPACE}
spec:
  sourceType: grpc
  image: ${CATALOGSOURCE_REPO}/${CATALOGSOURCE_IMAGE}:${CATALOGSOURCE_TAG}
  displayName: Start Brew iib ${CATALOGSOURCE_TAG}
  publisher: grpc
EOF
```

#### Step 4: Create an OperatorGroup

```
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: default
  namespace: ${TARGET_NAMESPACE}
spec:
  targetNamespaces:
  - ${TARGET_NAMESPACE}
EOF
```

#### Step 5: Create a Subscription

```
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${SUBSCRIPTION_NAME}
  namespace: ${TARGET_NAMESPACE}
spec:
  channel: ${SUBSCRIPTION_CHANNEL}
  installPlanApproval: Automatic
  name: advanced-cluster-management
  source: ${CATALOGSOURCE_RESOURCE_NAME}
  sourceNamespace: ${TARGET_NAMESPACE}
EOF
```

#### Step 6: Wait for Operator to Come Online

Watch for the `multiclusterhub-operator` pod to become ready in the `$TARGET_NAMESPACE`

#### Step 7: Create the MultiClusterHub Resource

```
oc apply -f - <<EOF
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: ${TARGET_NAMESPACE}
  annotations: {}
spec: {}
EOF
```

#### Step 8: Wait for the MultiClusterHub Install to Complete

You'll likely want to poll the status array of the mch resource or watch the UI!

#### Step 9: [Optional] Enable Search

```
oc set env deploy search-operator DEPLOY_REDISGRAPH="true" -n ${TARGET_NAMESPACE}
```