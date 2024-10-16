#!/bin/bash
# ~omadjoudj
# A script to silence the alerts when running the upgrade and allows some to go through
# Colors
RESTORE='\033[0m'
YELLOW='\033[00;33m'



alert_submitter="$USER"
duration="2h"
comment="MW silence via `basename $0`"

if [ -n "$1" ]; then
    duration="$1"
fi

if [ -n "$2" ]; then
    comment="$2 / via `basename $0`"
fi

echo -e "Setting a silence for$YELLOW $duration $RESTORE with the comment:$YELLOW $comment $RESTORE"

kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence add -a "$alert_submitter"  -d $duration -c "$comment"  "alertname!~Watchdog|TestVMCreateError|TestVMPingError|TestVMCreateTooLong|OpenstackServiceInternalApiOutage|OpenstackServicePublicApiOutage|OpenstackPublicAPI5xxCritical|OpenstackAPI5xxCritical|OpenstackAPI401Critical|OpenstackPublicAPIErrorRateExceedsUpgradeSLA|CloudproberReportingVMsDown|PowerDNSResolutionFailure|etcdDbSizeCritical|etcdDbSizeMajor|MCCAutoUpgradeEnabled|NovaErrorInstancesGrowth"