#!/bin/bash
#
# A: ~omadjoudj
#

#set -euo pipefail
ctx=mcc-${CLOUD}

cluster_ns="$(kubectl  --context $ctx get cluster -A --no-headers | grep -v 'default' | awk '{print $1}')"

echo "About to reboot the compute nodes on the rack $1 on $ctx"
read -p "Proceed? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Command cancelled"
    exit 1
else
	kubectl  get bmhi -n $cluster_ns -o wide  --context $ctx | grep cmp | grep $1 | awk '{print $1}' | xargs -P20 -I% kubectl  --context $ctx -n $cluster_ns  patch bmhi % --type=merge -p "{\"spec\":{\"online\":false}}"

	sleep 10

	kubectl  get bmhi -n $cluster_ns -o wide  --context $ctx | grep cmp | grep $1 | awk '{print $1}' | xargs -P20 -I% kubectl  --context $ctx -n $cluster_ns  patch bmhi % --type=merge -p "{\"spec\":{\"online\":true}}"
fi
