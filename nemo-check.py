#!/usr/bin/python3
# Customization owner: omadjoudj

import configparser
import threading
import time as t
import argparse
from collections import defaultdict
from datetime import datetime, timedelta, timezone, time
import json
import logging
import subprocess
import re
import os
import sys
import socket
import nemo_client
from openstack import connection
from kubernetes import client, config
from flask import Flask, Response, jsonify, request
from prometheus_client import Counter, Gauge, CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST
from waitress import serve

LOGLEVEL = os.environ.get('LOGLEVEL', 'INFO').upper()

logger = logging.getLogger("nemo-checkster")
logger.setLevel(LOGLEVEL)

ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.DEBUG)
ch.setFormatter(logging.Formatter("[%(asctime)s] [%(name)s] %(levelname)s [%(threadName)s-%(thread)d]: %(message)s"))

logger.addHandler(ch)
logger.propagate = False

nemo_logger = logging.getLogger("nemo_client")
nemo_logger.handlers.clear()
nemo_logger.addHandler(ch)

#decorator to measure function duration
def track_duration(func):
    def wrapper(*args, **kwargs):
        start = t.time()
        result = func(*args, **kwargs)
        duration = t.time() - start
        return result, duration
    return wrapper


@track_duration
def nemo_list_crs_by_date(date, status, cloud_name):
    nemo_config = nemo_client.parse_config()
    r = nemo_client.fetch_crs_list(**nemo_config,on_date=date, status=status)
    logger.debug(f"nemo_fetch_crs results = {r.status} {r.reason}")
    crs = json.loads(r.read())
    logger.debug(f"crs = {crs}")
    r.close()
    total_crs_of_the_date = int(crs['count'])
    logger.debug(f'total_crs_of_the_date = {total_crs_of_the_date}')
    crs_of_the_date = [
        item for item in crs['results'] 
        if item['summary'].startswith(f'opscare/{cloud_name}')
    ]
    logger.debug(f"crs_for_the_date = {crs_of_the_date}")
    return crs_of_the_date


def check():
            # Connect to OpenStack
            os_conn = connection.Connection(cloud='admin',verify=False, user_agent="nemo-checkster")
            
            kube_config = client.Configuration()
            config.load_kube_config(config_file='/etc/kubeconfig/config',client_configuration=kube_config)

            # Disable SSL certificate verification
            kube_config.verify_ssl = False

            # Create API client with insecure config
            api_client = client.ApiClient(configuration=kube_config)

            v1_client = client.CoreV1Api(api_client)
            co_client = client.CustomObjectsApi(api_client)
            nemo_config = nemo_client.parse_config()
            nemo_checkster_config = parse_config()
            cloud_name = nemo_checkster_config['cloud_name']

            crs_in_planned, duration = nemo_list_crs_by_date(date="" , status="planned", cloud_name=cloud_name)
            crs_in_pending_deployment, duration = nemo_list_crs_by_date(date="", status="pending_deployment", cloud_name=cloud_name)

            crs = crs_in_pending_deployment + crs_in_planned
            logger.debug(f"Got CRS = {crs}")

def parse_config():
    config = configparser.ConfigParser()
    config_paths = [
        '/etc/nemo-checkster/nemo-checkster.conf'                    
    ]
    read_files = config.read(config_paths)
    if not read_files:
        raise FileNotFoundError(f"No configuration file found in any of these locations: {', '.join(config_paths)}")
    return config['nemo_checkster']

if __name__ == '__main__':
    check()