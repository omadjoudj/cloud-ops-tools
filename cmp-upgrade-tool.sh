#!/bin/bash
# Contact: omadjoudj
# TODO: Integrate it with Migrator tool and create a function around it to drain the node or stop the workload before releasing the lock
# TODO: Refactor to remove repetitions

set -euo pipefail


TOOL_NAME="custom-opscare-openstack-cmp-upgrade-tool"
CMP_INVENTORY="/tmp/cmp_inventory_$(date +%Y%m%d%H%M%S)_$$_$RANDOM.txt"
# Colors
RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'


warn() {
    echo -e "$YELLOW $@ $RESTORE" 1>&2
}

abort() {
    echo -e "$RED $@ $RESTORE" 1>&2
    exit 1
}


function check_env_correctness()
{
    local keystone_ingress_fqdn
    local keystone_fqdn_from_envvar

    if [ -z "$KUBE_CONTEXT" ] && [ "$KUBE_CONTEXT" = '' ]; then
        abort "KUBE_CONTEXT is empty or undefined. To get a list of contexts, use: kubectl config get-contexts"
    fi

    keystone_ingress_fqdn="$(kubectl --context $KUBE_CONTEXT get ingress -n openstack keystone-namespace-fqdn -o jsonpath='{.spec.rules[0].host}')"
    keystone_fqdn_from_envvar="$(echo $OS_AUTH_URL | cut -d/ -f3)"
    if [[ "$keystone_ingress_fqdn" != "$keystone_fqdn_from_envvar" ]]; then
        abort "ERROR: Wrong Cloud detected. OS_AUTH_URL env variable does not match keystone's Ingress FQDN"
    fi
}

function generate_ansible_inventory()
{
    local mosk_ns
    local node_name
    local kaas_name
    
    echo "# Export MCC Kubeconfig first"
    # Get MOSK cluster's namespace
    mosk_ns=$(kubectl  --context $KUBE_CONTEXT  get cluster -A --no-headers | awk '{print $1}' | grep -v '^default')
    echo "[mcc_mgr]"
    kubectl  --context $KUBE_CONTEXT  get lcmmachine -n default -o wide --no-headers | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'
    echo "[mosk_mgr]"
    kubectl  --context $KUBE_CONTEXT  get lcmmachine -n "$mosk_ns" -o wide --no-headers | grep mgr | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'
    # CTL special case: needs to get the IP of k8s-ext
    echo "[ctl]"
    #kubectl  --context $KUBE_CONTEXT  get lcmmachine -n $mosk_ns -o wide --no-headers | grep -E "ctl|sl|gtw" | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'
    kubectl  --context $KUBE_CONTEXT  get lcmmachine -n "$mosk_ns" -o wide --no-headers | grep -E "ctl|sl|gtw" | awk '{print $1,$6}' | while read node_name kaas_name
    do
        echo $node_name "kaas_name="$kaas_name "ansible_host="$(kubectl  --context $KUBE_CONTEXT  get ipamhost -n "$mosk_ns" $node_name -o json 2>/dev/null | jq -r '.status.netconfigCandidate.bridges."k8s-ext".addresses[0]' | sed 's|/[0-9][0-9]||')
    done
    echo "[osd]"
    kubectl  --context $KUBE_CONTEXT  get lcmmachine -n "$mosk_ns" -o wide --no-headers | grep osd | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'
    echo "[cmp]"
    kubectl  --context $KUBE_CONTEXT  get lcmmachine -n "$mosk_ns" -o wide --no-headers | grep cmp | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'
}

function check_cmp_upgrade_readiness()
{
    local cmp
    local non_running_vms
    cmp="$1"
    non_running_vms="$( openstack server list --all -n -f value --limit 100000000000 --host "$cmp" |grep -v -w SHUTOFF )"
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

    #echo "INFO: Refreshing compute node inventory"
    kubectl  --context $KUBE_CONTEXT  get nodes -l openstack-compute-node=enabled -o json | jq -j '.items[] | .metadata.name, " ", .metadata.labels."kaas.mirantis.com/machine-name", "\n"' | sort -k 2 > "$CMP_INVENTORY"
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
  controllerName: $TOOL_NAME" |  kubectl  --context $KUBE_CONTEXT  apply -f -

}

