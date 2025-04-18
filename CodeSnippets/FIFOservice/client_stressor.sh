#!/bin/bash
# CLIENT.sh            Exercises systemd-notify based service
# Monitor systemd-notify msgs with
#      $ watch -n 1 'systemctl status fifo.service'
#########################################################################
FIFO="/tmp/FIFO"
metrics_file="/tmp/metrics_file.txt"  # should this be passed into the svc?
runlog="./runlog.txt"       # existing 'sysbench cpu' results
output="output._$(date +%Y%m%d_%H%M%S).txt"
timeout_long=10             # wait-time for Start and Stop actions
timeout_short=2             # wait-time for Workload Metric actions
num_iterations=100
iter_pause=1

# BEGIN FUNCTIONS #################################################
fail_exit() {
    if [ "$?" != "0" ]; then
        echo "ERROR: $1"
        # Additional error handling logic can be added here
        exit 1
    fi
}

write_to_fifo() {
    request_str=$1

    # Is the FIFO.SVC reporting Status='READY'?
    timeout $timeout_short bash -c \
      "until systemctl status fifo.service | grep -q "READY:" \
      ; do sleep 0.1; done"
    # Trap timeout condition
    if [ $? -eq 124 ]; then
        echo "Time out occurred waiting for systemd status=READY"
        exit 2
    fi

    # Special case for "SYNC" 
    # used to SYNC with systemd svc - don't write
    if [ "${request_str}" != 'SYNC' ]; then
        printf '%s\n' "$request_str" >"$FIFO" 
    fi
}
# END FUNCTIONS #################################################

# MAIN #################################################

# Check that FIFO.SVC is running
systemctl is-active --quiet fifo.service
fail_exit "fifo.service not running"

# Check if timeout on service readiness is working
##write_to_fifo 'GARBAGE'

# Start cpu stressor in backgrd
runtime="$num_iterations"
sysbench cpu run --time="$runtime" --threads="$(nproc)" >>"$output" 2>&1 &

# BEGIN: Issue FIFO Requests repeatedly and use timer(ms)
for loopcntr in `seq 1 $num_iterations`; do
    # Start a TIMER with millisecond resolution
    read up rest </proc/uptime; start_pre="${up%.*}${up#*.}"

    # Workload start - RESET Workload Metrics for this iteration
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

    # Start TIMER for post-workload activties
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

