#!/bin/bash
# CLIENT Script to exercise OpenMetrics Workload support for adding/removing
# metrics.  Issues writes to the FIFO following the steps in 'action_arr'
# NOTE: Metrics should only be reported in the Archive when they're
# listed in the 'openmetrics.txt' file.
###########################################################################
pause=5
num_cycles=5
test_name='om_test'
pmlog_cfg="$PWD/${test_name}.cfg"
# String array of ACTIONS for each loop
# NOTE: throughput and latency become available after the Workload
#   completes e.g.'running 0'. Those metrics should disappear w/'Reset'

action_arr=("Reset"\
  "Start"\
  "running 1"\
  "running 0"\
  "throughput 123.456"\
  "latency 0.987"\
  "Stop")
actioncntr=0
##om_workload_file="/tmp/openmetrics_workload.txt"

# Bring in FUNCTIONS and GLOBALS, inc $FIFO
source $PWD/client.inc

# MAIN #################################################
# Check that PCPrecord.SVC is running
systemctl is-active --quiet PCPrecord.service
fail_exit "PCPrecord.service not running"

echo "TEST Conditions: num_loops=${num_loops} Pause between Actions=${pause}sec"

for loopcntr in `seq 1 $num_loops`; do
    echo; echo "Loop Number: $loopcntr"
    for this_action in "${action_arr[@]}"; do
        if [[ "${this_action}" == 'Start' ]]; then
            archive_dir="$PWD/archive.$(date +%Y%m%d%H%M%S)"
            this_action="Start ${archive_dir} $test_name $pmlog_cfg"
        fi
##        echo "DEBUG this_action: ${this_action}"
        write_to_fifo "${this_action}"
        if [[ "${this_action}" == 'Stop' ]]; then
            # Notify user of PCP-Archive location
            echo -n "PCP Archive directory: ${archive_dir}  "
            echo "test-name: $test_name"
        fi
        ((++actioncntr))
    done
    sleep "$pause"      # pause after issuing each action to the fifo
done
# Final cleanup step
write_to_fifo 'Reset'   # Does not require PMLOGGER to be running
echo "Testing complete. Issued a total of ${actioncntr} Actions"
