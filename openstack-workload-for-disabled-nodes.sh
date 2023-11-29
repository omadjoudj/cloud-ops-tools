#!/bin/bash

ks_prefix='kubectl exec -it -n openstack deploy/keystone-client -c keystone-client  --'

for cmp_node in `$ks_prefix openstack compute service list -f csv --quote minimal| grep disab | cut -d, -f3`
do
    echo "==> VMs running on $cmp_node"
    $ks_prefix openstack server list --all -n --host $cmp_node --fit-width
done
