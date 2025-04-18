#!/bin/bash
# Collection of utility Functions for working with Perf Co-Pilot
# - pcp_verify($cfg_file)
# - pcp_start($cfg_file, $sample_rate, $archive_dir, $archive_name)
# - pcp_stop()
#
# NOTE: use of these Functions require that PCP is already installed on the system 
##################################################################################

# Global VARs
primary_pmlogger="false"          # used to manage stop/restart
pmlogger_killed="success"         # flags if private pmlogger was killed
#---------------------------------------------------------------

pcp_verify()
{
    cfg_file="$1"          # PMLOGGER Configuration File
# Verify user provided pmlogger.conf file exists. If not abort.
    if [ ! -f "$cfg_file" ]; then
        echo "File $cfg_file not found!"; echo
        exit 2
    fi

# TBD: use 'pmlogger -c $PWD/$cfg_file -C' to Verify syntax

# Verify PMCD is running (pcp-zeroconf is installed)
    pgrep pmcd > /dev/null
    if [ $? != 0 ]; then
        echo "PCP pmcd is not running. Is PCP installed?"
        echo "Suggested syntax: sudo dnf install pcp-zeroconf"; echo
        exit 2
    fi

# Manage primary pmlogger. STOP if it is running.
# Check if primary pmlogger is running
    pgrep pmlogger > /dev/null
    if [ $? == 0 ]; then
##        echo "Primary PCP pmlogger is running. It must be stopped to run script"
##        echo "Suggested syntax: sudo systemctl stop pmlogger"; echo
##        exit 2
        echo "Primary PCP pmlogger is running. Being stopped to run script"
        systemctl stop pmlogger
        # Flag indicates primary pmlogger should be restarted by 'pcp_stop'
        primary_pmlogger="true"
    fi

}

pcp_start()
{
    echo "PCP Starting private pmlogger"

    cfg_file="$1"
    sample_rate="$2"
    archive_dir="$3"
    archive_name="$4"

    mkdir -p ${archive_dir}

# Run PCP logger
# JTH - VERIFY success, ensure pmlogger starts
    pmlogger -c "${cfg_file}" -t "$sample_rate" -l "${archive_dir}/${archive_name}.log" "${archive_dir}/${archive_name}" &

# Sleep 5 seconds prior to continuing and starting workload
    sleep 5

# JTH - VERIFY success, ensure pmlogger started and remained running
    pgrep pmlogger > /dev/null
    if [ $? != 0 ]; then
        echo "FAILED to Start PCP private pmlogger. Aborting test."; echo
# Reset GPU Frequencies
##        restore_gpu_freq
        exit 2
    fi

}

pcp_stop()
{
    echo "PCP Stop. Stopping private pmlogger, creating archive"

# Stop PCP logger and pause for pmlogger to write archive
    pkill -USR1 pmlogger
    sleep 3

# JTH - VERIFY success, ensure pmlogger stops
    pid=$(pgrep pmlogger)
    if [ $? == 0 ]; then
        echo "FAILED to Stop private pmlogger. PID $pid should be manually stopped"
        echo                  # improves output readability
        pmlogger_killed="failed"
    else
        pmlogger_killed="success"
    fi


# Restore primary pmlogger, if it was previously running
    if [ "$primary_pmlogger" == "true" ]; then
        if [ "$pmlogger_killed" == "success" ]; then
            echo "Primary PCP pmlogger being restored to original run state"
            systemctl start pmlogger
        else
            echo "Primary PCP pmlogger NOT restored to original run state"
        fi
    fi
}

#-------------------------------------------------------



