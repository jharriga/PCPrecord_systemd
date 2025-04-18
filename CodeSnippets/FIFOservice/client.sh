#!/bin/bash
# CLIENT.sh            Exercises systemd-notify based service
# Observe overhead by running with 'time'
#   With num_iterations=100, sleep 0.1 and no Workload running
#   RESULTS: real 1m12.8s    user 0m9.8s   sys 0m19.1s
#     Changing 'sleep {0.1, 0.2, 1}' in 'write_to_fifo' = no change
#     Disabling AWKs: real 0m25.5s  user 0m6.6s sys 0m12.9s (100ms/awk)
# 
# Monitor systemd-notify msgs with
#      $ watch -n 1 'systemctl status fifo.service'
#########################################################################
FIFO="/tmp/FIFO"
metrics_file="/tmp/metrics_file.txt"  # should this be passed into the svc?
runlog="./runlog.txt"       # existing 'sysbench cpu' results
output="output_client_$(date +%Y%m%d_%H%M%S).txt"
timeout_long=10             # wait-time for Start and Stop actions
timeout_short=2             # wait-time for Workload Metric actions
pause_to="0.1"              # Pause interval within write_to_fifo Timeout
num_iterations=100
iter_pause=1                # Currently IGNORED

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

# INITIAL Check if timeout on service readiness is working
##write_to_fifo 'GARBAGE'

# BEGIN: Issue FIFO Requests repeatedly and use timer(ms)
for loopcntr in `seq 1 $num_iterations`; do
    # Start (ms) TIMER for PRE-workload activties
    read up rest </proc/uptime; start_pre="${up%.*}${up#*.}"

    # Approaching Workload start - RESET Workload Metrics for this iteration
    write_to_fifo 'Reset'
    # Update Workload States
    write_to_fifo 'running 1'
    write_to_fifo "iteration ${loopcntr}"
    # Ensure final 'write_to_fifo' completes
    write_to_fifo 'SYNC'
    # Stop TIMER for pre-workload activties
    read up rest </proc/uptime; stop_pre="${up%.*}${up#*.}"
    duration_pre=$(( 10*(stop_pre - start_pre) ))

    echo "**PRE-Workload execution" >> "$output"
    cat "$metrics_file" >> "$output"; echo >> "$output"   # DEBUG
##    sysbench cpu run --time="$runtime" --threads="$(nproc)">"$runlog" 2>&1
##    sleep 1

    # Start (ms) TIMER for POST-workload activties
    read up rest </proc/uptime; start_post="${up%.*}${up#*.}"
    # Workload done - update Workload State & Workload Metrics
    write_to_fifo 'running 0'
    # openmetrics.workload: throughput, latency, runtime, numthreads
    wl_throughput="$(awk '/events per second/ {printf("%.3f", $4)}' $runlog)"
    write_to_fifo "throughput ${wl_throughput}"
    wl_latency="$(awk '/95th/ {printf("%.3f", $3)}' $runlog)"
    write_to_fifo "latency ${wl_latency}"
    wl_runtime="$(awk '/total time/ {printf("%.3f", $3)}' $runlog)"
    write_to_fifo "runtime ${wl_runtime}"
    wl_numthreads="$(awk '/Number of threads/ {printf("%d", $4)}' $runlog)"
    write_to_fifo "numthreads ${wl_numthreads}"
    # Ensure final 'write_to_fifo' completes
    write_to_fifo 'SYNC'
    # Stop Timer POST
    read up rest </proc/uptime; stop_post="${up%.*}${up#*.}"
    duration_post=$(( 10*(stop_post - start_post) ))

    # Iteration done 
    echo "**POST-Workload execution" >> "$output"
##    cat "$metrics_file" >> "$output"; echo >> "$output"   # DEBUG
    cat "$metrics_file" >> "$output"   # DEBUG
    echo "> PREtimer=${duration_pre}ms  \
      POSTtimer=${duration_post}ms" >> "$output"; echo >> "$output" 
##    sleep "$iter_pause" 
done
# END: FIFO Requests section

# All done with test-run. Small PAUSE to view systemd-notify msg
##sleep 5

