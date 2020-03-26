
## Overview

### How to use kind to validate Cluster imports
```
GO111MODULE="on" go get sigs.k8s.io/kind@v0.7.0
export PATH=$PATH:$GOPATH/bin
kind create cluster --name=bekind

kubectl config use-context kind-bekind
kubectl get pods --all-namespaces
```

### How to import a kind cluster into a hub

1. Create a cluster via `kind`.
```bash
kind create cluster sydney-cluster
```
2. Edit the `kind-cluster.yaml` to have the correct `clusterName` and `clusterNamespace`. These resources should be applied to the **Hub**.
```bash
kubectl apply -f kind-cluster.yaml
```
3. Copy an authorized `$KUBECONFIG` copiyed into `kubeconfig`. The hub `kubeconfig` will be used to create the `klusterlet-bootstrap` secret on the managed cluster.
4. Edit the `clusterName` and `clusterNamespace` in `endpoint.yaml` (These values are not substituted yet by `kustomize`). Then apply the `kustomization`.
```bash
kubectl apply -k import/
```
