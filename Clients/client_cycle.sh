#!/bin/bash
# CLIENT Script which exercises PCPrecord_system service
# Issues writes to the FIFO to invoke multiple 'Start' / 'Stop' cycles
pause=5
num_cycles=5
test_name='cycle'
pmlog_cfg="$PWD/${test_name}.cfg"
# String array of ACTIONS for each cycle
action_arr=("Reset"\
  "Start"\
  "running 1"\
  "running 0"\
  "Stop")
actioncntr=0
jom_workload_file="/tmp/openmetrics_workload.txt"

# Bring in FUNCTIONS and GLOBALS, inc $FIFO
source $PWD/client.inc

# MAIN #################################################
# Check that PCPrecord.SVC is running
systemctl is-active --quiet PCPrecord.service
fail_exit "PCPrecord.service not running"

for loopcntr in `seq 1 $num_cycles`; do
    echo; echo "Cycle Number: $loopcntr"
    for this_action in "${action_arr[@]}"; do
        if [[ "${this_action}" == 'Start' ]]; then
            archive_dir="$PWD/archive.$(date +%Y%m%d%H%M%S)"
            this_action="Start ${archive_dir} $test_name $pmlog_cfg"
        fi
        pre_ms=$(mark_ms)
##        echo "DEBUG this_action: ${this_action}"
        write_to_fifo "${this_action}"
        post_ms=$(mark_ms)
        duration_ms=$(( 10*(post_ms - pre_ms) ))
        echo "> ${duration_ms}ms for: ${this_action}"
        if [[ "${this_action}" == 'Stop' ]]; then
            # Notify user of PCP-Archive location
            echo -n "PCP Archive directory: ${archive_dir}  "
            echo "test-name: $test_name"
            write_to_fifo 'Reset'   # Does not require PMLOGGER to be running
        fi
        ((++actioncntr))
    done
    sleep "$pause"
done
echo "Testing complete. Issued a total of ${actioncntr} Actions"

