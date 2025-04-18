# PCPrecord_systemd
Implements PCPrecord functionality as a systemd service.  
Supports the following 'actions'  
* Start  <-- starts PMLOGGER with cfg-file, e.g. CfgFiles/sbcpu.cfg  
* Stop  <-- stops PMLOGGER and completes PCP_Archive  
* Reset  <-- resets Workload Metrics, e.g. CfgFiles/openmetrics_workload.txt  
* WL-State 'value'  <-- writes 'state value' to Workload Metrics file, e.g. 'running 1'
* WL-Metric 'value' <-- writes 'metric value' to Workload Metrics file, e.g. 'latency 0.52'  
# Files
* install_PCPbits.sh  <-- installs PCPrecord.service components & reqd Packages  
* update_svc.sh  <-- updates PCPrecord systemd files and reload/restarts svc  
* PCPrecord.service  <-- PCPrecord systemd unitfile  
* PCPrecord_actions.sh  <-- systemd service 'ExecScript' code. Processes 'actions'  
* pcp_functions.inc  <-- bash functions used by PCPrecord_actions.sh  
* sbcpu_example.sh  <-- example of Workload execution client code, 'sysbench cpu'.  
* sbcpu.cfg  <-- example PMLOGGER configuration file. Specifies Metrics to record in PCP Archive  
* CfgFiles/openmetrics_rfchassis.txt  
* CfgFiles/RFchassis.url  
* CfgFiles/openmetrics_workload.txt  
* CfgFiles/workload.url  
# USAGE
root# git clone  
root# chmod -R 755 *.sh  
root# ./install_PCPbits.sh  
root# ./update_svc.sh  
root# ./sbcpu_example.sh  
  
