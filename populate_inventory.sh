#!/bin/sh
# Contact: omadjoudj
# Generate Ansible inventory from just lcmmachine object when possible, not very precise but fast
# Prerequisites: ansible, kubectl

echo "# Export MCC Kubeconfig first"

# Get MOSK cluster's namespace
NS=$(kubectl get cluster -A --no-headers | awk '{print $1}' | grep -v '^default')


echo "[mcc_mgr]"
kubectl get lcmmachine -n default -o wide --no-headers | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'

echo "[mosk_mgr]"
kubectl get lcmmachine -n $NS -o wide --no-headers | grep mgr | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'

# CTL special case: needs to get the IP of k8s-ext
echo "[ctl]"
#kubectl get lcmmachine -n $NS -o wide --no-headers | grep -E "ctl|sl|gtw" | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'

kubectl get lcmmachine -n $NS -o wide --no-headers | grep -E "ctl|sl|gtw" | awk '{print $1,$6}' | while read node_name kaas_name
do
    echo $node_name "kaas_name="$kaas_name "ansible_host="$(kubectl get ipamhost -n $NS $node_name -o json 2>/dev/null | jq -r '.status.netconfigCandidate.bridges."k8s-ext".addresses[0]' | sed 's|/[0-9][0-9]||')

done

echo "[osd]"
kubectl get lcmmachine -n $NS -o wide --no-headers | grep osd | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'

echo "[cmp]"
kubectl get lcmmachine -n $NS -o wide --no-headers | grep cmp | awk '{print $1,"kaas_name=",$6,"ansible_host=",$5}' | sed 's/= /=/g'
