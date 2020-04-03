#!/bin/bash

VER=$(oc version | grep "Client Version:")

if ! [[ $VER =~ .*[4-9]\.[3-9]\..* ]]; then
    echo "oc cli version 4.3 or greater required. Please visit https://access.redhat.com/downloads/content/290/ver=4.3/rhel---8/4.3.9/x86_64/product-software."
    exit 1
fi

oc delete -k multiclusterhub/ --ignore-not-found ./multiclusterhub/uninstall.sh

oc delete -k multiclusterhub-operator/ --ignore-not-found ./multiclusterhub-operator/uninstall.sh