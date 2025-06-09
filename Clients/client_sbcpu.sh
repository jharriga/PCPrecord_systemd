#!/bin/bash
# client_sbcpu.sh      Uses PCPrecord systemd service to record PCP Archives
#                      for multiple 'sysbench cpu run' TESTruns
#
#########################################################################

# Define Workload
test_name='sbcpu'   # Used to set archive name
num_iterations=5    # Number of test run iterations
##iteration_pause=60  # Quiet-time between test-runs
iteration_pause=5  # Quiet-time between test-runs
##runtime=100         # Runtime duration for each workload test iteration
runtime=20         # Runtime duration for each workload test iteration
thread_cnt=$(nproc) # Use all cores
# Use an array to build up cmdline with runtime args
cmdline=( sysbench cpu run --time="$runtime" --threads="$thread_cnt" )
iteration_results="/tmp/iteration_results.txt"   # per iteration results
output=">$iteration_results 2>&1"           # specific to $workload output
exec_str="${cmdline[@]} ${output}"

# Bring in FUNCTIONS and GLOBALS, inc $FIFO
source $PWD/client.inc

# Could some of these vars be put in 'client.inc'?
# Files
full_results="/tmp/workload_results.txt"         # full test run results
om_workload_file="/tmp/openmetrics_workload.txt"
pmlog_cfg="$PWD/${test_name}.cfg"
archive_dir="$PWD/archive_${test_name}.$(date +%Y%m%d%H%M%S)"

# MAIN #################################################
# Check that PCPrecord.SVC is running
systemctl is-active --quiet PCPrecord.service
fail_exit "PCPrecord.service not running"

echo "Test started. Workload not yet run."
echo "Runtime:$runtime  NumIterations:$num_iterations \
     Iteration Pause:$iteration_pause" | tee -a "${full_results}"
rm -f $iteration_results             # Cleanup for first iteration
#-------------------------------------
# Start PMLOGGER to create the ARCHIVE
start_action="Start ${archive_dir} $test_name $pmlog_cfg"
# TIMER (ms) to measure start time
prestart=$(mark_ms)
write_to_fifo "${start_action}"
poststart=$(mark_ms)
duration_start=$(( 10*(poststart - prestart) ))

# Start loop to run workload multiple times
for loopcntr in `seq 1 $num_iterations`; do
    echo "Iteration $loopcntr started, pausing $iteration_pause sec" 
    # Workload start - RESET Workload Metrics for this iteration
    write_to_fifo 'Reset'
    sleep "$iteration_pause"    # inserts quiet-time into Archive
    # Update Workload States
    # openmetrics.workload: iteration, running
    write_to_fifo 'running 1'
    write_to_fifo "iteration ${loopcntr}"
##    cat /tmp/openmetrics_workload.txt

    # Execute the Workload
    return=$(eval "$exec_str")  
    echo "Iteration $loopcntr completed" 

    # Workload done - update Workload State & Workload Metrics
    write_to_fifo 'running 0'
    # openmetrics.workload: throughput, latency, runtime, numthreads
    runlog=$iteration_results      # defined in client.inc
    write_wl_metrics

    # ensure openmetrics metrics persist for a few seconds
    echo "Iteration $loopcntr completed, pausing $iteration_pause sec" 
    sleep "$iteration_pause"    # inserts quiet-time into Archive
##    cat /tmp/openmetrics_workload.txt

    # Append this iteration's results to full results log
    cat $iteration_results>>$full_results
    rm -f $iteration_results               # Cleanup for next iteration
done
# END: Workload section

echo "All test-runs completed, pausing $iteration_pause sec" | tee -a "${full_results}"
sleep "$iteration_pause"    # inserts quiet-time at end of Archive

# Signal PCPrecord service to stop PMLOGGER
# TIMER to measure stop time
prestop=$(mark_ms)
write_to_fifo 'Stop'
# Stop TIMER for 'Stop' and report interval
poststop=$(mark_ms)
duration_stop=$(( 10*(poststop - prestop) ))
echo "> STARTtimer=${duration_start}ms  \
      STOPtimer=${duration_stop}ms" | tee -a "${full_results}"

# Notify user of PCP-Archive location
echo "PCP Archive directory: ${archive_dir}" | tee -a "${full_results}"

# Store test artifacts & cleanup
mv $full_results "${archive_dir}/workload.txt"
echo "Full workload log for all test-runs is at ${archive_dir}/workload.txt"
rm -f $iteration_results

# All done with test-runs. Reset openmetric.workload metrics before exiting
write_to_fifo 'Reset'      # Does not require PMLOGGER to be running
echo "All tests COMPLETED"
