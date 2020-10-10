#!/usr/bin/env python
# A script for collecting Ceph-related logs, config and data for MCP
# For bugs/issues contact: Othman Madjoudj <omadjoudj@mirantis.com>

import datetime
import json
import os
import subprocess
import sys

# sudo salt -C 'I@ceph:mon' --out=json test.ping
# sudo salt -C 'I@ceph:osd' --out=json test.ping

def salt_get_ceph_mons():
    return json.loads(subprocess.check_output(["sudo", "salt", "-C", 'I@ceph:mon', '--out', 'json', '--static', 'test.ping'])).keys()

def salt_get_ceph_osds():
    return json.loads(subprocess.check_output(["sudo", "salt", "-C", 'I@ceph:osd', '--out', 'json', '--static', 'test.ping'])).keys()

def run_ssh_command(node, cmd):
    return subprocess.check_output(["ssh", "-o", "StrictHostKeyChecking=no", node, cmd])

def collect_atop():
    pass

def collect_lsblk(collect_id):
    #TODO: check if the directories exists
    os.mkdir('%s' % (collect_id,))
    for node in salt_get_ceph_osds():
        os.mkdir('%s/%s' % (collect_id, node))
        print("I: Collecting lsblk on %s" % node)
        with open('%s/%s/lsblk.out' % (collect_id, node), 'w') as out_file:
            out_file.write(run_ssh_command(node, r"sudo lsblk"))

def collect_smartctl_or_vendor_tool(collect_id):
    #TODO: check if the directories exists
    #TODO: check if smartctl is installed, new Stacklight install it automatcly
    os.mkdir('%s' % (collect_id,))
    for node in salt_get_ceph_osds():
        os.mkdir('%s/%s' % (collect_id, node))
        print("I: Collecting smartctl on %s" % node)
        phy_disks_list = run_ssh_command(node, r"sudo lsblk -nd --output NAME").split('\n')
        phy_disks_list.remove('')
        for disk in phy_disks_list:
            with open('%s/%s/smartctl_%s.out' % (collect_id, node, disk), 'w') as out_file:
                out_file.write(run_ssh_command(node, r"sudo smartctl -a /dev/%s" % disk))

  

if __name__ == '__main__':
    NOW = datetime.datetime.now().isoformat()
#    print(salt_get_ceph_osds())
#    print(salt_get_ceph_mons())
#    collect_lsblk("test_"+NOW)
#    collect_smartctl_or_vendor_tool("test_"+NOW)
