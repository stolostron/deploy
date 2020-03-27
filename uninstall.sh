#!/bin/bash

VER=$(oc version | grep "Client Version:")

if [[ $VER =~ .*[4-9]\.[3-9]\..* ]]
then
    delete_command="oc delete -k"

else
    delete_command="kubectl delete -k"
fi

    $delete_command multiclusterhub/ --ignore-not-found
    ./multiclusterhub/uninstall.sh

    $delete_command multiclusterhub-operator/ --ignore-not-found
    ./multiclusterhub-operator/uninstall.sh