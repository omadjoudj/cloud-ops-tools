#!/bin/bash
# Performs a safe, rolling restart of a DaemonSet on a targeted set of nodes.
# It waits for each new pod to become ready before moving to the next node.
# ~omadjoudj

set -e
set -o pipefail

NAMESPACE="openstack"
DAEMONSET_NAME="openvswitch-openvswitch-vswitchd-default"
LABEL1="openstack-gateway=enabled"
LABEL2="openstack-control-plane=enabled"
POD_READY_TIMEOUT=3600
POLL_INTERVAL=5

print_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}
print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}
print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}
print_warning() {
    echo -e "\033[33m[DRY RUN]\033[0m $1"
}



DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
fi

if ! command -v jq &> /dev/null; then
    print_error "Error: jq is not installed. Please install it to continue." >&2
    exit 1
fi




if [ "$DRY_RUN" = true ]; then
  print_warning "DRY RUN MODE ENABLED. No changes will be made."
fi

print_info "Finding target nodes with label '$LABEL1' OR '$LABEL2'..."

NODE_LIST=$( (kubectl get nodes -l "$LABEL1" -o jsonpath='{.items[*].metadata.name}'; echo -e "\n" ; kubectl get nodes -l "$LABEL2" -o jsonpath='{.items[*].metadata.name}') | tr ' ' '\n' | sort -u | tr '\n' ' ' )

read -r -a NODES_TO_RESTART <<< "$NODE_LIST"

if [ ${#NODES_TO_RESTART[@]} -eq 0 ]; then
    print_error "No nodes found with the specified labels. Exiting."
    exit 1
fi

print_info "Found ${#NODES_TO_RESTART[@]} target node(s): ${NODES_TO_RESTART[*]}"

for NODE_NAME in "${NODES_TO_RESTART[@]}"; do
    echo "------------------------------------------------------------"
    print_info "Processing Node: $NODE_NAME"

    POD_TO_DELETE=$(kubectl get pods -n "$NAMESPACE" --field-selector "spec.nodeName=$NODE_NAME" -o json | \
                    jq -r --arg ds_name "$DAEMONSET_NAME" '.items[] | select(.metadata.ownerReferences[0].name == $ds_name) | .metadata.name')

    if [ -z "$POD_TO_DELETE" ]; then
        print_error "Could not find a pod for '$DAEMONSET_NAME' on node '$NODE_NAME'. Skipping."
        continue
    fi
    print_info "Found pod '$POD_TO_DELETE' to restart."

    if [ "$DRY_RUN" = true ]; then
        print_warning "kubectl delete pod \"$POD_TO_DELETE\" -n \"$NAMESPACE\""
    else
        if kubectl delete pod "$POD_TO_DELETE" -n "$NAMESPACE"; then
            print_info "Pod '$POD_TO_DELETE' deleted."
        else
            print_error "Failed to delete pod '$POD_TO_DELETE'. Skipping node."
            continue
        fi

        print_info "Waiting for new OVS pod on node '$NODE_NAME' to become ready..."
        START_TIME=$(date +%s)
        while true; do
            CURRENT_TIME=$(date +%s)
            if (( CURRENT_TIME - START_TIME > POD_READY_TIMEOUT )); then
                print_error "Timeout: Pod on node '$NODE_NAME' did not become ready within $POD_READY_TIMEOUT seconds."
                exit 1
            fi

            NEW_POD_NAME=$(kubectl get pods -n "$NAMESPACE" --field-selector "spec.nodeName=$NODE_NAME" -o json | \
                           jq -r --arg ds_name "$DAEMONSET_NAME" --arg old_pod "$POD_TO_DELETE" \
                           '.items[] | select(.metadata.ownerReferences[0].name == $ds_name and .metadata.name != $old_pod) | .metadata.name')

            if [ -n "$NEW_POD_NAME" ]; then
                STATUS=$(kubectl get pod "$NEW_POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
                if [[ "$STATUS" == "True" ]]; then
                    print_success "New pod '$NEW_POD_NAME' is ready."
                    break
                fi
            fi
            sleep "$POLL_INTERVAL"
        done
    fi
done

echo "------------------------------------------------------------"
print_success "Process complete."
