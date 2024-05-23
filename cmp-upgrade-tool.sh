#!/bin/bash
# Contact: omadjoudj
# TODO: Integrate it with Migrator tool and create a function around it to drain the node or stop the workload before releasing the lock

set -euo pipefail


KEYSTONE_POD_PREFIX="kubectl exec -it -n openstack deploy/keystone-client -c keystone-client -it --"
TOOL_NAME="custom-opscare-openstack-cmp-upgrade-tool"
CMP_INVENTORY="/tmp/cmp_inventory_$(date +%Y%m%d%H%M%S)_$$_$RANDOM.txt"


function check_cmp_upgrade_readiness()
{
    local cmp
    local non_running_vms
    cmp="$1"
    non_running_vms="$( $KEYSTONE_POD_PREFIX openstack server list --all -n -f value --limit 100000000000 --host "$cmp" |grep -v -w SHUTOFF )"
    if [[ -n "$non_running_vms" ]]; then
        echo "ERROR: $cmp still has running VMs."
        echo "$non_running_vms" | awk '{print $1}'
        return 1
    fi
    return 0
}

function node_safe_release_lock()
{
    local cmp
    cmp="$1"
    if check_cmp_upgrade_readiness "$cmp"; then
        remove_nodeworkloadlock "$cmp"
    else
        echo "ERROR: Node $cmp failed the readiness checks. The node must be Empty or have its workload in SHUTOFF state"
        exit 2
    fi
}

function refresh_cmp_inventory()
{

    #$KEYSTONE_POD_PREFIX openstack compute service list --service nova-compute -f value -c Host > $CMP_INVENTORY
    echo "INFO: Refreshing compute node inventory"
    kubectl get nodes -l openstack-compute-node=enabled -o json | jq -j '.items[] | .metadata.name, " ", .metadata.labels."kaas.mirantis.com/machine-name", "\n"' | sort -k 2 > "$CMP_INVENTORY"
}

function create_nodeworkloadlock()
{
    local cmp
    cmp="$1"
    echo "Creating NodeWorkloadLock:"
    echo "apiVersion: lcm.mirantis.com/v1alpha1
kind: NodeWorkloadLock
metadata:
  name: $TOOL_NAME-$cmp
spec:
  nodeName: $cmp
  controllerName: $TOOL_NAME" |  kubectl apply -f -

}

function remove_nodeworkloadlock()
{
    local cmp
    cmp="$1"
    if kubectl get nodeworkloadlocks "$TOOL_NAME-$cmp" > /dev/null; then
        echo "Releasing NodeWorkloadLock on the node $cmp"
        kubectl delete nodeworkloadlocks --grace-period=0 "$TOOL_NAME-$cmp"
    else
        echo "ERROR: NodeWorkloadLock on the node $cmp does not exist"
        exit 2
    fi
}

function lock_all_nodes()
{
    for i in $( cat "$CMP_INVENTORY" | awk '{print $1}' );
    do
        create_nodeworkloadlock "$i"
    done

}

function usage()
{
    echo "Usage: $0 {lock-all-nodes | rack-release-lock <RACK> | node-release-lock <NODE>}"
}

# Main script starts here

if [ $# -eq 0 ]; then
   usage
   exit 1
fi

case "$1" in
    lock-all-nodes)
        refresh_cmp_inventory
        echo "INFO: Creating a custom NodeWorkloadLock on all compute nodes"
        lock_all_nodes
        ;;

    node-release-lock)
        if [ -z "$2" ]; then
            echo "ERROR: No Node specified."
            usage
            exit 1
        else
            refresh_cmp_inventory
            node_safe_release_lock "$2"
        fi
        ;;
    rack-release-lock)
        if [ -z "$2" ]; then
            echo "ERROR: No Rack specified."
            usage
            exit 1
        else
            refresh_cmp_inventory
            if grep -q "$2" "$CMP_INVENTORY" ; then
                echo "INFO: Starting to Release NodeWorkloadLock on the nodes of the rack $2:"
                grep "$2" "$CMP_INVENTORY"
                for i in $( grep "$2" "$CMP_INVENTORY" | awk '{print $1}' );
                do
                    node_safe_release_lock "$i"
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    *)
        echo "Invalid subcommand"
        usage
        exit 1
        ;;
esac


