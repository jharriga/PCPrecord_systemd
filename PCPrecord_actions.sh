#!/bin/bash
# Executed by systemd service 'PCPrecord.service'
# See: /etc/systemd/system/PCPrecord.service
################################################################

# GLOBALS ###################
# Include the PCP Functions file
source $PWD/pcp_functions.inc

FIFO="/tmp/pcpFIFO"                 # get from cmdline
sample_rate=5                       # hardcode DEFAULT for now
test_name="sbcpu"                   # get from FIFO - Start action
pmlogger_running="false"            # Initialize service as OFF
conf_file="$PWD/${test_name}.cfg"   # get from FIFO - Start action
archive_name="$test_name"
archive_dir="$PWD/archive.$(date +%Y%m%d%H%M%S)"   # Where to put this?
om_workload_file="/tmp/openmetrics_workload.txt"

#############################
# Functions #################
update_om_workload() {
# Removes existing and Writes a new <openmetrics_workload> file
# Called by 'reset_om_metrics()', below
   
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

    # Prepare for an update to the $om_workload_file (GLOBAL)
    rm -f $om_workload_file
    touch $om_workload_file
    # Update metrics in the openmetric.workload file
    printf "iteration %d\n" "$v_iter_cnt">>$om_workload_file
    printf "running %d\n" "$v_started">>$om_workload_file
    printf "numthreads %d\n" "$v_numthreads">>$om_workload_file
    echo "runtime ${v_runtime}">>$om_workload_file
    echo "throughput ${v_throughput}">>$om_workload_file
    echo "latency ${v_latency}">>$om_workload_file
}

reset_om_metrics() {
    # Initialize openmetric.workload metric values
    r_iteration=0 ; r_running=0
    r_numthreads=0 ; r_runtime="NaN" ; r_throughput="NaN" ; r_latency="NaN"

    # Update the openmetrics.workload 
    update_om_workload "$r_iteration" "$r_running" \
           "$r_numthreads" "$r_runtime" "$r_throughput" "$r_latency"
}

error_exit() {
    if [ "$?" != "0" ]; then
        systemd-notify --status="ERROR: $1"
        # Additional error handling logic can be added here
        rm -f "$FIFO"
        # Reset openmetric.workload metric values prior to leaving
        reset_om_metrics
## if pmlogger_running = True then attempt forcible STOP?
        exit 1
    fi
}
# END Functions #################

# Main #################
# Initialize openmetric.workload metric values
reset_om_metrics

# Verify required files and Packages are available
#----------------------------------
test -f "${conf_file}"
error_exit "Initialization: ${conf_file} not found!"

test -f "${om_workload_file}"
error_exit "Initialization: ${om_workload_file} not found!"

# Remove and recreate FIFO on every service 'start'
rm -f "$FIFO"
mkfifo "$FIFO"
error_exit "Initialization: mkfifo $FIFO failed"

# Infinite Loop  #################
# Read FIFO and perform requested ACTION (start, stop, ...)
# Access each word in $action string for parsing 'actions' & 'metric'
# NOTE: 'Start, Stop, Reset' actions have no metrics
while : ; do
    # Required or we get TIMEOUT on 'read action < "$FIFO" '
    # Signal readiness for next $action. SYNC point w/client Workload
    systemd-notify --ready --status="READY: awaiting request on $FIFO"
    # Read the Request/'$action' and then process it
    read action < "$FIFO"       # Blocks until data is available
    # Signal Processing this $action
    systemd-notify --status="$action PMLOGGER Request"
    action_arr=($action)        # Array of 'words' in Request read from FIFO
    case "${action_arr[0]}" in
        Start)   # conf_file="${action_arr[1]}" archive_name=$2
            # Start PMLOGGER to create ARCHIVE
            if [ "$pmlogger_running" = "false" ]; then
                # Signal Processing this $action
##                systemd-notify --status="$action PMLOGGER Request"
                # These functions attempt to catch errors and verify success
                pcp_verify $conf_file
                error_exit "pcp_verify: Unable to start PMLOGGER"
                pcp_start $conf_file $sample_rate $archive_dir $archive_name
                error_exit "pcp_start: Unable to start PMLOGGER"
                pmlogger_running="true"       # Record this STATE info
#DEBUG           systemd-notify --ready --status="Started PMLOGGER"
#DEBUG      else
#DEBUG           systemd-notify --ready --status="PMLOGGER already running"
            fi
            ;;
        Stop)      # artifacts_dir="${action_arr[1]}"
            # Terminate PMLOGGER 
            if [ "$pmlogger_running" = "true" ]; then
                # Will ZATHRAS Store PCP Archive related artifacts ?
                #  - Currently Missing from PCPSTOP logic
                ##pcp_stop "${artifacts_dir}"
                pcp_stop
                error_exit "pcp_stop: Unable to stop PMLOGGER"
                pmlogger_running="false"
                # Clever way to advise client of $pcp_archive_dir
                echo "${archive_dir}" >>"${om_workload_file}"
                ##reset_om_metrics
            fi
            ;;
        Reset)   # om_workload_file="${action_arr[1]}"
            # RESET the Workload Metrics
            # the only Request that doesn't require $pmlogger_running
##                systemd-notify --status="$action PMLOGGER Request"
            ##reset_om_metrics "${om_workload_file}"
            reset_om_metrics
            error_exit "reset_om_metrics: Unable to RESET Workload Metrics"
            ;;
        throughput|latency|numthreads|runtime)      # Workload Metrics
            # metric="${action_arr[1]}"  om_workload_file=$2
            if [ "$pmlogger_running" = "true" ]; then
                # Forward workload metric to openmetrics_workload.txt
##                systemd-notify --status="$action PMLOGGER Request"
                # Change only one metric line at a time
                # Replaces the entire line using sed
                # Should I only print 'action_arr[0] & action_arr[1]'
                sed -i "s/^.*${action_arr[0]}.*$/${action}/" "$om_workload_file"
#DEBUG          systemd-notify --ready --status="Forwarded Workload METRIC"
#DEBUG      else
#DEBUG          systemd-notify --ready --status="Workload METRIC: PMLOGGER N/A"
            fi
            ;;
        running|iteration)                          # Workload States
            # state="${action_arr[1]}"  om_workload_file=$2
            if [ "$pmlogger_running" = "true" ]; then
##                systemd-notify --status="$action PMLOGGER Request"
                sed -i "s/^.*${action_arr[0]}.*$/${action}/" "$om_workload_file"
#DEBUG          systemd-notify --ready --status="Forwarded Workload STATE"
#DEBUG      else
#DEBUG          systemd-notify --ready --status="Workload STATE: PMLOGGER N/A"
            fi
            ;;
        *)
            systemd-notify --status="Unrecognized action - IGNORED"
            ;;
    esac
done

# Cleanup
echo "Cleaning up"

# Reset openmetric.workload metric values prior to leaving
reset_om_metrics

