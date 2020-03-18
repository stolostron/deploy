#!/bin/bash

# apply prereqs
oc apply -k prereqs/

# apply operator
oc apply -k multiclusterhub-operator/

# wait for operator to deploy
echo "pause 60s to wait for multiclusterhub operator to complete installation"
sleep 60

# apply operator cr
oc apply -k multiclusterhub/