function remove_nodeworkloadlock()
{
    local cmp
    cmp="$1"
    if check_nodeworkloadlock "$cmp" > /dev/null; then
        echo "INFO: Releasing NodeWorkloadLock on the node $cmp"
        kubectl  --context $KUBE_CONTEXT delete nodeworkloadlocks --grace-period=0 "$TOOL_NAME-$cmp"
    else
        echo "ERROR: NodeWorkloadLock on the node $cmp does not exist"
        exit 2
    fi
}


function check_nodeworkloadlock()
{
    local cmp
    cmp="$1"

    if kubectl  --context $KUBE_CONTEXT  get nodeworkloadlocks "$TOOL_NAME-$cmp" > /dev/null; then
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
    cat <<-USAGE
	    Usage:
        `basename $0` <subcommand> <args>
    
    subcommands:

        lock-all-nodes 

        check-locks 
        
        list-vms 

        ansible-inventory
        
        rack-list-vms <RACK> 
        
        rack-release-lock <RACK>  {force_unsafe}
        
        rack-disable <RACK> 
        
        rack-enable <RACK>
        
        rack-live-migrate <RACK> 
        
        node-release-lock <NODE>
	USAGE
}

# Main script starts here

if [ $# -eq 0 ]; then
   usage
   exit 1
fi

case "$1" in
    lock-all-nodes)
        check_env_correctness   
        refresh_cmp_inventory
        echo "INFO: Creating a custom NodeWorkloadLock on all compute nodes"
        lock_all_nodes
        ;;
    check-locks)
        check_env_correctness   
        refresh_cmp_inventory
        echo "INFO: Checking the custom NodeWorkloadLocks on all compute nodes."
        echo -e "$YELLOW CAUTION: DO NOT PROCEED WITH THE UPGRADE IF ONE OF THESE CHECKS FAILS $RESTORE"
        check_locks_all_nodes
        ;;
    
    ansible-inventory)
        generate_ansible_inventory
        ;;

    node-release-lock)
        check_env_correctness   
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
        check_env_correctness   
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
                    rack_release_lock_ops=${3:-safe}
                    if [[ "$rack_release_lock_ops" = "force_unsafe" ]]; then
                        remove_nodeworkloadlock "$i"
                    else
                        node_safe_release_lock "$i"
                    fi
                    # Enable back the nodes so we dont end up with all nodes left disabled
                    # LCM will disable/enable the node again when LCM picks the node for upgrade
                    skip_nova_disable=${4:-yes}
                    if [[ "skip_nova_disable" != "yes" ]]; then
                        openstack compute service set --enable "$i" nova-compute
                    fi
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    rack-list-vms)
        check_env_correctness   
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
                    openstack server list --all -n -c ID -c Name -c Status -f value --limit 100000000000 --host "$i"
                    echo
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;

    rack-disable)
        check_env_correctness   
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
                    openstack compute service set --disable --disable-reason="$TOOL_NAME: Preparing for upgrade" "$i" nova-compute
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    rack-enable)
        check_env_correctness   
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
                    openstack compute service set --enable "$i" nova-compute
                done
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;;
    rack-live-migrate)
        check_env_correctness   
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
                    (openstack server list --all -n -c ID -f value --status ACTIVE --limit 100000000000 --host $i | xargs --no-run-if-empty -L1 -P5 openstack server migrate --live-migration) || true
                done
                echo -e "INFO: Use $YELLOW << cmp-upgrade-tool.sh rack-list-vms $2 >> $RESTORE to monitor the progress"
            else
                echo "ERROR: Rack $2 not found in the inventory"
                exit 1
            fi
        fi
        ;; 
    list-vms)
        check_env_correctness   
        refresh_cmp_inventory
        aggr_inventory=$(mktemp /tmp/aggr.XXXXXXXXXXXXX)
        openstack aggregate list  -f csv --quote minimal --long > "$aggr_inventory"
        echo "Machine/Rack,AZ,Aggregate,VM ID,VM Name,VM Status,Network,Upgraded"
        for i in $( cat "$CMP_INVENTORY" | awk '{print $1}' );
        do
            machine_name="$(grep "$i" "$CMP_INVENTORY" | awk '{print $2}')"
            aggr="$( (grep "$i" "$aggr_inventory" | cut -d, -f2 | tr '\n' ' ' | tr -s ' ') || true)"
            az="$( (grep "$i" "$aggr_inventory" | cut -d, -f3 | tr '\n' ' ' | tr -s ' ') || true)"
            openstack server list --all -n -c ID -c Name -c Status -c Networks -f csv --quote minimal --limit 100000000000 --host "$i" | awk 'NR>1' | while read line; do
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