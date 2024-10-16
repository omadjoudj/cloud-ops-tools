#!/usr/bin/python
# Contact: omadjoudj

import subprocess
import sys

kubeconfig = str(sys.argv[1])
cluster_name = str(sys.argv[2])
BATCH_SIZE=5
OFFSET=500

ctl_nodes = subprocess.check_output("KUBECONFIG=%s  kubectl get -n %s machine -o custom-columns=NAME:.metadata.name | grep -vE 'NAME|osd|cmp'" % (kubeconfig, cluster_name), shell=True).decode().split("\n")
## cmp removed since they need to end indexed last as we will be switching to NodeWorkLoadLock-based approach
osd_nodes = subprocess.check_output("KUBECONFIG=%s  kubectl get -n %s machine -o custom-columns=NAME:.metadata.name | grep -E osd" % (kubeconfig, cluster_name), shell=True).decode().split("\n")
cmp_nodes = subprocess.check_output("KUBECONFIG=%s  kubectl get -n %s machine -o custom-columns=NAME:.metadata.name | grep -E cmp" % (kubeconfig, cluster_name), shell=True).decode().split("\n")

## Clean up
ctl_nodes.remove("")
osd_nodes.remove("")
cmp_nodes.remove("")

ctl_nodes.sort(reverse=True)
osd_nodes.sort(reverse=True)
cmp_nodes.sort(reverse=True)

# Create new list when 1 ctl is picked then 5 worker are picked to avoid 
# deadlock when parallel upgrade is enabled (FIELD-6451, FIELD-6386)


reindex_nodes = []
i=0
while True:
    if len(ctl_nodes)==0 and len(osd_nodes)==0:
        break

    # Reduced to 5 since we dont have enought osds
    if i % BATCH_SIZE == 0 and  len(ctl_nodes) != 0:
        reindex_nodes.append(ctl_nodes.pop())
    else:
        reindex_nodes.append(osd_nodes.pop())
    i+=1
    
while True:
    if len(cmp_nodes)==0:
        break
    # Put back cmp nodes at the end of the list
    reindex_nodes.append(cmp_nodes.pop())
    

for i in range(len(reindex_nodes)):
    if 'cmp' in reindex_nodes[i]:
        # Offset compute index so we have room for manual rescheduling 
        new_upgrade_index=str(OFFSET+i+1)
    else:
        new_upgrade_index = str(i+1)
    
    print("kubectl patch  machine %s -n %s  --type=\'json\' -p=\'[{\"op\": \"replace\",\"path\": \"/spec/providerSpec/value/upgradeIndex\",\"value\": %s}]\'" % (reindex_nodes[i], cluster_name, new_upgrade_index ))

