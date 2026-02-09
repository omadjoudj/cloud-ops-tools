#!/bin/bash
NODE="$1"
COMMENT="$2"
AM_PREFIX="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- "

if [ "$#" -lt 2 ]; then
    echo "Not enough arguments"
    exit 1
fi

echo "Silencing alerts on node $NODE"
for matcher in node node_name openstack_hypervisor_hostname; do

    $AM_PREFIX amtool --alertmanager.url http://127.0.0.1:9093 silence add -a "$USER" -d 4h -c "$COMMENT" "$matcher=$NODE"
done