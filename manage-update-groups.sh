#!/bin/bash
# Customization owner: omadjoudj

set -euo pipefail


function usage()
{
  echo "USAGE: $(basename "$0") {create-update-groups | set-nodes-update-group}"
}

function gen_updategroup_obj()
{
    local _cluster_name
    local _cluster_ns
    local _suffix
    local _index
    local _parallelizm
    _cluster_ns="$1"
    _cluster_name="$2"
    _suffix="$3"
    _index="$4"
    _parallelizm="$5"

    echo "apiVersion: kaas.mirantis.com/v1alpha1
kind: UpdateGroup
metadata:
  labels:
    cluster.sigs.k8s.io/cluster-name: $_cluster_name
  name: ${_cluster_name}-${_suffix}
  namespace: $_cluster_ns
spec:
  index: $_index
  concurrentUpdates: $_parallelizm"

}


function cluster_gen_all_updateGroup_objs()
{
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "control-plane" 1 1
    echo '---'
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "osd" 2 2
    #echo '---'
    #gen_updategroup_obj "$cluster_name" "$cluster_ns" "cmp" 3 19
    echo '---'
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "default" 4 1

}

function create_compute_updateGroup_per_rack() 
{
  i=5
  for cmp_rack in $(kubectl get machine -n "$cluster_ns"  --no-headers -o name  | cut -d/ -f2 | grep "cmp" | grep -Eo 'z[0-9][0-9]r[0-9][0-9]b[0-9][0-9]' | sort -u); do
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "cmp-rack-${cmp_rack}" "$i" 19
    i=$(($i+1))
  done
}


#for machine in $(kubectl get machine -n "$cluster_ns"  --no-headers -o name | grep "cmp" | grep "$cmp_rack")


# Main script starts here


if [ $# -eq 0 ]; then
   usage
   exit 1
fi

cluster_ns=$(kubectl get cluster -A --no-headers | grep -v 'default' | awk '{print $1}')
cluster_name=$(kubectl get cluster -A --no-headers | grep -v 'default' | awk '{print $2}')

case "$1" in
    create-update-group|create-update-groups)
      cluster_gen_all_updateGroup_objs
      create_compute_updateGroup_per_rack  
      ;;
    set-node-update-group|set-node-update-groups|set-nodes-update-group|set-nodes-update-groups)
  #echo "kubectl label -n $cluster_ns $machine --overwrite kaas.mirantis.com/update-group=<UpdateGroupObjectName>"
      ;;
    *)
      echo "Invalid subcommand"
      usage
      exit 1
      ;;
esac