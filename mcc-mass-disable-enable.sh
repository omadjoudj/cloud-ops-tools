#!/usr/bin/env bash
# Contact: omadjoudj

if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
  echo "Usage: $0 <action> <project-namespace> <node_list_file>"
  echo "Actions: enable | disable | poweroff | poweron"
  exit 1
fi

ACTION=$(echo "$1" | tr '[:upper:]' '[:lower:]')
NAMESPACE=$2
NODE_LIST_FILE=$3

if [[ ! "$ACTION" =~ ^(enable|disable|poweroff|poweron)$ ]]; then
  echo "Error: Invalid action '$ACTION'."
  echo "Supported actions: enable, disable, poweroff, poweron"
  exit 1
fi

if [[ ! -f "$NODE_LIST_FILE" ]]; then
  echo "Error: File '$NODE_LIST_FILE' not found."
  exit 1
fi

echo "Initiating node $ACTION in namespace: $NAMESPACE"
echo "----------------------------------------------------"

while IFS= read -r MACHINE; do
  [[ -z "$MACHINE" || "$MACHINE" == \#* ]] && continue

  echo "Attempting to $ACTION: $MACHINE..."

  case "$ACTION" in
    disable|enable)
      if [[ "$ACTION" == "disable" ]]; then
        DISABLE_FLAG="true"
      else
        DISABLE_FLAG="false"
      fi

      kubectl patch machines.cluster.k8s.io -n "$NAMESPACE" "$MACHINE" \
        --type=merge \
        -p '{"spec":{"providerSpec":{"value":{"disable":'"$DISABLE_FLAG"'}}}}'

      ;;

    poweroff|poweron)
      if [[ "$ACTION" == "poweroff" ]]; then
        ONLINE_FLAG="false"
      else
        ONLINE_FLAG="true"
      fi

      kubectl patch bmhi -n "$NAMESPACE" "bm-$MACHINE" \
        --type=merge \
        -p '{"spec":{"online":'"$ONLINE_FLAG"'}}'
      ;;
  esac

  if [ $? -eq 0 ]; then
    echo " -> Successfully executed '$ACTION' on $MACHINE."
  else
    echo " -> [ERROR] Failed to $ACTION $MACHINE."
  fi

done < "$NODE_LIST_FILE"

echo "----------------------------------------------------"
echo "Process complete."