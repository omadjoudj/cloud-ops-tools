#!/bin/bash
# Contact: omadjoudj
# TODO: Integrate it with Migrator tool and create a function around it to drain the node or stop the workload before releasing the lock
# TODO: Refactor to remove repetitions

set -euo pipefail


KEYSTONE_POD_PREFIX="kubectl exec -it -n openstack deploy/keystone-client -c keystone-client -it --"
TOOL_NAME="custom-opscare-openstack-cmp-upgrade-tool"
CMP_INVENTORY="/tmp/cmp_inventory_$(date +%Y%m%d%H%M%S)_$$_$RANDOM.txt"
# Colors
RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'

function check_cmp_upgrade_readiness()
{
    local cmp
    local non_running_vms
    cmp="$1"
    non_running_vms="$( $KEYSTONE_POD_PREFIX openstack server list --all -n -f value --limit 100000000000 --host "$cmp" |grep -v -w SHUTOFF )"
    if [[ -n "$non_running_vms" ]]; then
        echo "ERROR: $cmp still has running VMs."
        echo "$non_running_vms" | awk '{print $1,$2}'
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
    #echo "INFO: Refreshing compute node inventory"
    kubectl get nodes -l openstack-compute-node=enabled -o json | jq -j '.items[] | .metadata.name, " ", .metadata.labels."kaas.mirantis.com/machine-name", "\n"' | sort -k 2 > "$CMP_INVENTORY"
}

function create_nodeworkloadlock()
{
    local cmp
    cmp="$1"
    echo "INFO: Creating NodeWorkloadLock:"
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
    if check_nodeworkloadlock "$cmp" > /dev/null; then
        echo "INFO: Releasing NodeWorkloadLock on the node $cmp"
        kubectl delete nodeworkloadlocks --grace-period=0 "$TOOL_NAME-$cmp"
    else
        echo "ERROR: NodeWorkloadLock on the node $cmp does not exist"
        exit 2
    fi
}


function check_nodeworkloadlock()
{
    local cmp
    cmp="$1"

    if kubectl get nodeworkloadlocks "$TOOL_NAME-$cmp" > /dev/null; then
        echo -e "Check that the node $cmp has a nodeworkloadlock object \t $GREEN [OK] $RESTORE"
        return 0
    else
        echo -e "Check that the node $cmp has a nodeworkloadlock object \t $RED [FAIL] $RESTORE"
        return 1
    fi

}

function lock_all_nodes()
{
    for i in $( cat "$CMP_INVENTORY" | awk '{print $1}' );
    do
        create_nodeworkloadlock "$i"
    done

}

function check_locks_all_nodes()
{
    for i in $( cat "$CMP_INVENTORY" | awk '{print $1}' );
    do
        check_nodeworkloadlock "$i"
    done

}

function usage()
{
    echo "Usage: $0 {lock-all-nodes | check-locks | list-vms | rack-list-vms <RACK> | rack-release-lock <RACK> | rack-disable <RACK> | rack-enable <RACK>| rack-live-migrate <RACK> | node-release-lock <NODE>}"
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
    check-locks)
        refresh_cmp_inventory
        echo "INFO: Checking the custom NodeWorkloadLocks on all compute nodes."
        echo -e "$YELLOW CAUTION: DO NOT PROCEED WITH THE UPGRADE IF ONE OF THESE CHECKS FAILS $RESTORE"
        check_locks_all_nodes
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
                    # Enable back the nodes so we dont end up with all nodes left disabled
                    # LCM will disable/enable the node again when LCM picks the node for upgrade
                    $KEYSTONE_POD_PREFIX openstack compute service set --enable "$i" nova-compute
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    rack-list-vms)
        if [ -z "$2" ]; then
            echo "ERROR: No Rack specified."
            usage
            exit 1
        else
            refresh_cmp_inventory
            if grep -q "$2" "$CMP_INVENTORY" ; then
                for i in $( grep "$2" "$CMP_INVENTORY" | awk '{print $1}' );
                do
                    echo "[compute:$i]"
                    $KEYSTONE_POD_PREFIX openstack server list --all -n -c ID -c Name -c Status -f value --limit 100000000000 --host "$i"
                    echo
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;

    rack-disable)
         if [ -z "$2" ]; then
            echo "ERROR: No Rack specified."
            usage
            exit 1
        else
            refresh_cmp_inventory
            if grep -q "$2" "$CMP_INVENTORY" ; then
                for i in $( grep "$2" "$CMP_INVENTORY" | awk '{print $1}' );
                do
                    echo "INFO: Disabling the rack $2 / node $i from the scheduler"
                    $KEYSTONE_POD_PREFIX openstack compute service set --disable --disable-reason="$TOOL_NAME: Preparing for upgrade" "$i" nova-compute
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    rack-enable)
        if [ -z "$2" ]; then
            echo "ERROR: No Rack specified."
            usage
            exit 1
        else
            refresh_cmp_inventory
            if grep -q "$2" "$CMP_INVENTORY" ; then
                for i in $( grep "$2" "$CMP_INVENTORY" | awk '{print $1}' );
                do
                    echo "INFO: Enabling the rack $2 / node $i from the scheduler"
                    $KEYSTONE_POD_PREFIX openstack compute service set --enable "$i" nova-compute
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    rack-live-migrate)
        if [ -z "$2" ]; then
            echo "ERROR: No Rack specified."
            usage
            exit 1
        else
            refresh_cmp_inventory
            if grep -q "$2" "$CMP_INVENTORY" ; then
                for i in $( grep "$2" "$CMP_INVENTORY" | awk '{print $1}' );
                do
                    echo "INFO: Live-migrating VMs from Rack $2 / Node ${i}"
                    ## "|| true" in case the node is empty or a migration fails, so it continues to the next compute
                    $KEYSTONE_POD_PREFIX bash -c "(openstack server list --all -n -c ID -f value --status ACTIVE --limit 100000000000 --host "$i" | xargs --no-run-if-empty -L1 -P5 openstack server migrate --live-migration) || true"
                done
                echo -e "INFO: Use $YELLOW << cmp-upgrade-tool.sh rack-list-vms $2 >> $RESTORE to monitor the progress"
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;; 
    list-vms)
            refresh_cmp_inventory
            aggr_inventory=$(mktemp /tmp/aggr.XXXXXXXXXXXXX)
            $KEYSTONE_POD_PREFIX openstack aggregate list  -f csv --quote minimal --long > "$aggr_inventory"
            echo "Machine/Rack,AZ,Aggregate,VM ID,VM Name,VM Status,Network,Upgraded"
            for i in $( cat "$CMP_INVENTORY" | awk '{print $1}' );
            do
                machine_name="$(grep "$i" "$CMP_INVENTORY" | awk '{print $2}')"
                aggr="$((grep "$i" "$aggr_inventory" | cut -d, -f2 | tr '\n' ' ' | tr -s ' ') || true)"
                az="$((grep "$i" "$aggr_inventory" | cut -d, -f3 | tr '\n' ' ' | tr -s ' ') || true)"
                $KEYSTONE_POD_PREFIX openstack server list --all -n -c ID -c Name -c Status -c Networks -f csv --quote minimal --limit 100000000000 --host "$i" | awk 'NR>1' | while read line; do
                    echo "$machine_name,${az% },${aggr% },$line"

                done
            done
        ;;
    *)
        echo "Invalid subcommand"
        usage
        exit 1
        ;;
esac