#!/usr/bin/env python
# A script for collecting Ceph-related logs, config and data for MCP
# For bugs/issues contact: Othman Madjoudj <omadjoudj@mirantis.com>

#NOTE: By default Salt on MCP does not allow copying files from minions to master
#NOTE: Using Salt API directly was avoided due to version differences

import datetime
import json
import os
import re
import subprocess
import sys

# sudo salt -C 'I@ceph:mon' --out=json --static test.ping
# sudo salt -C 'I@ceph:osd' --out=json --static test.ping

def salt_get_ceph_mons():
    return json.loads(subprocess.check_output(["sudo", "salt", "-C", 'I@ceph:mon', '--out', 'json', '--static', 'test.ping'])).keys()

def salt_get_ceph_osds():
    try:
        return json.loads(subprocess.check_output(["sudo", "salt", "-C", 'I@ceph:osd', '--out', 'json', '--static', 'test.ping'])).keys()
    except Exception as e:
        return "SSH_COMMAND_FAILED: %s" % str(e)

def run_ssh_command(node, cmd):
    return subprocess.check_output(["ssh", "-q", "-o", "StrictHostKeyChecking=no", node, cmd])

def run_scp(node, remote_path, local_path):
    return subprocess.check_output(["scp", "-q", "-o", "StrictHostKeyChecking=no", "-r", "%s:%s" % (node, remote_path), local_path])

#TODO: Add possibility to remove node via env vairables EXCLUDE_NODES=node1:node2:...

def collect_cmd_output(collect_id, nodes, cmd):
    for node in nodes:
        if not os.path.exists('%s/%s' % (collect_id, node)):
            os.mkdir('%s/%s' % (collect_id, node))
        print("I: Collecting %s on %s" % (cmd, node))
        #cmd_output_filename = cmd.replace(" ", "_") + '.out'
        cmd_output_filename = re.sub("[<|/>]","_", cmd.replace(" ","_")) + '.out'
        with open('%s/%s/%s' % (collect_id, node, cmd_output_filename), 'w') as out_file:
            out_file.write(run_ssh_command(node, cmd))


def collect_lsblk(collect_id, nodes):
    collect_cmd_output(collect_id, nodes, r"sudo lsblk")

def collect_ceph_disk_list(collect_id, nodes):
    collect_cmd_output(collect_id, nodes, r"sudo ceph-disk list")

def collect_smartctl_or_vendor_tool(collect_id, nodes):
    #TODO: check if smartctl is installed, should be there by default sice Stacklight needs it
    for node in nodes:
        if not os.path.exists('%s/%s' % (collect_id, node)):
            os.mkdir('%s/%s' % (collect_id, node))
        phy_disks_list = run_ssh_command(node, r"sudo lsblk -nd --output NAME").split('\n')
        phy_disks_list.remove('')
        node_model =  run_ssh_command(node, r"sudo dmidecode -s system-product-name")
        #print(node_model)
        # If Server model is HP Proliant use the vendor specific tool since smart is emulated 
        if 'ProLiant' in node_model:
            print("I: Collecting hpssacli on %s" % node)
            with open('%s/%s/hpssacli.out' % (collect_id, node), 'w') as out_file:
                out_file.write(run_ssh_command(node, r'sudo /usr/sbin/hpssacli "ctrl all show config detail"' ))
        else:
            print("I: Collecting smartctl on %s" % node)
            for disk in phy_disks_list:
                with open('%s/%s/smartctl_%s.out' % (collect_id, node, disk), 'w') as out_file:
                    out_file.write(run_ssh_command(node, r"sudo smartctl -a /dev/%s" % disk))

def collect_ceph_conf(collect_id, nodes):
    collect_cmd_output(collect_id, nodes, r"sudo cat /etc/ceph/ceph.conf")

def collect_ceph_osd_running_conf(collect_id, nodes):
    for node in nodes:
        if not os.path.exists('%s/%s' % (collect_id, node)):
            os.mkdir('%s/%s' % (collect_id, node))
        osds_socket_list = run_ssh_command(node, r"sudo ls /var/run/ceph/").split('\n')
        osds_socket_list.remove('')
        #print(osds_socket_list)
        for osd_socket in osds_socket_list:
            collect_cmd_output(collect_id, [node], r"sudo ceph daemon /var/run/ceph/%s config show" % (osd_socket,))


