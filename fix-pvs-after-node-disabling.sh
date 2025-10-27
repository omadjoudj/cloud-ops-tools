#!/bin/bash

NODE_NAME="$1"

ANNOTATION_VALUE="$NODE_NAME-$2"

echo "# Finding all PVs with nodeAffinity for: $NODE_NAME"

PV_LIST=$(kubectl get pv -o jsonpath="{.items[?(@.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]==\"$NODE_NAME\")].metadata.name}")

if [ -z "$PV_LIST" ]; then
  echo "No PVs found for node $NODE_NAME."
  exit 0
fi

echo "# Found the following PVs: $PV_LIST"
echo "###"

for pv in $PV_LIST; do
  echo "# Patching $pv..."
  echo kubectl patch pv "$pv" -p '{"metadata": {"annotations": {"pv.kubernetes.io/provisioned-by": "'"$ANNOTATION_VALUE"'"}}}'
done

echo "###"
echo "# All patching complete."