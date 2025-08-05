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
* PCPrecord_actions.sh  <-- systemd service 'ExecStart' code. Processes 'actions' & reports service-side timings  
* pcp_functions.inc  <-- bash functions used by PCPrecord_actions.sh & PCPrecord_timings.sh
# USAGE to start PCPrecord_systemd 
root# ./install_PCPbits.sh  
root# ./update_svc.sh  
# USAGE to run a sample Client
root# cd Clients  
See README.md    

# To Record Power Usage  
cd PowerReadings  
See README.md  
