#!/bin/bash
# Contact: ~omadjoudj

IMG="Cirros-6.0"
SSHKEY="omadjoudj-opscare-pubkey"
NETID=""
FLAVOR="m1.extra_tiny_test"


for cmp in `kubectl exec -it -n openstack deploy/keystone-client -it -- openstack compute service list -f csv --quote minimal -c Binary -c Host -c State | grep nova-compute`;
do
    echo openstack server create --flavor $FLAVOR --image $IMG --key-name $SSHKEY --network $NETID --availability-zone nova:<compute-node> opscare-workload-mon-${cmp}
done
