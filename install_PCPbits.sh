#!/bin/bash
# Prepare for bare-metal testruns of the PCPrecord systemd svc unitfile

# Install PCP and Workload packages
dnf install -y --setopt=tsflags=nodocs \
  pcp-zeroconf pcp-pmda-openmetrics pcp-pmda-denki \
  sysbench \
  jq \
  && \
dnf clean all && \
touch /var/lib/pcp/pmdas/{openmetrics,denki}/.NeedInstall

# Does pcp-zeroconf already do this - redundant?
systemctl enable pmcd pmie pmlogger pmproxy

# Configure RFchassis openmetrics scripting w/hardcoded values
##cp -f CfgFiles/openmetrics_RFchassis.txt /tmp/.
##cp -f CfgFiles/RFchassis.url /var/lib/pcp/pmdas/openmetrics/config.d/.

# Configure Workload openmetrics scripting
cp -f CfgFiles/openmetrics_workload.txt /tmp/.
cp -f CfgFiles/workload.url /var/lib/pcp/pmdas/openmetrics/config.d/.
systemctl restart pmcd
sleep 5
# VERIFY
pcp
##pmrep -s 3 denki.rapl openmetrics.RFchassis
pmrep --ignore-incompat -s 3 openmetrics.RFchassis

