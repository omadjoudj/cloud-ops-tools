#!/bin/bash
# Contact: omadjoudj


echo "Env,Cluster Name,MCC release,MOSK release,Number of nodes that require reboot"
for mcc in $(kubectl config get-contexts -o name  | grep mcc); do 
    cluster_ns=$(kubectl --context $mcc get cluster -A | grep -vE 'NAMESPACE|default' | awk '{print $1}')
    cluster_name=$(kubectl --context $mcc get cluster -A | grep -vE 'NAMESPACE|default' | awk '{print $2}')
    need_reboot_count=$(kubectl --context $mcc get -o json -A machine | jq '.items[] | select(.status.providerStatus?.reboot?.required==true) | .metadata.name' | wc -l | tr -d ' ')
    mosk_version=$(kubectl --context $mcc get -n $cluster_ns cluster $cluster_name --no-headers -o wide | awk '{print $3}' | cut -d+ -f2)
    #mcc_version=$(kubectl --context $mcc get cluster kaas-mgmt --no-headers -o wide | awk '{print $3}' | cut -d+ -f2)
    mcc_version=$(kubectl --context $mcc get cluster kaas-mgmt -o json | jq '.spec.providerSpec.value.kaas.release' | sed 's/kaas-//' | tr '-' '.')
    echo "$(echo $mcc | sed 's/^mcc-//'),$cluster_name,$mcc_version,\"$mosk_version\",$need_reboot_count"
done