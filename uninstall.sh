#!/bin/bash


oc delete -k multiclusterhub/ --ignore-not-found
./multiclusterhub/uninstall.sh

oc delete -k multiclusterhub-operator/ --ignore-not-found
./multiclusterhub-operator/uninstall.sh