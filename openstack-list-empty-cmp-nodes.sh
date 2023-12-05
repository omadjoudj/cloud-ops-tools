#!/bin/bash

ks_prefix='kubectl exec -it -n openstack deploy/keystone-client -c keystone-client  --'

for cmp_node in `$ks_prefix openstack compute service list --service nova-compute -f csv --quote minimal -c Host | grep -v Host`
do
    vms=`$ks_prefix openstack server list --all -n -c ID -f value --host  $cmp_node | wc -l`
    #echo $vms

    if [[ "$vms" -eq "0" ]]; then
        echo "$cmp_node"
    fi
done
