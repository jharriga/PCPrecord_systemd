#!/bin/bash
# QUICK_TEST.sh            Exercises PCPrecord systemd service
#
# Monitor systemd-notify msgs with
#      $ watch -n 1 'systemctl status PCPrecord.service'
#########################################################################
num_iterations=5
runtime=100
iter_pause=60               # pause between iteration (testruns)

#### BEGIN Client.inc
# These GLOBAL vars and FUNCTIONS could be put in 'client.inc' file
FIFO="/tmp/pcpFIFO"
runlog="/tmp/runlog.txt"
timeout_long=10             # wait-time for Start and Stop actions
timeout_short=2             # wait-time for other actions

# FUNCTIONS ###
fail_exit() {
    if [ "$?" != "0" ]; then
        echo "ERROR: $1"
        # Additional error handling logic can be added here
        exit 1
    fi
}

check_svc() {
    wait_to=$1
    # Wait for the PCPrecord.SVC to report Status='READY'
    # This appears to be CPU time heavy
    timeout "$wait_to" bash -c \
      "until systemctl status PCPrecord.service | grep -q "READY:" \
      ; do sleep 0.1; done"
    # Trap timeout condition
    if [ $? -eq 124 ]; then
        echo "Timed out waiting $wait_to sec for systemd status=READY: \
          Request=$request_str"
        exit 2
    fi
}

write_to_fifo() {
    # Writes Request to FIFO
    # Synch's with PCPrecord.svc before and after writing Request
    # NOTE: Special case for "SYNC" - skips the printf
    request_str=$1

    # Handle 'short' and 'long' timeouts
    if [ "$request_str" = 'Stop' -o "$request_str" = 'Start' ]; then
        timeout_period="$timeout_long"
    else
        timeout_period="$timeout_short"
    fi

    # Prior to sending new Request
    # Wait for the PCPrecord.SVC to report Status='READY'
    check_svc $timeout_short

    # Special case for "SYNC" - skips the printf
    # Function can be used to SYNC with systemd svc - don't printf
    if [ "${request_str}" != 'SYNC' ]; then
        # Writing to FIFO: printf '%s\n' 'command' >/path/to/namedPipe 
        printf '%s\n' "$request_str" >"$FIFO"

        # Request sent - now...
        # Wait for the PCPrecord.SVC to report Status='READY'
        # NOTE: $timeout_period varies by Request-type
        check_svc $timeout_period
##        sleep 5      # DEBUG
    fi

}

write_wl_metrics() {
    # Synch is handled in 'write_to_fifo() --> check_svc()'
    # $runlog is a GLOBAL var
    wl_throughput="$(awk '/events per second/ {printf("%.3f", $4)}' $runlog)"
    write_to_fifo "throughput ${wl_throughput}" 
    wl_latency="$(awk '/95th/ {printf("%.3f", $3)}' $runlog)"
    write_to_fifo "latency ${wl_latency}" 
    wl_runtime="$(awk '/total time/ {printf("%.3f", $3)}' $runlog)"
    write_to_fifo "runtime ${wl_runtime}" 
    wl_numthreads="$(awk '/Number of threads/ {printf("%d", $4)}' $runlog)"
    write_to_fifo "numthreads ${wl_numthreads}"
}
# END FUNCTIONS
#### END client.inc

# MAIN #################################################
# Check that PCPrecord.SVC is running
systemctl is-active --quiet PCPrecord.service
fail_exit "PCPrecord.service not running"

# Now lets create an ARCHIVE and then run a Workload
# TIMER (ms) to measure start time
read up rest </proc/uptime; prestart="${up%.*}${up#*.}"
write_to_fifo 'Start'
read up rest </proc/uptime; poststart="${up%.*}${up#*.}"
write_to_fifo 'SYNC'
# End TIMER  for 'Start' Request
read up rest </proc/uptime; postsync="${up%.*}${up#*.}"
duration_start=$(( 10*(poststart - prestart) ))
duration_sync=$(( 10*(postsync - poststart) ))
echo; echo "> STARTtimer=${duration_start}ms   SYNCtimer=${duration_sync}ms"

# BEGIN: Workload section
for loopcntr in `seq 1 $num_iterations`; do
    # Workload start - RESET Workload Metrics for this iteration
    write_to_fifo 'Reset'
    # Update Workload States
    # openmetrics.workload: iteration, running
    write_to_fifo 'running 1'
    write_to_fifo "iteration ${loopcntr}"
    write_to_fifo 'SYNC'

    echo "**PRE-Workload execution"
    cat /tmp/openmetrics_workload.txt; echo     # DEBUG
    sysbench cpu run --time="$runtime" --threads="$(nproc)">"$runlog" 2>&1

    # Workload done - update Workload State & Workload Metrics
    write_to_fifo 'running 0'
    # openmetrics.workload: throughput, latency, runtime, numthreads
    write_wl_metrics
#################################################
    write_to_fifo 'SYNC'    # IS THIS NEEDED after every FIFO Write??
                            # Should it be part of WRITE_TO_FIFO
#################################################

    # Iteration done - PAUSE
    echo "**POST-Workload execution"
    cat /tmp/openmetrics_workload.txt; echo     # DEBUG
    sleep "$iter_pause" 
done
# END: Workload section

# Signal PCPrecord service to stop PMLOGGER
# Start (ms) TIMER to measure stop time
read up rest </proc/uptime; prestop="${up%.*}${up#*.}"
write_to_fifo 'Stop'
write_to_fifo 'SYNC'
# Stop TIMER for 'Stop' and report interval
read up rest </proc/uptime; poststop="${up%.*}${up#*.}"
duration_stop=$(( 10*(poststop - prestop) ))
echo; echo "> STARTtimer=${duration_start}ms  \
      STOPtimer=${duration_stop}ms"

# Notify user of PCP-Archive location
# PCPrecord.service 'Stop' Request appends PCP-Archive dir
echo -n "PCP Archive directory: "
tail -n 1 /tmp/openmetrics_workload.txt     # Report PCParchive location
write_to_fifo 'Reset'      # Does not require PMLOGGER to be running

# All done with test-run. Small PAUSE to view systemd-notify msg
# then stop the service

