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
# USAGE to run a sample Client
root# cd Clients  
root# chmod 755 *.sh  
root# Clients/client_sbcpu.sh  
# View Metrics with PMREP
root# pmrep -p -a ARCHIVE-NAME openmetrics.workload kernel.all.cpu.user | more
