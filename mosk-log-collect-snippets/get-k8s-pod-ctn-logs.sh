#!/bin/bash
#~omadjoudj
# Get K8s pod/container logs from a given namespace

namespace=$1

echo "Collecting logs from the namespace $namespace:"

kubectl get pods --namespace $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | \
    while read -r pod; do
        kubectl logs "$pod" --namespace $namespace --all-containers --prefix --timestamps > ${namespace}__${pod}.log
        echo -n '.'
    done
echo
