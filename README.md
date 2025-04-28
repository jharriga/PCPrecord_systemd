# PCPrecord_systemd
Implements PCPrecord functionality as a systemd service.  
Supports the following 'actions'  
* Start  <-- starts PMLOGGER with cfg-file, e.g. CfgFiles/sbcpu.cfg  
* Stop  <-- stops PMLOGGER and completes PCP_Archive  
* Reset  <-- resets Workload Metrics, e.g. CfgFiles/openmetrics_workload.txt  
* WL-State 'value'  <-- writes 'state value' to Workload Metrics file, e.g. 'running 1'
* WL-Metric 'value' <-- writes 'metric value' to Workload Metrics file, e.g. 'latency 0.52'  
# Files: PCPrecord_systemd Service
* install_PCPbits.sh  <-- installs PCPrecord.service components & reqd Packages  
* update_svc.sh  <-- updates PCPrecord systemd files and reload/restarts svc  
* PCPrecord.service  <-- PCPrecord systemd unitfile  
* PCPrecord_actions.sh  <-- systemd service 'ExecScript' code. Processes 'actions'
* PCPrecord_timings.sh  <-- use in place of 'PCPrecord_actions.sh' - report service-side $action timings  
* pcp_functions.inc  <-- bash functions used by PCPrecord_actions.sh & PCPrecord_timings.sh
# Client Scripts & PCP Openmetrics config files
* Clients/archives_test.sh  <-- creates PCP Archives for a variety of Workload runtimes  
* Clients/client_cycle.sh  <-- exersizes PCPrecord_system service and reports client-side timings for $actions  
* Clients/cycle.cfg  <-- example PMLOGGER configuration file. Specifies Metrics to record in PCP Archive  
* Clients/client_sbcpu.sh  <-- example of Workload execution client code, 'sysbench cpu'  
* Clients/sbcpu.cfg  <-- example PMLOGGER configuration file. Specifies Metrics to record in PCP Archive  
* CfgFiles/openmetrics_rfchassis.txt  
* CfgFiles/RFchassis.url  
* CfgFiles/openmetrics_workload.txt  
* CfgFiles/workload.url  
# USAGE to start PCPrecord_systemd 
root# ./install_PCPbits.sh  
root# ./update_svc.sh  
# USAGE to run a sample Client
root# cd Clients  
root# chmod 755 *.sh  
root# Clients/client_sbcpu.sh  
  
