#!/bin/bash
# CLIENT_MINIMAL.sh      Minimally exercises systemd-notify based service
# Observe overhead by running with 'time'
#   With num_iterations=100, sleep 0.1 and no Workload running
#   RESULTS: real 0m9.940s user	0m2.597s sys 0m5.069s
#     > PREtimer=50ms        POSTtimer=50m
#   Removing 'timeout' SYNC point: real 3.8s user 0.027s sys 0.022s
#     > PREtimer=20ms        POSTtimer=20ms
# 
# Monitor systemd-notify msgs with
#      $ watch -n 1 'systemctl status fifo.service'
#########################################################################
FIFO="/tmp/FIFO"
metrics_file="/tmp/metrics_file.txt"  # should this be passed into the svc?
output="output_minimal_$(date +%Y%m%d_%H%M%S).txt"
timeout_short=2             # wait-time for Workload Metric actions
pause_to="0.01"             # Pause interval within write_to_fifo Timeout
num_iterations=100

# BEGIN FUNCTIONS #################################################
fail_exit() {
    if [ "$?" != "0" ]; then
        echo "ERROR: $1"
        # Additional error handling logic can be added here
        exit 1
    fi
}

write_to_fifo() {
    # Special case for "SYNC" - skips the printf
    request_str=$1

    # Is the FIFO.SVC reporting Status='READY'?
    # this appears to be SYS time heavy
    timeout $timeout_short bash -c \
      "until systemctl status fifo.service | grep -q "READY:" \
      ; do sleep $pause_to; done"
    # Trap timeout condition
    if [ $? -eq 124 ]; then
        echo "Timed out waiting for systemd status=READY: \
          Request=$request_str"
        exit 2
    fi

    # Function used to SYNC with systemd svc - don't printf
    if [ "${request_str}" != 'SYNC' ]; then
        printf '%s\n' "$request_str" >"$FIFO" 
    fi
}
# END FUNCTIONS #################################################

# MAIN #################################################

# Check that FIFO.SVC is running
systemctl is-active --quiet fifo.service
fail_exit "fifo.service not running"

echo "Running $num_iterations iterations. Results in file: $output"

# BEGIN: Issue FIFO Requests repeatedly and use timer(ms)
for loopcntr in `seq 1 $num_iterations`; do
    # Start (ms) TIMER for PRE-workload activties
    read up rest </proc/uptime; start_pre="${up%.*}${up#*.}"

    # Approaching Workload start - RESET Workload Metrics for this iteration
    write_to_fifo 'Reset'
    # Ensure final 'write_to_fifo' completes
    write_to_fifo 'SYNC'
    # Stop TIMER for pre-workload activties
    read up rest </proc/uptime; stop_pre="${up%.*}${up#*.}"
    duration_pre=$(( 10*(stop_pre - start_pre) ))

    ######################
    # Execute workload
    #----------------------

    # Start (ms) TIMER for POST-workload activties
    read up rest </proc/uptime; start_post="${up%.*}${up#*.}"
    # Workload done - update Workload State & Workload Metrics
    write_to_fifo 'running 0'
    # Ensure final 'write_to_fifo' completes
    write_to_fifo 'SYNC'
    # Stop Timer POST
    read up rest </proc/uptime; stop_post="${up%.*}${up#*.}"
    duration_post=$(( 10*(stop_post - start_post) ))

    # Iteration done 
    echo "> PREtimer=${duration_pre}ms  \
      POSTtimer=${duration_post}ms" >> "$output"; echo >> "$output" 
##    sleep "$iter_pause" 
done
# END: FIFO Requests section

# All done with test-run. Small PAUSE to view systemd-notify msg

