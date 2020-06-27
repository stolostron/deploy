get_leaked_namespaces() {
    oc get ns -o name | grep -v openshift | grep -v default | grep -v kube
}

delete_leaked_namespaces() {
    for ns in $(get_leaked_namespaces); do
        oc delete $ns --wait=false
    done 
}

nuke_leaked_namespaces() {
    get_leaked_namespaces
    delete_leaked_namespaces
    evict_wedged_namespaces
}

get_wedged_namespaces() {
    oc get ns --field-selector=status.phase=Terminating -o name
}

evict_wedged_namespaces() {
    for namespace in $(get_wedged_namespaces); do
        evict_namespaced_resources ${namespace}
    done
}

get_namespaced_resources() {
    if [ -z "$1" ]; then
        namespace=$(oc project -q)
    else
        namespace=${1#"namespace/"}
    fi

    for resource in $(oc api-resources -o name --namespaced=true | grep -v operators.coreos.com ); do 
        oc get ${resource} -o name -n ${namespace} 2> /dev/null
    done
}

evict_namespaced_resources() {
    if [ -z "$1" ]; then
        namespace=$(oc project -q)
    else
        namespace=${1#"namespace/"}
    fi

    for resource in $(get_namespaced_resources ${namespace}); do
        remove_finalizer ${resource} ${namespace} 
    done
}

remove_finalizer() {
    if [ -z "$2" ]; then
        oc patch ${1} -p '{"metadata":{"finalizers":[]}}' --type=merge 2> /dev/null
    else
        oc patch ${1} -n ${2#"namespace/"} -p '{"metadata":{"finalizers":[]}}' --type=merge 2> /dev/null
    fi    
}

get_all_wedged_crd() {
    for crd in $(oc get crd -o name | grep -v openshift | grep -v coreos); do 
        [ -z "`oc get $crd -o jsonpath={.metadata.deletionTimestamp}`" ] || echo $crd;
    done
}

evict_wedged_crd() {
    crd=${1#"customresourcedefinition.apiextensions.k8s.io/"}

    if [[ $(oc get customresourcedefinition.apiextensions.k8s.io ${crd} -o jsonpath={.spec.scope}) == "Cluster" ]]; then
        for cr in $(oc get ${crd} -o name); do
            oc delete ${cr} --wait=false
            remove_finalizer ${cr}
        done
    else
        for namespace in $(oc get ${crd} --all-namespaces -o jsonpath='{.items[*].metadata.namespace}'); do
            for cr in $(oc get ${crd} -n ${namespace}); do
                oc delete ${cr} -n ${namespace} --wait=false
                remove_finalizer ${cr} ${namespace}
            done
        done
    fi
}

evict_all_wedged_crd() {
    for crd in $(get_all_wedged_crd); do
        evict_wedged_crd ${crd}
    done
}
