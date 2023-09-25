#!/bin/bash
#~omadjoudj
# Get K8s pod/container logs from a given namespace

namespace=$1

echo "Collecting logs from the namespace $namespace:"

kubectl get pods --namespace $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | \
    while read -r pod; do
        containers=$(kubectl get pod "$pod" --namespace $namespace -o jsonpath='{range .spec.containers[*]}{.name}{" "}{end}')
        for container in $containers; do
            kubectl logs "$pod" --namespace $namespace -c "$container" > ${namespace}__${pod}__${container}.log
            echo -n '.'
        done
    done

    echo
