#!/bin/bash
#~omadjoudj
# k8s local node shell similar to the one from Lens

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <node-name>"
  exit 1
fi

NODE_NAME="$1"
POD_NAME="shell-${NODE_NAME}"
YAML_FILE="/tmp/nodeshell-${NODE_NAME}.yaml"

cleanup() {
  echo "Cleaning up pod and YAML file..."
  kubectl delete -f "${YAML_FILE}" --ignore-not-found=true
  rm -f "${YAML_FILE}"
}

trap cleanup EXIT INT TERM

cat << EOF > "${YAML_FILE}"
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: kube-system
spec:
  containers:
  - name: shell
    image: docker.io/alpine:3.13
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /
  hostIPC: true
  hostNetwork: true
  hostPID: true
  nodeName: ${NODE_NAME}
  restartPolicy: Never
EOF

echo "Applying pod manifest to node ${NODE_NAME}..."
kubectl apply -f "${YAML_FILE}"

echo "Waiting for pod ${POD_NAME} to be running..."
kubectl wait --for=condition=Ready pod/${POD_NAME} -n kube-system --timeout=120s

echo "Spawning node root shell... (type 'exit' to quit)"
kubectl -n kube-system exec -it "${POD_NAME}" -- chroot /host /bin/sh

echo "Shell exited."