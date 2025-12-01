#!/bin/bash
# ~omadjoudj
# OVS pinning tool, usable with MOSK 25.2+

if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [check|generate] [apply]"
    echo ""
    echo "Options:"
    echo "  check     : Compares existing ConfigMap against live DaemonSet images."
    echo "  generate  : Generate the ConfigMap YAML file locally."
    echo "  apply     : (Optional) Used with 'generate' to apply the file to the cluster."
    exit 0
fi

MODE=${1:-"check"}   # Default to 'check' if no arg provided
APPLY_FLAG=${2:-""}  # Optional second argument

NAMESPACE="openstack"
DS_NAME="openvswitch-openvswitch-vswitchd-default"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

OS_DEPLOYMENT_NAME=$(kubectl get -n "$NAMESPACE" osdpl -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$OS_DEPLOYMENT_NAME" ]; then
    echo -e "${RED}Error: Could not find an OpenStackDeployment (osdpl) in namespace '$NAMESPACE'.${NC}"
    exit 1
fi

OPENSTACK_RELEASE=$(kubectl get -n "$NAMESPACE" osdpl -o jsonpath='{.items[0].spec.openstack_version}' 2>/dev/null)
if [ -z "$OPENSTACK_RELEASE" ]; then
    echo -e "${RED}Error: Could not determine 'openstack_version' from the OpenStackDeployment.${NC}"
    exit 1
fi

CM_NAME="${OS_DEPLOYMENT_NAME}-artifacts"
OUTPUT_FILE="/tmp/${CM_NAME}.yaml"

get_images() {
    DS_EXISTS=$(kubectl get ds "$DS_NAME" -n "$NAMESPACE" --ignore-not-found)
    if [ -z "$DS_EXISTS" ]; then
        echo -e "${RED}Error: DaemonSet '$DS_NAME' not found in namespace '$NAMESPACE'.${NC}"
        exit 1
    fi

    OPENVSWITCH_IMAGE_URL=$(kubectl get ds "$DS_NAME" -n "$NAMESPACE" -o jsonpath="{..image}" | tr ' ' '\n' | grep -m1 "openvswitch")

    KUBERNETES_ENTRYPOINT_IMAGE_URL=$(kubectl get ds "$DS_NAME" -n "$NAMESPACE" -o jsonpath="{..image}" | tr ' ' '\n' | grep -m1 "kubernetes-entrypoint")

    if [ -z "$OPENVSWITCH_IMAGE_URL" ] || [ -z "$KUBERNETES_ENTRYPOINT_IMAGE_URL" ]; then
        echo -e "${RED}Error: Failed to resolve images from DaemonSet.${NC}"
        exit 1
    fi
}

if [ "$MODE" == "check" ]; then
    EXISTING_UPD_STRATEGY=$(kubectl get ds "$DS_NAME" -n "$NAMESPACE" --ignore-not-found -o jsonpath='{.spec.updateStrategy.type}')
    if [ "$EXISTING_UPD_STRATEGY" == "OnDelete" ]; then
         echo -e "${GREEN}PASS ${NC} OVS updateStrategy is OnDelete"
    else
         echo -e "${RED}ERROR${NC} OVS updateStrategy is not OnDelete"
         exit 1
    fi

    echo "----  CHECKING CONFIGMAP STATUS "
    get_images

    CM_DATA=$(kubectl get cm "$CM_NAME" -n "$NAMESPACE" -o jsonpath="{.data.${OPENSTACK_RELEASE}}" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "ConfigMap: ${RED}MISSING${NC} ($CM_NAME)"
        echo "Action: Run '$0 generate apply' to create it."
        exit 1
    elif [ -z "$CM_DATA" ]; then
         echo -e "ConfigMap: ${YELLOW}EXISTS BUT KEY '${OPENSTACK_RELEASE}' IS MISSING${NC}"
         echo "Action: Run '$0 generate apply' to update it."
         exit 1
    fi

    EXISTING_ENTRYPOINT=$(echo "$CM_DATA" | grep "dep_check:" | awk '{print $2}' | tr -d '[:space:]')
    EXISTING_OVS=$(echo "$CM_DATA" | grep "openvswitch_vswitchd:" | awk '{print $2}' | tr -d '[:space:]')

    MISMATCH=0



    if [ "$EXISTING_ENTRYPOINT" == "$KUBERNETES_ENTRYPOINT_IMAGE_URL" ]; then
         echo -e "${GREEN}PASS ${NC} Kubernetes Entrypoint image matches"
    else
         echo -e "${RED}ERROR${NC} Kubernetes Entrypoint image MISMATCH"
         echo "  Current CM: $EXISTING_ENTRYPOINT"
         echo "  DaemonSet:  $KUBERNETES_ENTRYPOINT_IMAGE_URL"
         MISMATCH=1
    fi

    if [ "$EXISTING_OVS" == "$OPENVSWITCH_IMAGE_URL" ]; then
         echo -e "${GREEN}PASS ${NC} OpenvSwitch image matches"
    else
         echo -e "${RED}ERROR${NC} Openvswitch image MISMATCH"
         echo "  Current CM: $EXISTING_OVS"
         echo "  DaemonSet:  $OPENVSWITCH_IMAGE_URL"
         MISMATCH=1
    fi
    echo "---------------------------------------------------------"

    if [ $MISMATCH -eq 1 ]; then
        echo -e "Configmap is ${RED}OUT OF SYNC${NC}"
        echo "Action: Run '$0 generate apply' to update."
        exit 1
    else
        echo -e "Configmap is ${GREEN}IN SYNC${NC}"
        exit 0
    fi
fi

get_images

echo "Generating ConfigMap: $OUTPUT_FILE ..."

cat <<EOF > "$OUTPUT_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    openstack.lcm.mirantis.com/watch: "true"
  name: ${CM_NAME}
  namespace: openstack
data:
  ${OPENSTACK_RELEASE}: |
    dep_check: $KUBERNETES_ENTRYPOINT_IMAGE_URL
    openvswitch_db_server: $OPENVSWITCH_IMAGE_URL
    openvswitch_vswitchd: $OPENVSWITCH_IMAGE_URL
EOF

echo "File generated successfully."

if [ "$APPLY_FLAG" == "apply" ]; then
    echo "--- Applying to Kubernetes ---"
    kubectl apply -f "$OUTPUT_FILE"
else
    echo "Skipping apply. Use 'apply' as the second argument to execute."
fi