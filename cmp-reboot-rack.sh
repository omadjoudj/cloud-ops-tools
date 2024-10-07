#!/bin/bash
#
# A: ~omadjoudj
#

set -euo pipefail

cluster_ns="$(kubectl  --context $KUBE_CONTEXT get cluster -A --no-headers | grep -v 'default' | awk '{print $1}')"

echo "About to reboot the compute nodes on the rack $1 on $KUBE_CONTEXT"
read -p "Proceed? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Command cancelled"
    exit 1
else
	kubectl  get bmh -n $cluster_ns -o wide  --context $KUBE_CONTEXT | grep cmp | grep $1 | awk '{print $1}' | xargs -P20 -I% kubectl  --context $KUBE_CONTEXT -n $cluster_ns  patch bmh % --type=merge -p "{\"spec\":{\"online\":false}}"

	sleep 10

	kubectl  get bmh -n $cluster_ns -o wide  --context $KUBE_CONTEXT | grep cmp | grep $1 | awk '{print $1}' | xargs -P20 -I% kubectl  --context $KUBE_CONTEXT -n $cluster_ns  patch bmh % --type=merge -p "{\"spec\":{\"online\":true}}"
fi
