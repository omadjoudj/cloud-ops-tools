#!/bin/bash
#
# A: ~omadjoudj
#

#set -euo pipefail

TIMEOUT=900
ELAPSED=0
SLEEP_INTERVAL=10

ctx=mcc-${CLOUD}

cluster_ns="$(kubectl  --context $ctx get cluster -A --no-headers | grep -v 'default' | awk '{print $1}')"

echo "About to reboot the compute nodes on the rack $1 on $ctx"
read -p "Proceed? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Command cancelled"
    exit 1
else
	echo "Sending power off requests to compute nodes on the rack $1"
	kubectl  get bmhi -n $cluster_ns -o wide  --context $ctx | grep cmp | grep $1 | awk '{print $1}' | xargs -P20 -I% kubectl  --context $ctx -n $cluster_ns  patch bmhi % --type=merge -p "{\"spec\":{\"online\":false}}"

	#sleep 900
	while true; do
		cmp_rack_power_state=$(kubectl --context $ctx -n $cluster_ns get bmhi -o custom-columns="NAME:.metadata.name,TARGET:.spec.online,ACTUAL:.status.poweredOn" | grep "cmp" | grep "$1")
		if echo "$cmp_rack_power_state" | grep -q "true"; then
        	echo "Waiting for nodes to power OFF... (${ELAPSED}s elapsed)"
			sleep $SLEEP_INTERVAL
        	((ELAPSED+=SLEEP_INTERVAL))
		else
        	echo "All nodes are powered OFF."
        	break
    	fi
		if [ $ELAPSED -ge $TIMEOUT ]; then
        	echo "Error: Timed out waiting for power state."
        	exit 1
   		fi
	done
	echo "$cmp_rack_power_state"
	echo "Triggering poweron on rack $1"

	kubectl  get bmhi -n $cluster_ns -o wide  --context $ctx | grep cmp | grep $1 | awk '{print $1}' | xargs -P20 -I% kubectl  --context $ctx -n $cluster_ns  patch bmhi % --type=merge -p "{\"spec\":{\"online\":true}}"
fi
