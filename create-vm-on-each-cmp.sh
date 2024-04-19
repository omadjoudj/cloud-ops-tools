#!/bin/bash
# Contact: ~omadjoudj

PREFIX="omadjoudj-opscare-upgrade-canary-workload-mon"
IMG="healthcheck-vm"
SSHKEY="omadjoudj-opscare-pubkey"
NETID="healthcheck-net"
PUBLIC_NET="public-prod"
FLAVOR="m1.healthcheck"
SEC_GROUP="omadjoudj_opscare_allow_icmp"

# Create sec group and its rule
openstack security group create $SEC_GROUP --description "Allows ICMP traffic for Cloudprober"
openstack security group rule create $SEC_GROUP --protocol icmp --remote-ip 0.0.0.0/0 --ingress
openstack security group rule create $SEC_GROUP --protocol icmp --remote-ip 0.0.0.0/0 --egress
##

for cmp in `openstack compute service list -f csv --quote minimal -c Binary -c Host -c State | grep nova-compute | cut -d, -f2`;
do
    #openstack server create --wait --flavor $FLAVOR --image $IMG --key-name $SSHKEY --network $NETID --availability-zone nova:<compute-node> ${PREFIX}-${cmp}
    #
    vm_id=`openstack server create --flavor $FLAVOR --image $IMG --network $NETID --availability-zone nova:$cmp -f value -c id ${PREFIX}-${cmp}`
    fip=`openstack floating ip create $PUBLIC_NET -f value -c floating_ip_address`
    openstack server add floating ip $vm_id $fip
    openstack server add security group $vm_id $SEC_GROUP
    openstack --os-compute-api-version 2.26 server set --tag openstack.lcm.mirantis.com:prober $vm_id
done
