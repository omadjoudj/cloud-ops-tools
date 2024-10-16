#!/bin/bash
# A script to manage updategroups
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
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "ctl" 1 1
    echo '---'
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "osd" 2 2
    #echo '---'
    #gen_updategroup_obj "$cluster_name" "$cluster_ns" "cmp" 3 19
    echo '---'
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "default" 4 1

}

function get_machine_rack()
{
  local _machine
  _machine=$1
  kubectl get machine -n "$cluster_ns"  --no-headers -o name  "$_machine" | cut -d/ -f2 | grep -Eo 'z[0-9][0-9]r[0-9][0-9]b[0-9][0-9]'
}

function create_compute_updateGroup_per_rack()
{
  # start from 5 b/c we have ctl, osd and default before
  # We leave 1 group free in case we need to squeeze something there
  i=5
  for cmp_rack in $(kubectl get machine -n "$cluster_ns"  --no-headers -o name  | cut -d/ -f2 | grep "cmp" | grep -Eo 'z[0-9][0-9]r[0-9][0-9]b[0-9][0-9]' | sort -u); do
    echo "---"
    gen_updategroup_obj "$cluster_name" "$cluster_ns" "cmp-rack-${cmp_rack}" "$i" 19
    i=$(($i+1))
  done
}


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
      #ctl
      for machine in $(kubectl get machine -n "$cluster_ns"  --no-headers -o name | cut -d/ -f2 | grep -Ev "osd|cmp" ) ; do
        echo "kubectl label machine -n $cluster_ns $machine --overwrite kaas.mirantis.com/update-group=${cluster_ns}-ctl"
      done
      #osd
      for machine in $(kubectl get machine -n "$cluster_ns"  --no-headers -o name | cut -d/ -f2 | grep "osd" ) ; do
        echo "kubectl label machine -n $cluster_ns $machine --overwrite kaas.mirantis.com/update-group=${cluster_ns}-osd"
      done
      #cmp
      for machine in $(kubectl get machine -n "$cluster_ns"  --no-headers -o name | cut -d/ -f2 | grep "cmp" ) ; do
        rack=$(get_machine_rack "$machine")
        echo "kubectl label machine -n $cluster_ns $machine --overwrite kaas.mirantis.com/update-group=${cluster_ns}-cmp-rack-${rack}"
      done
      ;;
    *)
      echo "Invalid subcommand"
      usage
      exit 1
      ;;
esac
