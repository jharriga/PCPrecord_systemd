#!/bin/bash
# Extends openmetrics-pmda to record Redfish Smart PDU power readings
# Requires vars in 'RFvars.cfg' to be configured for URLs and Credentials

# VARs - import from CFG file
source /var/lib/pcp/pmdas/openmetrics/config.d/RFvars.cfg

# Get Readings - PDU1
curl -kfsS https://${RFpdu_user}:${RFpdu_passwd}@${RFpdu_ip1}${RFpdu_url1} | \
jq | \
awk -v str="$RFpdu_metric" '$0~str {
    print("# HELP RFpdus Redfish SmartPDU watts")
    print("# TYPE RFpdus gauge")
    printf("watts %.1f\n", $2)
}'
