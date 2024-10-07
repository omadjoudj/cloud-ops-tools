#!/bin/bash

set -euo pipefail

silence-list="kubectl --context $KUBE_CONTEXT -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence"
silence-del="kubectl --context $KUBE_CONTEXT -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence expire"
silence-add="kubectl --context $KUBE_CONTEXT  -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence add -a $USER "
