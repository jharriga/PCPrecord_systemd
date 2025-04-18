#!/bin/bash

FIFO="/tmp/FIFO"
metrics_file="/tmp/metrics_file.txt"

# BEGIN Functions ######################
update_metrics_file() {
    # Removes existing and Writes a new $metrics_file
    # Check for proper number of args
    if [ "$#" -ne 6 ]; then
        echo "ERROR on number of parameters in ${FUNCNAME}"
        exit 2
    else
        v_iter_cnt=$1
        v_running=$2
        v_numthreads=$3
        v_runtime=$4
        v_throughput=$5
        v_latency=$6
    fi

    # Prepare for an update to the $metrics_file (GLOBAL)
    rm -f $metrics_file
    touch $metrics_file
    # Update metrics in the file
    printf "iteration %d\n" "$v_iter_cnt">>$metrics_file
    printf "running %d\n" "$v_started">>$metrics_file
    printf "numthreads %d\n" "$v_numthreads">>$metrics_file
    echo "runtime ${v_runtime}">>$metrics_file
    echo "throughput ${v_throughput}">>$metrics_file
    echo "latency ${v_latency}">>$metrics_file
}

reset_metrics() {
    # Initialize metric values
    r_iteration=0 ; r_running=0
    r_numthreads=0 ; r_runtime="NaN" ; r_throughput="NaN" ; r_latency="NaN"
    # Update the openmetrics.workload
    update_metrics_file "$r_iteration" "$r_running" \
           "$r_numthreads" "$r_runtime" "$r_throughput" "$r_latency"
}

error_exit() {
    if [ "$?" != "0" ]; then
        systemd-notify --status="ERROR: $1"
        # Additional error handling logic can be added here
        rm -f "$FIFO"
        # Reset metric values prior to leaving
        reset_metrics
        exit 1
    fi
}
# END Functions ######################

# DEBUG - measure w/interval timer and report via systemd-notify
if ! test -f "${metrics_file}"; then
    systemd-notify --status="${metrics_file}' not found!"
    reset_metrics
    error_exit "reset_metrics: Unable to RESET Workload Metrics"
fi

rm -f "$FIFO"
mkfifo "$FIFO"
error_exit "Initialization: Unable to MKFIFO ${FIFO}"

# Infinite Loop  #################
# Read FIFO and perform requested ACTION (Reset, Metric <value>, ...)
while : ; do
    systemd-notify --ready --status="READY: awaiting request on $FIFO"
    read action < "$FIFO"
##    systemd-notify --status="Processing $action"    # DEBUG
    action_arr=($action)          # Array of 'words' read from FIFO
    case "${action_arr[0]}" in
        Reset)
            # RESET the Workload Metrics
            systemd-notify --status="$action PMLOGGER Request"
            # These functions need to catch errors and verify success
            reset_metrics
            error_exit "reset_metrics: Unable to RESET Workload Metrics"
            ;;
        throughput|latency|numthreads|runtime)      # Workload Metrics
            systemd-notify --status="$action Request"
            sed -i "s/^.*${action_arr[0]}.*$/${action}/" "$metrics_file"
            ;;
        running|iteration)                          # Workload States
            systemd-notify --status="$action Request"
            sed -i "s/^.*${action_arr[0]}.*$/${action}/" "$metrics_file"
            ;;
        *)
            systemd-notify --status="$action Unrecognized Request"
##            sleep 5         # DEBUG
            ;;
    esac
done

