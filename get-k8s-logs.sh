#!/bin/bash
#~omadjoudj
# Get K8s pod/container logs from a given namespace


if [ $# -eq 2 ]; then
    namespace=$1
    pod_substring=$2

    echo "Collecting logs from the namespace $namespace and filtering only pod containing $pod_substring"
    kubectl get pods --namespace $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep $pod_substring | \
    while read -r pod; do
        kubectl logs "$pod" --namespace $namespace --all-containers --prefix --timestamps > ${namespace}__${pod}.log
        echo -n '.'
    done
elif [ $# -eq 1 ]; then
    namespace=$1
    echo "Collecting logs from the namespace $namespace:"
    kubectl get pods --namespace $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'  | \
    while read -r pod; do
        kubectl logs "$pod" --namespace $namespace --all-containers --prefix --timestamps > ${namespace}__${pod}.log
        echo -n '.'
    done
else
    echo "Usage: $0 <namespace> [sub string in pod name]>"
    exit 1
fi

echo