def collect_atop(collect_id, nodes):
    for node in nodes:
        if not os.path.exists('%s/%s' % (collect_id, node)):
            os.mkdir('%s/%s' % (collect_id, node))
        print("I: Collecting recent atop files from %s" % node)
        recent_atop_files = run_ssh_command(node, r"find /var/log/atop/ -name 'atop_*' -mtime -1").split('\n')
        recent_atop_files.remove('')
        #print(recent_atop_files)
        for atop_file in recent_atop_files:
            run_scp(node, atop_file , '%s/%s' % (collect_id, node))

def collect_cluster_data(collect_id, mon_node):
    print("I: Collecting Ceph clutser data from %s" % mon_node)
    print("I: Collecting CRUSH map")
    run_ssh_command(mon_node, r"mkdir /tmp/%s" % collect_id)
    run_ssh_command(mon_node, r"sudo ceph osd getcrushmap -o /tmp/%s/crush.bin" % collect_id)
    run_ssh_command(mon_node, r"sudo crushtool -d /tmp/%s/crush.bin -o /tmp/%s/crushmap.txt" % (collect_id, collect_id))
    print("I: Collecting cluster status")
    run_ssh_command(mon_node, r"sudo ceph -s -f json -o /tmp/%s/ceph_s.json" % collect_id )
    print("I: Collecting monmap")
    run_ssh_command(mon_node, r"sudo ceph mon dump -f json -o /tmp/%s/monmap.json" % collect_id )
    print("I: Collecting ceph df")
    run_ssh_command(mon_node, r"sudo ceph df -f json -o /tmp/%s/ceph_df.json" % collect_id )
    print("I: Collecting ceph osd df")
    run_ssh_command(mon_node, r"sudo ceph osd df -f json -o /tmp/%s/ceph_osd_df.json" % collect_id )
    print("I: Collecting ceph osd dump")
    run_ssh_command(mon_node, r"sudo ceph osd dump -f json -o /tmp/%s/ceph_osd_dump.json" % collect_id)
    print("I: Collecting rados df")
    run_ssh_command(mon_node, r"sudo rados df -f json > /tmp/%s/rados_df.json" % collect_id )
    print("I: Collecting ceph report")
    run_ssh_command(mon_node, r"sudo ceph report -o /tmp/%s/ceph_report.json" % collect_id )
    print("I: Collecting auth data anonymized")
    run_ssh_command(mon_node, r"sudo ceph auth list -f json |sed 's/AQ[^=]*==/KEY/g' > /tmp/%s/ceph_auth_ls.json" % collect_id)
    print("I: Collecting ceph pg dump")
    run_ssh_command(mon_node, r"sudo ceph pg dump -f json -o /tmp/%s/ceph_pg_dump.json" % collect_id )
    print("I: Collecting ceph osd perf")
    run_ssh_command(mon_node, r"sudo ceph osd perf -o /tmp/%s/ceph_osd_perf.out" % collect_id )
    run_ssh_command(mon_node, r"sudo chmod o+r /tmp/%s/*" % collect_id)
    if not os.path.exists('%s/cluster_data' % (collect_id,)):
        os.mkdir('%s/cluster_data' % (collect_id,))
    run_scp(mon_node, '/tmp/%s/*' % collect_id  , '%s/cluster_data/' % (collect_id,))

def create_collect_archive():
    NOW = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    osd_nodes = salt_get_ceph_osds()
    mon_nodes = salt_get_ceph_mons()
    customer = ""
    cluster = mon_nodes[0]
    # Override if defined
    try:
        customer = sys.argv[1]
        cluster = sys.argv[2]
    except IndexError:
        print("W: Using automatically generated names, correct usage is:")
        print("W: %s [CUSTOMER] [CLUSTER NAME]" % sys.argv[0])

    collect_id = '%s_%s_%s' % (customer, cluster, NOW)
    os.mkdir('%s' % (collect_id,))
    collect_lsblk(collect_id, osd_nodes)
    collect_ceph_disk_list(collect_id, osd_nodes)
    collect_ceph_conf(collect_id, osd_nodes + mon_nodes)
    collect_ceph_osd_running_conf(collect_id, osd_nodes)
    try:
        collect_atop(collect_id, osd_nodes)
    except Exception as e:
        print("E: Error while collecting atop, make sure atop is installed")
        print(e)

    try:
        collect_smartctl_or_vendor_tool(collect_id, osd_nodes)
    except Exception as e:
        print("E: Error while collecting SMART/HPSSA, make sure smartctl or hpssacli is installed, and if the devices support those tools")
        print(e)
    # Only one mon node is needed for this
    collect_cluster_data(collect_id, mon_nodes[0])
    os.system("tar Jcf %s.tar.bz2 ./%s/" % (collect_id, collect_id,))

if __name__ == '__main__':
    create_collect_archive()
