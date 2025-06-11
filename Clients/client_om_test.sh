#!/bin/bash
# CLIENT Script exercise OpenMetrics Workload function of the PCPrecord_system service
# Issues writes to the FIFO following the steps in 'action_arr'
#
pause=5
num_cycles=5
test_name='om_test'
pmlog_cfg="$PWD/${test_name}.cfg"
# String array of ACTIONS for each loop
# NOTE: throughput becomes available after 'running 0' and should disappear upon 'Reset'
action_arr=("Reset"\
  "Start"\
  "running 1"\
  "running 0"\
  "throughput 123.456"\
  "Stop")
actioncntr=0
##jom_workload_file="/tmp/openmetrics_workload.txt"

# Bring in FUNCTIONS and GLOBALS, inc $FIFO
source $PWD/client.inc

# MAIN #################################################
# Check that PCPrecord.SVC is running
systemctl is-active --quiet PCPrecord.service
fail_exit "PCPrecord.service not running"

echo "TEST Conditions: num_cycles=${num_cycles} Pause between Actions=${pause}sec"

for loopcntr in `seq 1 $num_cycles`; do
    echo; echo "Cycle Number: $loopcntr"
    for this_action in "${action_arr[@]}"; do
        if [[ "${this_action}" == 'Start' ]]; then
            archive_dir="$PWD/archive.$(date +%Y%m%d%H%M%S)"
            this_action="Start ${archive_dir} $test_name $pmlog_cfg"
        fi
##        echo "DEBUG this_action: ${this_action}"
        write_to_fifo "${this_action}"
        if [[ "${this_action}" == 'Stop' ]]; then
            # Notify user of PCP-Archive location
            echo -n "PCP Archive directory: ${archive_dir}"
            echo "test-name: $test_name"
            write_to_fifo 'Reset'   # Does not require PMLOGGER to be running
        fi
        ((++actioncntr))
    done
    sleep "$pause"
done
echo "Testing complete. Issued a total of ${actioncntr} Actions"
