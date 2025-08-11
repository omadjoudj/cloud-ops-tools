#!/bin/bash
# ~omadjoudj

if [ -z "$1" ]; then
  echo "Usage: $0 <pg-id>"
  exit 1
fi

PG_ID=$1
POOL_ID=$(echo $PG_ID | cut -d'.' -f1)
POOL_NAME=$(ceph osd lspools | awk -v pool_id="$POOL_ID" '$1 == pool_id {print $2}')

if [ -z "$POOL_NAME" ]; then
  echo "Error: Could not find pool with ID $POOL_ID"
  exit 1
fi

echo "PG $PG_ID belongs to pool: $POOL_NAME (ID: $POOL_ID)"
echo "---"
echo "Checking RBD images in pool '$POOL_NAME'..."

FIRST_OBJECT=$(rados -p "$POOL_NAME" ls --pgid "$PG_ID" | head -n 1)

if [ -z "$FIRST_OBJECT" ]; then
  echo "No objects found in PG $PG_ID."
  exit 0
fi

OBJECT_PREFIX=$(echo $FIRST_OBJECT | cut -d'.' -f1,2)


for image in $(rbd -p "$POOL_NAME" ls); do
  IMAGE_PREFIX=$(rbd -p "$POOL_NAME" info "$image" | grep 'block_name_prefix:' | awk '{print $2}')
  if [[ "$OBJECT_PREFIX" == "$IMAGE_PREFIX"* ]]; then
    echo "****************************************"
    echo "!!! Affected Volume Found !!!"
    echo "Pool:  $POOL_NAME"
    echo "Image: $image"
    echo "PG:    $PG_ID"
    echo "****************************************"
  fi
done