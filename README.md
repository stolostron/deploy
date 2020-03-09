# deploy
Deploy Open Cluster Management

- generate quay-secret
  - go to [https://quay.io/user/tpouyer?tab=settings](https://quay.io/user/tpouyer?tab=settings) replacing `tpouyer` with your username
  - click on `Generate Encrypted Password`
  - enter your quay.io password
  - select `Kubernetes Secret` from left-hand menu
  - click on `Download tpouyer-secret.yaml` except `tpouyer` will be your username
  - save secret file in root of this repo directory as `quay-secret.yaml`

- update `kustomization.yaml` file to set `namespace` and `newTag`
  You can find a snapshot tag by viewing the list of tags available [here](https://quay.io/open-cluster-management/multicloudhub-operator-index) Use a tag that has the word `SNAPSHOT` in it.
    ```bash
    namespace: open-cluster-management

    images: # updates operator.yaml with the dev image
      - name: multicloudhub-operator-index
        newName: quay.io/open-cluster-management/multicloudhub-operator-index
        newTag: "1.0.0-SNAPSHOT-2020-03-02-20-35-12"
     ```

- apply kubectl
  - run `kubectl apply -k .`
