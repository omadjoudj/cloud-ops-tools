#!/usr/bin/python
# Contact: omadjoudj

import subprocess
import sys

kubeconfig = str(sys.argv[1])
cluster_name = str(sys.argv[2])


ctl_nodes = subprocess.check_output("KUBECONFIG=%s  kubectl get -n %s machine -o custom-columns=NAME:.metadata.name | grep -vE 'NAME|osd|cmp'" % (kubeconfig, cluster_name), shell=True).decode().split("\n")
worker_nodes = subprocess.check_output("KUBECONFIG=%s  kubectl get -n %s machine -o custom-columns=NAME:.metadata.name | grep -E 'osd|cmp'" % (kubeconfig, cluster_name), shell=True).decode().split("\n")


ctl_nodes.remove("")
ctl_nodes.sort()
worker_nodes.remove("")
worker_nodes.sort()


# Create new list when 1 ctl is picked then 20 worker are picked to avoid 
# deadlock when parallel upgrade is enabled (FIELD-6451, FIELD-6386)

reindex_nodes = []

for i in range(len(cluster_name)+len(worker_nodes)):
    if i % 20 == 0:
        if len(ctl_nodes) != 0:
            reindex_nodes.append(ctl_nodes.pop())
    else:
        if len(worker_nodes) != 0:
            reindex_nodes.append(worker_nodes.pop())

for i in range(len(reindex_nodes)):
    print("kubectl patch  machine %s -n %s  --type=\'json\' -p=\'[{\"op\": \"replace\",\"path\": \"/spec/providerSpec/value/upgradeIndex\",\"value\": %s}]\'" % (reindex_nodes[i], cluster_name, str(i+1)))

