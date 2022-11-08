#!/bin/bash
## Manual migration helpers, usueful to prepare the node for MCC/MOSK LCM to upgrade the node
## A: ~omadjoudj

host=$1

# Shutoff VMs
echo "[WARN] Cold-migrating shutoff VMs from $host"
for i in `openstack server list --all --host $host --status shutoff -f value -c ID` ; do openstack server migrate $i ; done

while true; do
        total_vms=`openstack server list --all --host $host -f value -c ID | wc -l`
        if [ $total_vms -eq 0 ] ; then
                echo "[OK] Node $host is empty"
                exit 0
        fi

        # Live evacuate
        vm_migrating=`openstack server list --all --host $host --status migrating -f value -c ID | wc -l`
        echo "[INFO] Currently migrating $vm_migrating VM(s) from $host"
        sleep 10
        if [ $vm_migrating -eq 0 ] ; then
                echo "[INFO] Live-Evacuating 20 VMs from $host"
                nova host-evacuate-live --max-servers 20 $host
        fi
done
