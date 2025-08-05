#!/bin/bash
# Extends openmetrics-pmda to record Redfish Chassis power readings
# Requires vars in 'RFvars.cfg' to be configured for URLs and Credentials

# VARs - import from CFG file
source /var/lib/pcp/pmdas/openmetrics/config.d/RFvars.cfg

# Get Readings
curl -kfsS https://${RFchassis_user}:${RFchassis_passwd}@${RFchassis_ip}${RFchassis_url} | jq | \
awk -v str="$RFchassis_metric" '$0~str {
    print("# HELP RFchassis Redfish Chassis watts")
    print("# TYPE RFchassis gauge")
    printf("watts %.1f\n", $2)
}'
