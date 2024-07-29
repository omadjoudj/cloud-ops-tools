#/bin/bash 

cat << EOF > /tmp/nodeshell-$1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: shell-$1
  namespace: kube-system
spec:
  containers:
  - name: shell-$1
    image: docker.io/alpine:3.13
    command: ["nsenter", "-t", "1", "-m", "-u", "-i", "-n", "sleep", "14000"]
    securityContext:
      privileged: true
  hostIPC: true
  hostNetwork: true
  hostPID: true
  nodeName: $1
  restartPolicy: Never
EOF
kubectl apply -f /tmp/nodeshell-$1.yaml
sleep 10
kubectl -n kube-system exec -it shell-$1 -- /bin/bash
kubectl delete -f /tmp/nodeshell-$1.yaml
rm /tmp/nodeshell-$1.yaml
