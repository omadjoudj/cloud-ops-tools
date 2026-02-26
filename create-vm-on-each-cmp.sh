#!/bin/bash
# Contact: ~omadjoudj

PREFIX="omadjoudj-opscare-upgrade-workload-mon"
IMG="healthcheck-vm"
FLAVOR="m1.healthcheck"
SEC_GROUP="$PREFIX-allow-icmp"
NET="$PREFIX-net"
PUBLIC_NET="public-prod"
SUBNET="$PREFIX-subnet"
ROUTER="$PREFIX-router"


if ! openstack network show "$NET" >/dev/null 2>&1; then
    echo "Creating network: $NET"
    openstack network create "$NET"
else
    echo "Network $NET already exists."
fi

if ! openstack subnet show "$SUBNET" >/dev/null 2>&1; then
    echo "Creating subnet: $SUBNET"
    openstack subnet create --network "$NET" --subnet-range=192.168.0.0/16 --gateway 192.168.0.1 "$SUBNET"
else
    echo "Subnet $SUBNET already exists."
fi

if ! openstack router show "$ROUTER" >/dev/null 2>&1; then
    echo "Creating router: $ROUTER"
    openstack router create "$ROUTER"
    openstack router set --external-gateway "$PUBLIC_NET" "$ROUTER"
    openstack router add subnet "$ROUTER" "$SUBNET"
else
    echo "Router $ROUTER already exists."
fi


if ! openstack security group show "$SEC_GROUP" >/dev/null 2>&1; then
    echo "Creating security group: $SEC_GROUP"
    openstack security group create "$SEC_GROUP" --description "Allows ICMP traffic for Cloudprober"
    openstack security group rule create "$SEC_GROUP" --protocol icmp --remote-ip 0.0.0.0/0 --ingress
    openstack security group rule create "$SEC_GROUP" --protocol icmp --remote-ip 0.0.0.0/0 --egress
else
    echo "Security group $SEC_GROUP already exists."
fi


for cmp in $(openstack compute service list --service nova-compute -f csv --quote minimal -c Binary -c Host -c State | grep ',up' | cut -d, -f2); do
    VM_NAME="${PREFIX}-${cmp}"

    vm_id=$(openstack server show "$VM_NAME" -f value -c id 2>/dev/null)

    if [ -z "$vm_id" ]; then
        echo "Creating server: $VM_NAME"
        vm_id=$(openstack server create --flavor "$FLAVOR" --image "$IMG" --network "$NET" --availability-zone "nova:$cmp" -f value -c id "$VM_NAME")

        fip=$(openstack floating ip create "$PUBLIC_NET" -f value -c floating_ip_address)
        openstack server add floating ip "$vm_id" "$fip"

        openstack server add security group "$vm_id" "$SEC_GROUP"
        openstack --os-compute-api-version 2.26 server set --tag openstack.lcm.mirantis.com:prober "$vm_id"
    else
        echo "Server $VM_NAME already exists (ID: $vm_id). Skipping creation."
    fi
done