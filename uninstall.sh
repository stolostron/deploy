#!/bin/bash


kubectl delete -k multiclusterhub/ --ignore-not-found
./multiclusterhub/uninstall.sh

kubectl delete -k multiclusterhub-operator/ --ignore-not-found
./multiclusterhub-operator/uninstall.sh