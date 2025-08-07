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

mark_ms() {
    read up rest </proc/uptime; marker="${up%.*}${up#*.}"
    echo "$marker"                 # return value
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
    local request_str=$1
##    echo "DEBUG request: $request_str"

    # Handle 'short' and 'long' timeouts
    if [[ "${request_str}" =~ ^Stop || "${request_str}" =~ ^Start* ]]; then
        timeout_period="$timeout_long"
    else
        timeout_period="$timeout_short"
    fi

    # Prior to sending new Request
    # Wait for the PCPrecord.SVC to report Status='READY'
    check_svc $timeout_short

    printf '%s\n' "${request_str}" >"$FIFO"
##    sleep 5  # DEBUG - allows Service-side time measurements

    # Request sent - now...
    # Wait for the PCPrecord.SVC to report Status='READY'
    # NOTE: $timeout_period varies by Request-type
    check_svc $timeout_period
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

PCParchive_start() {
  local archive_dir=$1
  local test_name=$2
  local pmlog_cfg=$3

  # Check that PCPrecord.SVC is running
  systemctl is-active --quiet PCPrecord.service
  fail_exit "PCPrecord.service not running"

  # Start PMLOGGER to create the ARCHIVE
  start_action="Start ${archive_dir} $test_name $pmlog_cfg"
  write_to_fifo "${start_action}"
}

PCParchive_end() {
  # Signal PCPrecord service to stop PMLOGGER
  write_to_fifo 'Stop'

  # Notify user of PCP-Archive location
  ##echo "PCP Archive directory: ${archive_dir}"

  # All done with test-run. Reset openmetric.workload metrics
  write_to_fifo 'Reset'      # Does not require PMLOGGER to be running
}

# END FUNCTIONS
#### END client.inc
