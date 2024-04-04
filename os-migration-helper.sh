#!/bin/bash
## Manual migration helpers, usueful to prepare the node for MCC/MOSK LCM to upgrade the node
## A: ~omadjoudj

host=$1

usage() {
    echo "Usage: $0 <HOSTNAME>"
    exit 1
}

[[ $# -eq 0 ]] && usage

# Shutoff VMs
#for i in `openstack server list --all --host $host --status shutoff -f value -c ID` ; do openstack server migrate $i ; done
vms_in_shutoff_state=`openstack server list --all --host $host --status shutoff -f value -c ID`

for i in $vms_in_shutoff_state; do
    echo "[INFO] Cold-migrating shutoff VM: $i from $host"
    openstack server migrate $i
done
sleep 10


for i in $vms_in_shutoff_state; do
    if [[ "$(openstack server show $i -f value -c status)" == "VERIFY_RESIZE" ]];
        echo "[INFO] Confirming RESIZE for the VM: $i from $host"
        openstack server migrate confirm $i
    fi
done

while true; do
        total_vms=`openstack server list --all --host $host -f value -c ID | wc -l`
        if [ $total_vms -eq 0 ] ; then
                echo "[OK] Node $host is empty"
                exit 0
        fi

        # Live evacuate
        vm_migrating=`openstack server list --all --host $host --status migrating -f value -c ID | wc -l`
        echo "[INFO] Currently $vm_migrating VM(s) are in MIGRATING state from $host"
        sleep 10
        if [[ $vm_migrating -eq 0 ]] ; then
                echo "[INFO] Launching Live-Evacuation of 5 VMs from $host"
                # Switch to openstack client b/c nova client is deprecated
                nova host-evacuate-live --max-servers 5 $host
        fi
done
