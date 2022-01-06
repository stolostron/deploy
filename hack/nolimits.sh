#!/bin/bash

# Remove all limits on OCM pods https://github.com/stolostron/backlog/issues/1073

kubectl patch deploy $(kubectl get deploy -l component=applicationui -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy kui-web-terminal \
    --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=mcm-grcui -o  jsonpath='{.items[0].metadata.name }') \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=mcm-grcuiapi -o  jsonpath='{.items[0].metadata.name }') \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=mcm-policy-propogator -o  jsonpath='{.items[0].metadata.name }') \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=consoleui -o  jsonpath='{.items[0].metadata.name }') \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=consoleapi -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app=cert-manager -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app=webhook -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app=cainjector -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app.kubernetes.io/name=configmap-watcher -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=console-header -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app=multiclusterhub-repo -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app=rcm-api -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l app=rcm-controller -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=redisgraph -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=search-aggregator -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=search-api -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=search-collector -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=mcm-topology -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'

kubectl patch deploy $(kubectl get deploy -l component=mcm-topologyapi -o  jsonpath='{.items[0].metadata.name }')  \
   --type='json' -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'