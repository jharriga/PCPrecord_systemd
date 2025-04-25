#!/bin/bash
# ARCHIVES_TEST.sh      Uses PCPrecord systemd service to create PCP Archives
#                       for various TEST runtimes
#
# Monitor systemd-notify msgs with
#      $ watch -n 1 'systemctl status PCPrecord.service'
#########################################################################
num_iterations=5
test_name='sbcpu'
pmlog_cfg="$PWD/${test_name}.cfg"

runtime_array=(60 600 1800 3600)    # minutes: 1, 10, 30, 60
##rt_array_length=${#runtime_array[@]}

# Bring in FUNCTIONS and GLOBALS, inc $FIFO
source $PWD/client.inc
# Could these three vars be put in 'client.inc'?
iter_pause=10               # pause between iteration (testruns)
test_pause=30               # pause at start and stop of the PCP-Archive
om_workload_file="/tmp/openmetrics_workload.txt"

# MAIN #################################################
# Check that PCPrecord.SVC is running
systemctl is-active --quiet PCPrecord.service
fail_exit "PCPrecord.service not running"

# Outer Loop - iterate over various RUNTIME settings
# Create a new PCP Archive for each one
for this_rt in "${runtime_array[@]}"; do
    this_tn="${test_name}_${this_rt}"
    echo "**TEST Starting $this_tn"

    archive_dir="$PWD/archive_${this_rt}sec.$(date +%Y%m%d%H%M%S)"
    this_action="Start ${archive_dir} $this_tn $pmlog_cfg"

    # Now lets create an ARCHIVE and then run the Workload
    write_to_fifo "${this_action}"
    sleep "$test_pause"    # inserts quiet-time into beginning of Archive

    # Workload start - RESET Workload Metrics for this iteration
    write_to_fifo 'Reset'
    # Update Workload States
    # openmetrics.workload: iteration, running
    write_to_fifo 'running 1'
    write_to_fifo "iteration 1"

    echo "**PRE-Workload execution"
    cat /tmp/openmetrics_workload.txt; echo     # DEBUG
##    sysbench cpu run --time="$this_rt" --threads="$(nproc)">"$runlog" 2>&1
    sysbench cpu run --time="$this_rt" --threads=2>"$runlog" 2>&1

    # Workload done - update Workload State & Workload Metrics
    write_to_fifo 'running 0'
    # openmetrics.workload: throughput, latency, runtime, numthreads
    write_wl_metrics
    sleep "$test_pause"    # inserts quiet-time into end of Archive

    # Signal PCPrecord service to stop PMLOGGER
    write_to_fifo 'Stop'

    # Iteration done - PAUSE
    echo "**TEST Completed $this_tn"
    # Notify user of PCP-Archive location
    echo "PCP Archive directory: ${archive_dir}"

    echo "**PRE-Workload execution"
    cat /tmp/openmetrics_workload.txt; echo     # DEBUG
    sleep "$iter_pause" 
done
# END: Workload section

write_to_fifo 'Reset'      # Does not require PMLOGGER to be running

# All done with test-runs.
echo "All tests COMPLETED"
