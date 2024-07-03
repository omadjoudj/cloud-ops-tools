#!/bin/bash
# Contact: omadjoudj
# A script that creates GracefulReboot object for the nodes that has the reboot flag set to true

set -euo pipefail


function usage()
{
    echo "Usage: $0 {cmp|ctl-osd}"
    echo "A script that creates GracefulReboot object for the nodes that has the reboot flag set to true"
    echo "Make sure to export MCC's kubeconfig"
}


if [[ $# -ne 1 ]]; then
    echo "No argument provided" >&2
    usage 
    exit 2
fi

cluster_ns=$(kubectl get cluster -A | grep -vE 'NAMESPACE|default' | awk '{print $1}')
cluster_name=$(kubectl get cluster -A | grep -vE 'NAMESPACE|default' | awk '{print $2}')


# Generate GracefulReboot object 

    echo "apiVersion: kaas.mirantis.com/v1alpha1
kind: GracefulRebootRequest
metadata:
  name: $cluster_name
  namespace: $cluster_ns
spec:
  machines:"


if [[ "$1" == "cmp" ]] ; then 
    echo "  # Rebooting compute nodes"
    kubectl get machine -n $cluster_ns -o json | jq '.items[] | select(.status.providerStatus?.reboot?.required==true) | .metadata.name' | tr -d '"' | grep cmp | while read i ; do echo "  - $i" ; done  
elif [[ "$1" == "ctl-osd" ]] ; then
    echo "  # Rebooting control plane and OSD nodes"
    kubectl get machine -n $cluster_ns -o json | jq '.items[] | select(.status.providerStatus?.reboot?.required==true) | .metadata.name' | tr -d '"' | grep -v cmp | while read i ; do echo "  - $i" ; done  
else
    echo "  # Rebooting all nodes"
fi 