#!/bin/bash
# Contact: ~omadjoudj

DATE=`date -I`
PREFIX="omadjoudj-opscare-upgrade-workload-mon"
IMG="healthcheck-vm"
#SSHKEY="omadjoudj-opscare-pubkey"
FLAVOR="m1.healthcheck"
SEC_GROUP="$PREFIX-allow-icmp-$DATE"
NET="$PREFIX-net-$DATE"
PUBLIC_NET="public-prod"
SUBNET="$PREFIX-subnet-$DATE"
ROUTER="$PREFIX-router-$DATE"


# Create subnet and router

openstack network create $NET
openstack subnet create --network $NET --subnet-range=192.168.0.0/16 --gateway 192.168.0.1 $SUBNET
openstack router create $ROUTER
openstack router set --external-gateway $PUBLIC_NET $ROUTER
openstack router add subnet $ROUTER $SUBNET


# Create sec group and its rule
openstack security group create $SEC_GROUP --description "Allows ICMP traffic for Cloudprober"
openstack security group rule create $SEC_GROUP --protocol icmp --remote-ip 0.0.0.0/0 --ingress
openstack security group rule create $SEC_GROUP --protocol icmp --remote-ip 0.0.0.0/0 --egress
##

for cmp in `openstack compute service list --service nova-compute -f csv --quote minimal -c Binary -c Host -c State | grep ',up' | cut -d, -f2`;
do
    #openstack server create --wait --flavor $FLAVOR --image $IMG --key-name $SSHKEY --network $NETID --availability-zone nova:<compute-node> ${PREFIX}-${cmp}
    #
    vm_id=`openstack server create --flavor $FLAVOR --image $IMG --network $NET --availability-zone nova:$cmp -f value -c id ${PREFIX}-${cmp}-${DATE}`
    fip=`openstack floating ip create $PUBLIC_NET -f value -c floating_ip_address`
    openstack server add floating ip $vm_id $fip
    openstack server add security group $vm_id $SEC_GROUP
    openstack --os-compute-api-version 2.26 server set --tag openstack.lcm.mirantis.com:prober $vm_id
done
