#!/bin/bash
################################################################

# GLOBALS ###################

# Files
FIFO="/tmp/pcpFIFO"   
om_workload_file="/tmp/openmetrics_workload.txt"
iteration_results="/tmp/iteration_results.txt"   # one iteration results
full_results="/tmp/workload_results.txt"         # full test run results
# Define Workload
num_iterations=5    # Number of test run iterations
iteration_pause=60
##iteration_pause=15   # Shorter pause between iterations
runtime=100         # Runtime duration for each workload test iteration
thread_cnt=$(nproc)                            # use all cores

# Use an array to build up cmdline with runtime args
cmdline=( sysbench cpu run --time="$runtime" --threads="$thread_cnt" )
output=">$iteration_results 2>&1"           # specific to $workload output
exec_str="${cmdline[@]} ${output}"

#############################

# Functions #################

#############################

# Main #################
echo "Test started. Workload not yet run."
echo "Runtime:$runtime  NumIterations:$num_iterations \
     Iteration Pause:$iteration_pause"

#----------------------------------
# Start PMLOGGER to create ARCHIVE
echo "Start" > "$FIFO"
#pcp_verify $pcp_conf_file
##pcp_start $pcp_conf_file $pcp_sample_rate $pcp_archive_dir $pcp_archive_name
#pcp_start $pcp_conf_file 5 $pcp_archive_dir sysbenchTEST

# Start loop to run workload five times
for loopcntr in `seq 1 $num_iterations`; do
    # Set the openmetrics.workload metrics for this loop
    wl_iteration=$loopcntr ; wl_started=1 ; wl_finished=0
    wl_numthreads=0 ; wl_runtime="NaN" ; wl_throughput="NaN" ; wl_latency="NaN"
    update_om_workload "$wl_iteration" "$wl_started" "$wl_finished" \
           "$wl_numthreads" "$wl_runtime" "$wl_throughput" "$wl_latency"

    # Execute the Workload
    return=$(eval "$exec_str")  
    echo "Iteration $wl_iteration completed" 

    # PUT THIS IN FUNCTION
    # Set/Get the workload results then update openmetrics file
    # Do this in two steps. 
    # First set the 'states' (fast)
    wl_iteration=$loopcntr ; wl_started=0 ; wl_finished=1
    update_om_workload "$wl_iteration" "$wl_started" "$wl_finished" \
           "$wl_numthreads" "$wl_runtime" "$wl_throughput" "$wl_latency"

    # Now get the workload stats (slower, overhead of calling awk)
#    wl_numthreads="$(${awk_numthreads} ${iteration_results})"   # Needs DEBUG
#    echo $wl_numthreads                 # DEBUG

    # For now use HARD-CODED to SYSBENCH regex string for parsing
    wl_numthreads="$(awk '/Number of threads/ {printf("%d", $4)}' $iteration_results)"
    wl_runtime="$(awk '/total time/ {printf("%.3f", $3)}' $iteration_results)"
    wl_throughput="$(awk '/events per second/ {printf("%.3f", $4)}' $iteration_results)"
    wl_latency="$(awk '/95th/ {printf("%.3f", $3)}' $iteration_results)"
    update_om_workload "$wl_iteration" "$wl_started" "$wl_finished" \
           "$wl_numthreads" "$wl_runtime" "$wl_throughput" "$wl_latency"

    # Append this iteration's results to full results log
    cat $iteration_results>>$full_results
    rm -f $iteration_results               # Cleanup for next iteration
    sleep "$iteration_pause"               # Pause between iterations
done

# MOSTLY DONE
# Delay for DEBUG and to allow PMLOGGER completes several reads
##echo "Pausing for 30s"
##sleep 30
# Terminate PMLOGGER. Flush buffers by sending SIGUSR1 signal
#pcp_stop
echo "Stop" > "$FIFO"

# Store test artifacts
mv $full_results "${pcp_archive_dir}/workload.txt"
echo "Full workload log is at ${pcp_archive_dir}/workload.txt"

# Verify PCP ARCHIVE was created and list contents
echo; echo "${pcp_archive_dir}"
ls -l "${pcp_archive_dir}"

# Cleanup
echo "Cleaning up"
rm -f $iteration_results

# Reset openmetric.workload metric values prior to leaving
reset_om_metrics
echo "DONE"

