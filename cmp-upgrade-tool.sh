#!/bin/bash
# Contact: omadjoudj
# TODO: Integrate it with Migrator tool and create a function around it to drain the node or stop the workload before releasing the lock


KEYSTONE_POD_PREFIX="kubectl exec -it -n openstack deploy/keystone-client -c keystone-client -it --"
TOOL_NAME="custom-opscare-openstack-cmp-upgrade-tool"
CMP_INVENTORY="/tmp/cmp_inventory_$(date +%Y%m%d%H%M%S)_$$_$RANDOM.txt"


function check_cmp_upgrade_readiness()
{
    local cmp=$1
    
    local vm_in_shutoff_state="$( $KEYSTONE_POD_PREFIX openstack server list --all -n -f value --limit -1 --status SHUTOFF --host $cmp | grep -c 'SHUTOFF')"
    local all_vms="$( $KEYSTONE_POD_PREFIX openstack server list --all -n -f value --limit -1 --host $cmp | grep -c '')"

    # kubectl puts an extra line 
    if [[ "$vm_in_shutoff_state" == "$all_vms" ]] ; then
        return 0
    else
        return 1
    fi

}

function refresh_cmp_inventory()
{
    
    #$KEYSTONE_POD_PREFIX openstack compute service list --service nova-compute -f value -c Host > $CMP_INVENTORY
    echo "Refreshing compute node inventory"
    kubectl get nodes -o json 2>/dev/null | jq -j '.items[] | .metadata.name, " ", .metadata.labels."kaas.mirantis.com/machine-name", "\n"' | sort -k 2 | grep 'cmp' > $CMP_INVENTORY
}

function create_nodeworkloadlock()
{
    local cmp=$1
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
    local cmp=$1
    echo "Releasing NodeWorkloadLock on the node $cmp"
    kubectl delete nodeworkloadlocks --grace-period=0 $TOOL_NAME-$cmp
}

function lock_all_nodes()
{
    for i in `cat $CMP_INVENTORY | awk '{print $1}'`; 
    do
        create_nodeworkloadlock $i
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

refresh_cmp_inventory

case "$1" in
    lock-all-nodes)
        echo "Creating a custom NodeWorkloadLock on all compute nodes"
        lock_all_nodes
        ;;
    rack-release-lock)
        if [ -z "$2" ]; then
            echo "ERROR: No Rack specified."
            usage
            exit 1
        else
            if grep -q "$2" $CMP_INVENTORY ; then
                echo "Starting to Release NodeWorkloadLock on the nodes of the rack $2"
                for i in `grep "$2" $CMP_INVENTORY | awk '{print $1}'`; 
                do
                    remove_nodeworkloadlock $i 
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
            fi
        fi
        ;;
    node-release-lock)
        if [ -z "$2" ]; then
            echo "ERROR: No Node specified."
            usage
            exit 1
        else
            check_cmp_upgrade_readiness $2
            result=$?
            if [ $result -eq 0 ]; then
                remove_nodeworkloadlock $2
            else 
                echo "ERROR: Node $2 failed the readiness checks. The node must be Empty or have its workload in SHUTOFF state"
                exit 2  
            fi
        fi
        ;;
    *)
        echo "Invalid subcommand"
        usage
        exit 1
        ;;
esac


