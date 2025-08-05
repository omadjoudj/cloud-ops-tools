#!/bin/bash

kubectl get pods --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,POD:.metadata.name,IMAGE:.spec.containers[*].image'
