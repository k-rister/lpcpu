#!/bin/bash

#
# LPCPU (Linux Performance Customer Profiler Utility): ./lpcpu.sh
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# Linux Performance Customer Profiler Utility (LPCPU)
#
# the overridable options can be specified like:
#   lpcpu.sh profilers="vmstat iostat" duration=60
#
# Copyright (c) IBM Corporation, 2014.  All rights reserved.

VERSION_STRING="bf56a943302a7055bf5be6f296d81fd85c29579f 2016-03-02 17:19:03 -0600"

## overridable values (with defaults) ##############################################################
# 
# We recommend you override these values on the command line, not by modifying the script
#


################################################
#
# The common parameters to override. 
#

# List of profilers to use.
# oprofile: see README for additional options
# perf: See README for additional options
# The following are the default profilers to use
profilers="sar iostat mpstat vmstat top meminfo interrupts"

# list of profilers to add in addition to the defaults
extra_profilers=""

# Duration of the profiler run, in seconds.
duration=120

# A command to run, if this is specified then the command is run and profiled from start
# to finish instead of profiling for the length of $duration
cmd=""

# where to create the output data (a compressed tar ball)
output_dir="/tmp"

# optional directory name to use in the output_dir, otherwise defaults to LPCPU naming scheme
dir_name=""

# Duration between profiler samples (does not apply to some profilers)
interval=5

# Files to include in summary.html
link_files=""

# should the resulting data be packaged into a compress tarball or left alone.  valid values are "yes" or "no"
package_results="yes"

################################################
# 
# oprofile and perf specific parameters

# Use callgraph on oprofile or perf
callgraph="no"

# use oprofile separate feature
oprofile_separate="yes"

# which flags to pass to oprofile separate
oprofile_separate_flags="lib,kernel"

# specific PID for oprofile to focus on
oprofile_pid=""

# if you absolutely positively cannot find the Linux kernel rpms
# we will of course ask for this later
# oprofile_kernel=--no-vmlinux
oprofile_kernel=""

# specify specific hardware counters to oprofile
# the counters should be specified in the same form as opcontrol accepts them
# for example: oprofile_hw_counters="-e <counter name>:<count>"
#          or: oprofile_hw_counters="-e <counter 1 name>:<count> -e <counter 2 name>:<count>"
ARCH=`uname -m`
if [ "$ARCH" == "ppc64" ]; then
     # http://www.ibm.com/developerworks/opensource/library/l-evaluatelinuxonpower
     # the recommended default override
     oprofile_hw_counters="-e PM_RUN_CYC_GRP1:500000"
     #
     # for normal cycles
     # oprofile_hw_counters="-e PM_CYC_GRP1:1000000"
     #
     # for cycles per instruction
     # oprofile_hw_counters="-e PM_CYC_GRP1:1000000 -e PM_INST_CMPL_GRP1:1000000"
     #
     # for cycles per instruction based on run_cycles
     # oprofile_hw_counters="-e PM_RUN_CYC_GRP1:500000 -e PM_RUN_INST_CMPL_GRP1:500000"
else
     oprofile_hw_counters=""
fi

# control the frequency at which perf samples are collected
perf_frequency=""

# default to all cpus
perf_cpu=""

################################################
# 
# unique special case parameters

# MySQL Account info
MYSQL_USER=""
MYSQL_PASSWORD=""

# data collection flags, used to provide functionality with Autobench postprocessing scripts
id="default"

# no reason to modify this unless you know what you are doing
RUN_NUMBER="001"

# debugfs mount reference count
DEBUGFS_USERS=0
DEBUGFS_UNMOUNT=0

## argument import loop ############################################################################
# This loop takes the command line input variable (CLI) and sets the bash script variables
startup_output_log=""
for arg; do
    export "$arg"
    startup_output_log="${startup_output_log}Importing CLI variable : $arg\n"
done

## post argument important fixes ###################################################################
profilers="$profilers $extra_profilers"

## fixup configuration conflicts ###################################################################
# pmu conflicts with perf, oprofile, and cmd
if [[ " $profilers " =~ " pmu " && ( " $profilers " =~ " perf " || " $profilers " =~ " oprofile " || "$cmd" != "" ) ]]; then
   echo "ERROR: profiler \"pmu\" conflicts with \"perf\", \"oprofile\", and \"cmd\"."
   exit 1
fi
# pmu needs to run at least 120 sec or longer
if [[ " $profilers " =~ " pmu " && ( " $duration " -lt " 120 " ) ]]; then
   echo "ERROR: profiler \"pmu\" requires a duration of at least 120 seconds."
   exit 1
fi

if [ -n "$oprofile_pid" ]; then
    startup_output_log="${startup_output_log}\nUsing oprofile_pid=$oprofile_pid [`sed -e 's/\x0/ /g' /proc/$oprofile_pid/cmdline`]\n"
    startup_output_log="${startup_output_log}Profiling a specific PID using Oprofile requires --separate=thread => fixing\n"
    export "oprofile_separate=yes"
    export "oprofile_separate_flags=thread"
fi

## non-overridable defined values ##################################################################

# Location to store output data.
NAME=$(hostname -s)
TODAY=$(date +"%F_%H%M")
if [ -z "${dir_name}" ]; then
    LOGDIR_NAME=lpcpu_data.$NAME.$id.$TODAY
else
    LOGDIR_NAME=${dir_name}
fi
LOGDIR=$output_dir/$LOGDIR_NAME
mkdir -p $LOGDIR

## utility functions ###############################################################################

function debugfs_mount() {
	# checking and mounting debugfs and enabling trace
	DEBUGFS=$(awk '($3 == "debugfs") {print $2}' < /proc/mounts)
	if [ -z "$DEBUGFS" ]; then
		DEBUGFS=/sys/kernel/debug
		mount -t debugfs debugfs $DEBUGFS >${LOGDIR}/lpcpu.out 2>&1 && DEBUGFS_UNMOUNT=1
	fi
	DEBUGFS_USERS=$((DEBUGFS_USERS+1))
}

function debugfs_unmount() {
	DEBUGFS_USERS=$((DEBUGFS_USERS-1))
	if [ "$DEBUGFS_UNMOUNT" -eq 1 -a "$DEBUGFS_USERS" -eq 0 ]; then
	    umount "$DEBUGFS"
	    DEBUGFS_UNMOUNT=0
	fi
}

## mysql ###########################################################################################
function setup_mysql() {
    echo "Setting up MySQL."

    if [ -z "$(which mysql)" ]; then
	echo "ERROR: MySQL is not installed."
	exit 1
    fi

    if [ -z "$MYSQL_USER" ]; then
	echo "ERROR: Please specify the account to connect to MySQL with by running 'export MYSQL_USER=<username>'"
	exit 1
    fi

    mkdir $LOGDIR/mysql-profiler.$id.$RUN_NUMBER

    if ! mysql -u $MYSQL_USER ${MYSQL_PASSWORD:+"--password=$MYSQL_PASSWORD"} -e "show global variables" > $LOGDIR/mysql-profiler.$id.$RUN_NUMBER/variables; then
	echo "ERROR: Unable to retrieve MySQL global variables.  Is a password required for $MYSQL_USER to connect?"
	echo "ERROR: Please specify the password to connect to MySQL with by running 'export MYSQL_PASSWORD=<password>'"
	exit 1
    fi
}

function mysql_profiler() {
    local mysql_profile_counter=0

    trap "echo 'mysql_profiler : Received quit signal'; exit" SIGINT SIGTERM

    while [ 1 ]; do
        local pre=`printf "%06d" $mysql_profile_counter`

        mysql -u $MYSQL_USER ${MYSQL_PASSWORD:+"--password=$MYSQL_PASSWORD"} -e "show global status;" \
            > $LOGDIR/mysql-profiler.$id.$RUN_NUMBER/status.$pre

        sleep $interval
        (( mysql_profile_counter += $interval ))
    done
}

function start_mysql() {
    echo "Starting MySQL."
    mysql_profiler &
    MYSQL_PROFILER_PID=$!
    disown $MYSQL_PROFILER_PID
}

function stop_mysql() {
    echo "Stopping MySQL."
    kill $MYSQL_PROFILER_PID
}

function report_mysql() {
    echo "Postprocessing MySQL."
}

function setup_postprocess_mysql() {
    echo '${LPCPUDIR}/postprocess/postprocess-mysql.pl .'" $id.$RUN_NUMBER"
}

## oprofile ########################################################################################
function setup_oprofile() {
	echo "Setting up oprofile."

	if [ -z "$(which opcontrol)" ]; then
		echo "ERROR: Oprofile is not installed."
                ## Add check here for Advance toolchain.
		exit 1
	fi

	if [ -z "$oprofile_kernel" ]; then

		KERNEL="$(uname -r)"
		if [ -f "/boot/vmlinux-${KERNEL}" ]; then
			VMLINUX="--vmlinux=/boot/vmlinux-${KERNEL}"
		elif [ -f "/boot/vmlinux-${KERNEL}.gz" ]; then
			# This gunzip step is classically what is done on the SLES distros
			gunzip -c "/boot/vmlinux-${KERNEL}.gz" > "/tmp/vmlinux-${KERNEL}"
			VMLINUX="--vmlinux=/tmp/vmlinux-${KERNEL}"
	        elif [ -f "/usr/lib/debug/lib/modules/${KERNEL}/vmlinux" ]; then
        	        VMLINUX="--vmlinux=/usr/lib/debug/lib/modules/${KERNEL}/vmlinux"
	        else
        	        echo "ERROR: Cannot find the vmlinux file for the running kernel (${KERNEL})."
                	if [ -f "/etc/redhat-release" ]; then
                        	echo "       On RedHat, you should find and install the kernel-debuginfo*.rpm files"
	                        echo "       These RPM files are typically on the optional DVD for your hardware platform."
        	        elif [ -f "/etc/SuSE-release" ]; then
                	        echo "       On SLES, this should have been caught in the gunzip step."
	                else
        	                echo "       This script expects the symbol enabled vmlinux kernel to be available"
                	fi
	                echo "       Please do not modify the script to bypass this checking."

			exit 1
		fi
	else
		VMLINUX=$oprofile_kernel
	fi

	opcontrol --deinit
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		# The nmi watchdog uses some resources that oprofile needs
		echo 0 >/proc/sys/kernel/nmi_watchdog
	fi
	modprobe oprofile

	opcontrol --shutdown
	rm -rf /var/lib/oprofile/samples/current
	rm -f /var/lib/oprofile/samples/oprofiled.log
	rm -f ~/.oprofile/daemonrc

	opcontrol $VMLINUX $oprofile_hw_counters

	if [ "$oprofile_separate" == "yes" ]; then
	    opcontrol --separate=$oprofile_separate_flags
	fi

        if [ "$callgraph" == "yes" ]; then
            opcontrol --callgraph=10
	else
	    opcontrol --callgraph=0
        fi
	opcontrol --init
	opcontrol --status
}

function start_oprofile() {
	echo "starting oprofile."$id"" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
        opcontrol --start && opcontrol --reset
}

function stop_oprofile() {
	echo "Stopping oprofile."
        opcontrol --dump
	opcontrol --stop
}

function report_oprofile() {
	echo "Processing oprofile data."
	mkdir $LOGDIR/oprofile.breakout.$id.$RUN_NUMBER

	if [ "$oprofile_separate_flag" == "thread" -o -n "$oprofile_pid" ]; then
	    opreport --merge tgid > $LOGDIR/oprofile-brief.$id.$RUN_NUMBER 2>&1

	    if [ -n "$oprofile_pid" ]; then
		opreport tgid:$oprofile_pid > $LOGDIR/oprofile-brief.pid.$oprofile_pid.$id.$RUN_NUMBER 2>&1
	    fi
	else
	    opreport > $LOGDIR/oprofile-brief.$id.$RUN_NUMBER 2>&1
	fi

	OPRPT_PATH="/lib/modules/$(uname -r)/kernel"

        if [ -d /lib/modules/$(uname -r)/extra ]; then
            OPRPT_PATH="${OPRPT_PATH},/lib/modules/$(uname -r)/extra"
	fi

        if [ -d /lib/modules/$(uname -r)/updates ]; then
            OPRPT_PATH="${OPRPT_PATH},/lib/modules/$(uname -r)/updates"
        fi

        if [ -d /lib/modules/$(uname -r)/weak-updates ]; then
            OPRPT_PATH="${OPRPT_PATH},/lib/modules/$(uname -r)/weak-updates"
        fi

	if [ "$oprofile_separate_flag" == "thread" -o -n "$oprofile_pid" ]; then
	    opreport --merge tgid -l -p $OPRPT_PATH > $LOGDIR/oprofile.$id.$RUN_NUMBER 2>&1

	    if [ -n"$oprofile_pid" ]; then
		opreport tgid:$oprofile_pid -l -p $OPRPT_PATH > $LOGDIR/oprofile.pid.$oprofile_pid.$id.$RUN_NUMBER 2>&1
	    fi
	else
	    opreport -l -p $OPRPT_PATH > $LOGDIR/oprofile.$id.$RUN_NUMBER 2>&1
	fi

        if [ "$callgraph" == "yes" ]; then
            opreport --callgraph -l -p $OPRPT_PATH > $LOGDIR/oprofile-callgraph.$id.$RUN_NUMBER 2>&1
        fi

	opcontrol --shutdown

	opcontrol --version > $LOGDIR/oprofile.breakout.$id.$RUN_NUMBER/oprofiled-log 2>&1
	cat /var/lib/oprofile/samples/oprofiled.log >> $LOGDIR/oprofile.breakout.$id.$RUN_NUMBER/oprofiled-log 2>&1
}

function setup_postprocess_oprofile() {
    echo '${LPCPUDIR}/postprocess/postprocess-oprofile .'" $id.$RUN_NUMBER"
}

## sar #############################################################################################
function setup_sar() {
	echo "Setting up sar."
	SAR=$(which sar)
	if [ -z "$SAR" ]; then
		echo "ERROR: sar is not installed.  To correct this problem install the sysstat package for your distribution."
		exit 1
	fi
}

function start_sar() {
      echo "starting sar."$id" ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
      sar -o $LOGDIR/sar.bin.$id.$RUN_NUMBER $interval 100000 > $LOGDIR/sar.STDOUT 2> $LOGDIR/sar.STDERR &
      SAR_PID=$!
      disown $SAR_PID
}

function stop_sar() {
	echo "Stopping sar."
	kill $SAR_PID
}

function printsar() {
        # Note: Not all of the requested reporting options are available across
        #       all versions of sar on the various distros and platforms.
        # Some permutations may return errors.   That's ok.
	sar -$1 -f "$LOGDIR/sar.bin.$id.$RUN_NUMBER"  > "$LOGDIR/sar.breakout.$id.$RUN_NUMBER/sar.$2" 2> "$LOGDIR/sar.breakout.$id.$RUN_NUMBER/sar.$2.STDERR"
}

function report_sar() {
	echo "Processing sar data."
	mkdir $LOGDIR/sar.breakout.$id.$RUN_NUMBER

	sar -A -f $LOGDIR/sar.bin.$id.$RUN_NUMBER > $LOGDIR/sar.text.$id.$RUN_NUMBER

	printsar b io_transfer_rate
	printsar c process_creation
	printsar w process_creation-context_switching
	printsar d block_devices
	printsar q run_queue_loadavg
	printsar r memory
	printsar u cpu_util
	printsar v fs_tables
	printsar w context_switching
	printsar y tty_device
	printsar B paging_stats
	printsar R memory_rates
	printsar W swapping
	printsar "I SUM" irq_sum

	# Some versions of sar have "FULL" as a value for the -n option,
	# others use "ALL".  Rather than doing tedious version checking
	# to figure out which value should be used, just do both and send
	# the error output to /dev/null.  One will fail; the other will work.
	printsar "n FULL" netdev 2>/dev/null
	printsar "n ALL" netdev 2>/dev/null

	if grep -q "processor\s[0-9]" /proc/cpuinfo; then
	    # this works on s390
	    ONLINE_PROCS=$(grep "^processor" /proc/cpuinfo | awk '{ print $2 }' | awk -F: '{ print $1 }')
	else
	    # this works on x86 and PPC
	    ONLINE_PROCS=$(grep "^processor" /proc/cpuinfo | awk '{ print $3 }')
	fi

	if [ -n "${ONLINE_PROCS}" ]; then
	    for ivar in ${ONLINE_PROCS}; do
		printsar "P ${ivar}" cpu_util_${ivar}
	    done
	else
	    NR_CPUS=`cat /proc/cpuinfo | grep -c ^processor`
	    for ((ivar=0;ivar<NR_CPUS;ivar++)); do
		printsar "P ${ivar}" cpu_util_${ivar}
	    done
	fi
}

function setup_postprocess_sar() {
    echo '${LPCPUDIR}/postprocess/postprocess-sar .'" $RUN_NUMBER $id"
}

## iostat ##########################################################################################
function setup_iostat() {
	echo "Setting up iostat."
	IOSTAT=$(which iostat)
	if [ -z "$IOSTAT" ]; then
		echo "ERROR: iostat is not installed.  To correct this problem install the sysstat package for your distribution."
		exit 1
	fi
}

function start_iostat() {
	echo "starting iostat."$id" ["$interval"] [mode=disks]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	iostat -x -k -t $interval > $LOGDIR/iostat.$id.$RUN_NUMBER &
	IOSTAT_PID=$!
	disown $IOSTAT_PID
}

function stop_iostat() {
	echo "Stopping iostat."
	kill $IOSTAT_PID
}

function report_iostat() {
	echo "Processing iostat data."
}

function setup_postprocess_iostat() {
    echo -n '${LPCPUDIR}/postprocess/postprocess-iostat --dir=.'" --run-number=$RUN_NUMBER --id=$id"
    if [ -e "${LPCPUDIR}/tools/block-device-hierarchy.pl" ]; then
	echo -n " --bdh=block-device-hierarchy.dat"
    fi
    echo
}

## proc-interrupts ##########################################################################################
function setup_interrupts() {
	echo "Setting up proc-interrupts."
	if [ ! -e "${LPCPUDIR}/tools/proc-interrupts.pl" ]; then
	    echo "ERROR: proc-interrupts.pl is not available.  To correct this problem ensure that you have the entire LPCPU distribution or disable the interrupts profiler."
	    exit 1
	fi
}

function start_interrupts() {
	echo "starting proc-interrupts."$id" ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	${LPCPUDIR}/tools/proc-interrupts.pl $interval > $LOGDIR/proc-interrupts.$id.$RUN_NUMBER &
	INTERRUPTS_PID=$!
	disown $INTERRUPTS_PID
}

function stop_interrupts() {
	echo "Stopping interrupts."
	kill $INTERRUPTS_PID
}

function report_interrupts() {
	echo "Processing interrupts data."
}

function setup_postprocess_interrupts() {
    echo 'if [ -f ./system-topology.dump ]; then'
    echo '${LPCPUDIR}/postprocess/postprocess-proc-interrupts .'" $RUN_NUMBER $id ./system-topology.dump"
    echo 'else'
    echo 'PROC_INTERRUPTS_NO_NUMA=1 ${LPCPUDIR}/postprocess/postprocess-proc-interrupts .'" $RUN_NUMBER $id"
    echo 'fi'
}

## KVM ###############################################################################################
function setup_kvm() {
	echo "Setting up KVM host profilers."

	if [ ! -e "${LPCPUDIR}/tools/proc-cpu" -o ! -e "${LPCPUDIR}/tools/kvm-stat" -o ! -e "${LPCPUDIR}/tools/ksm.pl" ]; then
	    echo "ERROR: One the KVM related profilers requires a script that is not available.  To correct this problem ensure that you have the entire LPCPU distribution or disable the KVM profiler."
	    exit 1
	fi

	debugfs_mount

	if [ -n "`which virsh`" ]; then
	    echo "  Capturing Libvirt XML for running guests"
	    mkdir ${LOGDIR}/libvirt-xml
	    for guest in `virsh list | grep running | awk '{ print $2 }'`; do
		virsh dumpxml ${guest} > ${LOGDIR}/libvirt-xml/${guest}.xml
	    done
	fi
}

function start_kvm() {
	echo "Starting KVM host profilers"
	echo "starting process-cpu.KVM-guests ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	${LPCPUDIR}/tools/proc-cpu -d $interval -r -i --qemu-guest-mode > $LOGDIR/process-cpu.KVM-guests.$RUN_NUMBER &
	PROC_CPU_PID=$!
	disown $PROC_CPU_PID
	echo "starting kvmstat."$id" ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	${LPCPUDIR}/tools/kvm-stat log=yes timestamps=yes interval=${interval} >> $LOGDIR/kvmstat.$id.$RUN_NUMBER &
	KVM_STAT_PID=$!
	disown $KVM_STAT_PID
	echo "starting ksm."$id" ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	${LPCPUDIR}/tools/ksm.pl $interval > $LOGDIR/ksm.$id.$RUN_NUMBER &
	KSM_PID=$!
	disown $KSM_PID
}

function stop_kvm() {
	echo "Stopping KVM host profilers."
	kill $PROC_CPU_PID
	kill $KVM_STAT_PID
	kill $KSM_PID

	debugfs_unmount
}

function report_kvm() {
	echo "Processing KVM host profiler data."
}

function setup_postprocess_kvm() {
    echo '${LPCPUDIR}/postprocess/postprocess-process-cpu .'" $RUN_NUMBER KVM-guests"
    echo '${LPCPUDIR}/postprocess/postprocess-kvmstat .'" $RUN_NUMBER $id"
    echo '${LPCPUDIR}/postprocess/postprocess-ksm .'" $RUN_NUMBER $id"
}

## meminfo  ##########################################################################################
function setup_meminfo() {
        echo "Setting up meminfo."
}

function start_meminfo() {
        echo "starting meminfo."$id" ["$interval"] " | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	MEMINFO_WATCH_OUTPUT_FILE=$LOGDIR/meminfo-watch.$id.$RUN_NUMBER
        while [ 1 ]; do
	        echo "============================= SAMPLE =============================" >> ${MEMINFO_WATCH_OUTPUT_FILE}
        	date >> ${MEMINFO_WATCH_OUTPUT_FILE}
	        echo >> ${MEMINFO_WATCH_OUTPUT_FILE}
        	cat /proc/meminfo >> ${MEMINFO_WATCH_OUTPUT_FILE}
	        for i in `ls -1d /sys/devices/system/node/node* 2>/dev/null`; do
        	        echo "--" >> ${MEMINFO_WATCH_OUTPUT_FILE}
	                cat $i/meminfo >> ${MEMINFO_WATCH_OUTPUT_FILE}
	        done
	        echo >> ${MEMINFO_WATCH_OUTPUT_FILE}
        	sleep $interval
	done &
        MEMINFO_PID=$!
	disown $MEMINFO_PID
}

function stop_meminfo() {
        echo "Stopping meminfo."
        kill $MEMINFO_PID
}

function report_meminfo() {
        echo "Processing meminfo data."
}

function setup_postprocess_meminfo() {
    echo '${LPCPUDIR}/postprocess/postprocess-meminfo-watch .'" $RUN_NUMBER $id"
}

## vmstat ##########################################################################################
function setup_vmstat() {
	echo "Setting up vmstat."
	VMSTAT=$(which vmstat)
	if [ -z "$VMSTAT" ]; then
		echo "ERROR: vmstat is not installed."
		exit 1
	fi
}

function start_vmstat() {
	echo "starting vmstat."$id" ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	vmstat $interval | ${LPCPUDIR}/tools/output-timestamp.pl > $LOGDIR/vmstat.$id.$RUN_NUMBER &
	VMSTAT_PID=$!
	disown $VMSTAT_PID
}

function stop_vmstat() {
	echo "Stopping vmstat."
	kill $VMSTAT_PID
}

function report_vmstat() {
	echo "Processing vmstat data."
}

function setup_postprocess_vmstat() {
	echo '${LPCPUDIR}/postprocess/postprocess-vmstat .'" $RUN_NUMBER $id"
}

## top #############################################################################################
function setup_top() {
	echo "Setting up top."
	TOP=$(which top)
	if [ -z "$TOP" ]; then
		echo "ERROR: top is not installed."
		exit 1
	fi
}

function start_top() {
	echo "Starting top."
	top -b -d $interval -H > $LOGDIR/top.$id.$RUN_NUMBER &
	TOP_PID=$!
	disown $TOP_PID
}

function stop_top() {
	echo "Stopping top."
	kill $TOP_PID
}

function report_top() {
	echo "Processing top data."
}

function setup_postprocess_top() {
    link_files="top.$id.$RUN_NUMBER $link_files"
    echo
}

## mpstat ##########################################################################################
function setup_mpstat() {
	echo "Setting up mpstat."
	MPSTAT=$(which mpstat)
	if [ -z "$MPSTAT" ]; then
		echo "ERROR: mpstat is not installed.  To correct this problem install the sysstat package for your distribution."
		exit 1
	fi
	if mpstat --help 2>&1 | grep -q "\[ -P { <cpu>.*ON.* ALL } \]"; then
	    MPSTAT_PROCESSOR_SELECTION="ON"
	else
	    MPSTAT_PROCESSOR_SELECTION="ALL"
	fi
}

function start_mpstat() {
	echo "starting mpstat.$id ["$interval"]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	mpstat -P ${MPSTAT_PROCESSOR_SELECTION} $interval > $LOGDIR/mpstat.$id.$RUN_NUMBER &
	MPSTAT_PID=$!
	disown $MPSTAT_PID
}

function stop_mpstat() {
	echo "Stopping mpstat."
	kill $MPSTAT_PID
}

function report_mpstat() {
	echo "Processing mpstat data."
}

function setup_postprocess_mpstat() {
	echo 'if [ -f ./system-topology.dump ]; then'
	echo '${LPCPUDIR}/postprocess/postprocess-mpstat . '" $RUN_NUMBER $id ./system-topology.dump"
	echo 'else'
	echo 'MPSTAT_NO_NUMA=1 ${LPCPUDIR}/postprocess/postprocess-mpstat .'" $RUN_NUMBER $id"
	echo 'fi'
}

## perf       ##########################################################################################
function setup_perf() {
	echo "Setting up perf."
	PERF=$(which perf)
	if [ -z "$PERF" ]; then
        	echo "ERROR: perf is not installed."
	        exit 1
	fi
		echo $profilers | grep oprofile > /dev/null
	if [  $? == 0 ]; then
		echo "ERROR: perf and oprofile can not run at same time."
        	exit 1
    	fi

}

function start_perf() {
	local perf_cmd

	echo "starting perf" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
        perf_cpu_arg="-a"
        if [ -n "$perf_cpu" ]; then
	        perf_cpu_arg="--cpu=$perf_cpu"
        fi
        perf_cmd="perf record $perf_cpu_arg -o $LOGDIR/perf_data.$RUN_NUMBER"
	if [ "$callgraph" = "yes" ]; then
		perf_cmd="$perf_cmd -g"
		echo "perf using callgraph" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	fi
	if [ -n "$perf_frequency" ]; then
		perf_cmd="$perf_cmd -F $perf_frequency"
		echo "perf using user specified frequency of [$perf_frequency]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	fi
	echo "using perf command [$perf_cmd]" | tee -a $LOGDIR/profile-log.$RUN_NUMBER
	$perf_cmd &
    	PERF_PID=$!
	disown $PERF_PID
}

function stop_perf() {
    	echo "Stopping perf."
    	kill -SIGINT $PERF_PID
}

function report_perf() {
    	echo "Processing perf data."
    	if [ "$callgraph" = "yes" ]; then
		perf report -n -g flat,100 -i $LOGDIR/perf_data.$RUN_NUMBER > $LOGDIR/perf_report.$RUN_NUMBER
		perf report -n -g -i $LOGDIR/perf_data.$RUN_NUMBER > $LOGDIR/perf_report-callgraph.$RUN_NUMBER
	else
		perf report -n -i $LOGDIR/perf_data.$RUN_NUMBER > $LOGDIR/perf_report.$RUN_NUMBER
	fi
}

function setup_postprocess_perf() {
        echo "mkdir perf-processed.$RUN_NUMBER"
        echo "pushd perf-processed.$RUN_NUMBER > /dev/null"
        echo "echo \"<html><head><title>Perf files for $RUN_NUMBER</title></head><body>\" > chart.html"
        echo "counter=1"
        echo "for file in \`find ../perf_report*.$RUN_NUMBER -maxdepth 0 -type f\`; do"
        echo "    echo \"\$counter : <a href='\$file'>\" >> chart.html"
        echo "    echo \$file | sed -e 's|../||' >> chart.html"
        echo "    echo \"</a><br/>\" >> chart.html"
        echo "    (( counter += 1 ))"
        echo "done"
        echo "echo \"</body></html>\" >> chart.html"
        echo "popd > /dev/null"
}

## tcpdump ##########################################################################################

function setup_tcpdump() {
	echo "Setting up tcpdump."
}

function start_tcpdump() {
	echo "Starting tcpdump."
	tcpdump -s256 -c500000  -B130000 -w $LOGDIR/tcpdump.pcap -nnvvi any &
	TCPDUMP_PID=$!
	disown $TCPDUMP_PID
}

function stop_tcpdump() {
	echo "Stopping tcpdump."
	kill -9 $TCPDUMP_PID
}

function report_tcpdump() {
	echo "processing tcpdump."
}

function setup_postprocess_tcpdump() {
	echo "Postprocessing tcpdump."
	tcpdump -r "$LOGDIR"/tcpdump.pcap > "$LOGDIR"/tcpdump.STDOUT 2>"$LOGDIR"/tcpdump.STDERR
}

## ftrace ##########################################################################################

function setup_ftrace() {
	echo "Setting up ftrace."
	debugfs_mount
	> "$DEBUGFS"/tracing/trace # zero out trace buffer
	#end of trace enabling
}

function start_ftrace() {
	echo "Starting ftrace."
	DEFAULT_BUFFER_SIZE=$(awk '{print $1}' < $DEBUGFS/tracing/buffer_size_kb)
	echo 1 > $DEBUGFS/tracing/events/enable #enable all trace events
	echo 256000 > $DEBUGFS/tracing/buffer_size_kb
	echo 1 > $DEBUGFS/tracing/tracing_on #turn on tracing
}

function stop_ftrace() {
	echo "Stopping ftrace."
	#clean up after tracing
	echo 0 > $DEBUGFS/tracing/tracing_on #turn off tracing
	echo 0 > $DEBUGFS/tracing/events/enable #disable all trace events
}

function report_ftrace() {
	echo "processing ftrace."
	cat $DEBUGFS/tracing/trace >> $LOGDIR/ftrace.out
	> $DEBUGFS/tracing/trace # zero out trace buffer
	echo $DEFAULT_BUFFER_SIZE > $DEBUGFS/tracing/buffer_size_kb
	debugfs_unmount
}

function setup_postprocess_ftrace() {
	echo "Postprocessing ftrace."
}

## pmu ##########################################################################################

function setup_pmu() {
	echo "Setting up pmu."
 	cmd="${LPCPUDIR}/tools/pmcount.sh ${duration} ${pmusets} > $LOGDIR/pmu.out 2>&1"
}

function start_pmu() {
	echo "Starting pmu."
	# pmu collection will be run as the lpcpu "cmd"
}

function stop_pmu() {
	echo "Stopping pmu."
}

function report_pmu() {
	echo "processing pmu."
}

function setup_postprocess_pmu() {
	echo "Postprocessing pmu."
}

## Generic Functions ###############################################################################

# in normal SIGINT handling just log the signal and exit
function sigint_normal_trap() {
    echo -e "\n\nCaught SIGINT --> exiting\n"
    exit 1
}

# when the profilers are running and a SIGINT is received we log the
# SIGNAL but continue running to allow the profilers to be cleanly
# shutdown
# NOTE: This means that when profilers are running and a SIGINT is
# received the script continues to run
function sigint_running_trap() {
    echo -e "\n\nCaught SIGINT --> stopping data collection\n"
}

####################################################################################################

# main block, used to log all output
{
    trap sigint_normal_trap SIGINT

    echo "Running Linux Performance Customer Profiler Utility version $VERSION_STRING"
    echo "$VERSION_STRING" > $LOGDIR/lpcpu.version

    LPCPUDIR=`dirname $0`

    # dump the startup output log, doing it here so that is recorded
    echo -e "$startup_output_log"

    echo "Starting Time: `date`"

    # Setup all profilers.
    for prof in $profilers; do
	setup_$prof
    done

    cat /proc/net/netstat > $LOGDIR/netstat.before
    netstat -in > $LOGDIR/netstat-in.before 2>&1
    netstat -v > $LOGDIR/netstat-v.before 2>&1
    netstat -s > $LOGDIR/netstat-s.before 2>&1
    cat /proc/interrupts > $LOGDIR/interrupts.before
    cat /proc/meminfo > $LOGDIR/meminfo.before
    mkdir $LOGDIR/numa-node.before
    cp -a /sys/devices/system/node/* $LOGDIR/numa-node.before 2> $LOGDIR/numa-node.before/cp.STDERR
    df -a > $LOGDIR/df.before
    ip -s link > $LOGDIR/ip-statistics.before
    ifconfig -a > $LOGDIR/ifconfig.before
    cat /proc/net/snmp > $LOGDIR/snmp.before

    trap sigint_running_trap SIGINT

    # Start all profilers.
    echo "Profilers start at: `date`"
    for prof in $profilers; do
	start_$prof
    done

    if [ -n "$cmd" ]; then
	echo "Executing '$cmd'"
	eval $cmd &
	MAIN_WAIT_PID=$!
    else
	echo "Waiting for $duration seconds."
	sleep $duration &
	MAIN_WAIT_PID=$!
    fi
    # by waiting on the PID we get proper signal delivery to the
    # script which is necessary for the SIGINT handler to function
    # properly, if a signal (SIGINT) is received the wait will exit
    # prematurely
    wait ${MAIN_WAIT_PID}
    WAIT_RET_VAL=$?

    # if the wait returned a non-zero value it may be because it was short-circuited by a SIGINT
    # if so, kill the PID we were waiting on because it will still be running, just in case
    if [ ${WAIT_RET_VAL} != 0 ]; then
	kill ${MAIN_WAIT_PID} > /dev/null 2>&1
    fi

    # Stop all profilers.
    for prof in $profilers; do
	stop_$prof
    done
    echo "Profilers stop at: `date`"

    trap sigint_normal_trap SIGINT

    cat /proc/net/netstat > $LOGDIR/netstat.after
    netstat -in > $LOGDIR/netstat-in.after 2>&1
    netstat -v > $LOGDIR/netstat-v.after 2>&1
    netstat -s > $LOGDIR/netstat-s.after 2>&1
    cat /proc/interrupts > $LOGDIR/interrupts.after
    cat /proc/meminfo > $LOGDIR/meminfo.after
    mkdir $LOGDIR/numa-node.after
    cp -a /sys/devices/system/node/* $LOGDIR/numa-node.after 2> $LOGDIR/numa-node.after/cp.STDERR
    df -a > $LOGDIR/df.after
    ip -s link > $LOGDIR/ip-statistics.after
    ifconfig -a > $LOGDIR/ifconfig.after
    cat /proc/net/snmp > $LOGDIR/snmp.after

    # Collect data for all profilers.
    for prof in $profilers; do
	report_$prof
    done

    # setup postprocessing script
    echo "Setting up postprocess.sh"
    echo '#!/bin/bash' > $LOGDIR/postprocess.sh
    echo 'DIR=`dirname $0`' >> $LOGDIR/postprocess.sh
    echo 'LPCPUDIR=$1' >> $LOGDIR/postprocess.sh
    echo 'CHART_TYPE=$2' >> $LOGDIR/postprocess.sh
    echo 'if [ -z "${LPCPUDIR}" ]; then echo "ERROR: You must specify where the LPCPU package is installed"; exit 1; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -n "${CHART_TYPE}" -a "${CHART_TYPE}" == "chart.pl" ]; then echo "Forcing the use of chart.pl instead of jschart"; export FORCE_CHART_PL=1; fi' >> $LOGDIR/postprocess.sh
    echo 'LPCPUDIR=`readlink -e ${LPCPUDIR}`' >> $LOGDIR/postprocess.sh
    echo 'ARCH=`uname -m | sed -e "s/i.86/i386/"`' >> $LOGDIR/postprocess.sh
    echo 'CHART_DIRECTOR=""' >> $LOGDIR/postprocess.sh
    echo 'if [ "${FORCE_CHART_PL}" == "1" ]; then if [ "${ARCH}" == "i386" ]; then CHART_DIRECTOR="${LPCPUDIR}/tools/chart-lib.32bit"; elif [ "${ARCH}" == "x86_64" ]; then CHART_DIRECTOR="${LPCPUDIR}/tools/chart-lib.64bit"; else echo "Forcing usage of chart.pl requires a 32bit or 64bit x86 platform"; fi; fi' >> $LOGDIR/postprocess.sh
    echo 'export PERL5LIB=${LPCPUDIR}/perl' >> $LOGDIR/postprocess.sh
    echo 'if [ ! -e "${LPCPUDIR}/tools/jschart.pm/d3.min.js" -o ! -e "${LPCPUDIR}/tools/jschart.pm/queue.min.js" ]; then export FORCE_JSCHART_REMOTE_LIBRARY=1; fi' >> $LOGDIR/postprocess.sh
    echo '# avoid some issues with postprocessing scripts requiring large number of file handles, only works if postprocess.sh is executed as root' >> $LOGDIR/postprocess.sh
    echo 'ulimit -n 500000' >> $LOGDIR/postprocess.sh
    echo 'pushd $DIR > /dev/null' >> $LOGDIR/postprocess.sh
    echo "# make sure all chart.sh scripts are deleted in case we are doing a repostprocess with a different chart implementation than before" >> $LOGDIR/postprocess.sh
    echo 'find . -name chart.sh -execdir rm "{}" \;' >> $LOGDIR/postprocess.sh
    for prof in $profilers; do
	echo >> $LOGDIR/postprocess.sh
	setup_postprocess_$prof >> $LOGDIR/postprocess.sh
    done
    echo >> $LOGDIR/postprocess.sh
    echo "link_files=\"${link_files}\"" >> $LOGDIR/postprocess.sh
    echo '# make sure summary.html is deleted in case we are doing a repostprocess' >> $LOGDIR/postprocess.sh
    echo 'rm summary.html > /dev/null 2>&1' >> $LOGDIR/postprocess.sh
    echo 'if [ "${FORCE_CHART_PL}" == "1" ]; then if [ ! -z "${CHART_DIRECTOR}" ]; then ${LPCPUDIR}/tools/chart-processor.sh chart=${LPCPUDIR}/tools/chart.pl chart_lib=${CHART_DIRECTOR} link_files="${link_files}"; else echo "Skipping chart-processor.sh execution due to no valid chart.pl libraries"; fi; else ${LPCPUDIR}/tools/chart-processor.sh chart= chart_lib= link_files="${link_files}"; fi' >> $LOGDIR/postprocess.sh
    echo >> $LOGDIR/postprocess.sh
    echo 'NDIFF="${LPCPUDIR}/tools/ndiff.py"' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e interrupts.before -a -e interrupts.after ]; then ${NDIFF} interrupts.before interrupts.after > interrupts.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e netstat.before -a -e netstat.after ]; then ${NDIFF} netstat.before netstat.after > netstat.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e netstat-in.before -a -e netstat-in.after ]; then ${NDIFF} netstat-in.before netstat-in.after > netstat-in.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -e netstat-v.before -a -e netstat-v.after ]; then diff netstat-v.before netstat-v.after > netstat-v.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e netstat-s.before -a -e netstat-s.after ]; then ${NDIFF} netstat-s.before netstat-s.after > netstat-s.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e meminfo.before -a -e meminfo.after ]; then ${NDIFF} meminfo.before meminfo.after > meminfo.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e df.before -a -e df.after ]; then ${NDIFF} df.before df.after > df.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e ip-statistics.before -a -e ip-statistics.after ]; then ${NDIFF} ip-statistics.before ip-statistics.after > ip-statistics.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e ifconfig.before -a -e ifconfig.after ]; then ${NDIFF} ifconfig.before ifconfig.after > ifconfig.diff; fi' >> $LOGDIR/postprocess.sh
    echo 'if [ -x ${NDIFF} -a -e snmp.before -a -e snmp.after ]; then ${NDIFF} snmp.before snmp.after > snmp.diff; fi' >> $LOGDIR/postprocess.sh
    chmod +x $LOGDIR/postprocess.sh

    # capture data
    echo "Gathering system information"
    dmesg > $LOGDIR/dmesg.STDOUT 2> $LOGDIR/dmesg.STDERR
    dmidecode > $LOGDIR/dmidecode.STDOUT 2> $LOGDIR/dmidecode.STDERR
    sysctl -a > $LOGDIR/sysctl.STDOUT 2> $LOGDIR/sysctl.STDERR
    ulimit -a > $LOGDIR/ulimit.STDOUT 2> $LOGDIR/ulimit.STDERR
    lspci -vv > $LOGDIR/lspci.STDOUT 2> $LOGDIR/lspci.STDERR
    lspci -tv > $LOGDIR/lspci-tree.STDOUT 2> $LOGDIR/lspci-tree.STDERR
    lsscsi -t -d > $LOGDIR/lsscsi.STDOUT 2> $LOGDIR/lsscsi.STDERR
    lsblk -f -t -m > $LOGDIR/lsblk.STDOUT 2> $LOGDIR/lsblk.STDERR
    lscpu > $LOGDIR/lscpu.STDOUT 2> $LOGDIR/lscpu.STDERR
    lscpu -a -e >> $LOGDIR/lscpu.STDOUT 2>> $LOGDIR/lscpu.STDERR
    pvdisplay -v --maps > $LOGDIR/pvdisplay.STDOUT 2> $LOGDIR/pvdisplay.STDERR
    vgdisplay -v > $LOGDIR/vgdisplay.STDOUT 2> $LOGDIR/vgdisplay.STDERR
    lvdisplay -v --maps > $LOGDIR/lvdisplay.STDOUT 2> $LOGDIR/lvdisplay.STDERR
    pvscan > $LOGDIR/pvscan.STDOUT 2> $LOGDIR/pvscan.STDERR
    uname -a > $LOGDIR/uname.STDOUT 2> $LOGDIR/uname.STDERR
    lsmod > $LOGDIR/lsmod.STDOUT 2> $LOGDIR/lsmod.STDERR
    dmsetup ls > $LOGDIR/dmsetup_ls.STDOUT 2> $LOGDIR/dmsetup_ls.STDERR
    dmsetup table > $LOGDIR/dmsetup_table.STDOUT 2> $LOGDIR/dmsetup_table.STDERR
    multipath -ll > $LOGDIR/multipath.STDOUT 2> $LOGDIR/multipath.STDERR
    numactl --hardware > $LOGDIR/numactl.STDOUT 2> $LOGDIR/numactl.STDERR
    route -n -ee > $LOGDIR/route.STDOUT 2> $LOGDIR/route.STDERR
    ps -eL -o user=UID -o pid,ppid,lwp,c,nlwp,stime,sgi_p=CPU,time,cmd > $LOGDIR/ps.eLf.STDOUT 2> $LOGDIR/ps.eLf.STDERR
    ps waxf > $LOGDIR/ps.waxf.STDOUT 2> $LOGDIR/ps.waxf.STDERR
    pstree -a -A -l -n -p -u > $LOGDIR/pstree.STDOUT 2> $LOGDIR/pstree.STDERR
    ip addr > $LOGDIR/ip-addr.STDOUT 2> $LOGDIR/ip-addr.STDERR
    ip route > $LOGDIR/ip-route.STDOUT 2> $LOGDIR/ip-route.STDERR
    brctl show > $LOGDIR/brctl-show.STDOUT 2> $LOGDIR/brctl-show.STDERR
    mkdir $LOGDIR/ethtool
    for IF in /sys/class/net/*; do
	[ -e "$IF" ]      || continue
	IF=$(basename $IF)
	[ "$IF" == "lo" ] && continue
	ethtool $IF    > $LOGDIR/ethtool/ethtool-$IF.STDOUT          2> $LOGDIR/ethtool/ethtool-$IF.STDERR
	ethtool -i $IF > $LOGDIR/ethtool/ethtool-$IF-driver.STDOUT   2> $LOGDIR/ethtool/ethtool-$IF-driver.STDERR
	ethtool -k $IF > $LOGDIR/ethtool/ethtool-$IF-offload.STDOUT  2> $LOGDIR/ethtool/ethtool-$IF-offload.STDERR
	ethtool -c $IF > $LOGDIR/ethtool/ethtool-$IF-coalesce.STDOUT 2> $LOGDIR/ethtool/ethtool-$IF-coalesce.STDERR
	ethtool -l $IF > $LOGDIR/ethtool/ethtool-$IF-channel.STDOUT 2> $LOGDIR/ethtool/ethtool-$IF-channel.STDERR
	ethtool -g $IF > $LOGDIR/ethtool/ethtool-$IF-ring.STDOUT 2> $LOGDIR/ethtool/ethtool-$IF-ring.STDERR
	ethtool -S $IF > $LOGDIR/ethtool/ethtool-$IF-stats.STDOUT 2> $LOGDIR/ethtool/ethtool-$IF-stats.STDERR
	ethtool -a $IF > $LOGDIR/ethtool/ethtool-$IF-pause.STDOUT 2> $LOGDIR/ethtool/ethtool-$IF-pause.STDERR
    done
    if which rpm &> /dev/null; then
	rpm -qa | sort > $LOGDIR/rpm-qa.STDOUT 2> $LOGDIR/rpm-qa.STDERR
    fi
    if which dpkg-query &> /dev/null; then
	dpkg-query --list > $LOGDIR/dpkg-query.STDOUT 2> $LOGDIR/dpkg-query.STDERR
    fi

    # for some reason the +fg flag fails on some system, even though the man
    # page documentation implies that it should work.  if it does fail, just
    # run lsof without any flags so that we get some data
    if ! lsof +fg > $LOGDIR/lsof.fg.STDOUT 2> $LOGDIR/lsof.fg.STDERR; then
	lsof > $LOGDIR/lsof.STDOUT 2> $LOGDIR/lsof.STDERR
    fi

    if which btrfs &> /dev/null; then
	btrfs filesystem show > $LOGDIR/btrfs.show.STDOUT 2> $LOGDIR/btrfs.show.STDERR
	for btrfs_mount in `grep btrfs /proc/mounts | awk '{ print $2 }'`; do
            btrfs_cmd="btrfs filesystem df ${btrfs_mount}"
            echo "${btrfs_cmd}:" >> $LOGDIR/btrfs.df.STDOUT
            echo "${btrfs_cmd}:" >> $LOGDIR/btrfs.df.STDERR
            ${btrfs_cmd} >> $LOGDIR/btrfs.df.STDOUT 2>> $LOGDIR/btrfs.df.STDERR
            echo >> $LOGDIR/btrfs.df.STDOUT
            echo >> $LOGDIR/btrfs.df.STDERR
	done
    fi

    cat /proc/swaps > $LOGDIR/swaps
    if [ -e /proc/sys/vm/zone_reclaim_mode ]; then
	cat /proc/sys/vm/zone_reclaim_mode > $LOGDIR/zone_reclaim_mode
    fi
    cat /proc/sys/vm/swappiness > $LOGDIR/swappiness
    cat /proc/version > $LOGDIR/version
    cat /proc/cmdline > $LOGDIR/cmdline
    cat /proc/partitions > $LOGDIR/partitions
    cat /proc/cpuinfo > $LOGDIR/cpuinfo
    if [ -e /var/log/messages ]; then
	cp -a /var/log/messages $LOGDIR
	chmod +r $LOGDIR/messages
    fi
    if [ -e /var/log/syslog ]; then
	cp -a /var/log/syslog $LOGDIR
	chmod +r $LOGDIR/syslog
    fi
    cat /proc/mounts > $LOGDIR/mounts
    cat /proc/net/softnet_stat > $LOGDIR/softnet_stat
    cp -a /etc/sysctl.conf $LOGDIR/sysctl.conf
    cp -a $0 $LOGDIR

    if [ -e /etc/redhat-release ]; then
	cp -a /etc/redhat-release $LOGDIR
    fi

    if [ -e /etc/SuSE-release ]; then
	cp -a /etc/SuSE-release $LOGDIR
    fi

    ARCH=`uname -m`
    if [ "$ARCH" == "ppc64" ]; then
       if [ -e /proc/device-tree ]; then
           tar -cjf ${LOGDIR}/device_tree.tar.bz2 /proc/device-tree > $LOGDIR/device_tree.STDOUT 2> $LOGDIR/device_tree.STDERR
       fi

       if [ -e /proc/ppc64/lparcfg ]; then
          cat /proc/ppc64/lparcfg > $LOGDIR/lparcfg
       fi

       if which ppc64_cpu > /dev/null 2>&1; then
           ppc64_cpu --cores-present     >  $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --cores-on          >> $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --smt               >> $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --smt-snooze-delay  >> $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --frequency         >> $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --run-mode          >> $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --dscr              >> $LOGDIR/ppc64_cpu 2>&1
           ppc64_cpu --info              >> $LOGDIR/ppc64_cpu 2>&1
       fi
    fi

    if [ -e "${LPCPUDIR}/tools/system-topology.pl" -a -d "${LPCPUDIR}/perl" ]; then
	PERL5LIB=${LPCPUDIR}/perl ${LPCPUDIR}/tools/system-topology.pl --dump $LOGDIR/system-topology.dump > $LOGDIR/system-topology.STDOUT 2> $LOGDIR/system-topology.STDERR
    fi

    if [ -e "${LPCPUDIR}/tools/block-device-hierarchy.pl" ]; then
	${LPCPUDIR}/tools/block-device-hierarchy.pl --dump $LOGDIR/block-device-hierarchy.dat > $LOGDIR/block-device-hierarchy.STDOUT 2> $LOGDIR/block-device-hierarchy.STDERR
    fi

    if [ -e "${LPCPUDIR}/tools/block-device-properties.pl" ]; then
	${LPCPUDIR}/tools/block-device-properties.pl > $LOGDIR/block-device-properties.STDOUT 2> $LOGDIR/block-device-properties.STDERR
    fi

    if [ -e "${LPCPUDIR}/tools/cpufreq.pl" ]; then
	${LPCPUDIR}/tools/cpufreq.pl > $LOGDIR/cpufreq.STDOUT 2> $LOGDIR/cpufreq.STDERR
    fi

    if [ -e "${LPCPUDIR}/tools/lseth" ]; then
	${LPCPUDIR}/tools/lseth -v > $LOGDIR/lseth.STDOUT 2> $LOGDIR/lseth.STDERR
    fi

    if [ -e "${LPCPUDIR}/tools/adapter_disklist.sh" ]; then
	${LPCPUDIR}/tools/adapter_disklist.sh $LOGDIR 001
    fi

    if [ -e "${LPCPUDIR}/tools/irq-affinity-list.sh" ]; then
	${LPCPUDIR}/tools/irq-affinity-list.sh > $LOGDIR/irq-affinity.STDOUT 2> $LOGDIR/irq-affinity.STDERR
    fi

    if [ -e "${LPCPUDIR}/tools/jschart.pm" ]; then
	cp -a ${LPCPUDIR}/tools/jschart.pm ${LOGDIR}
    fi

    if [ -e "${LPCPUDIR}/tools/results-web-server.py" ]; then
	cp -a ${LPCPUDIR}/tools/results-web-server.py ${LOGDIR}
    fi

    echo "Finishing time: `date`"
} 2>&1 | tee -i ${LOGDIR}/lpcpu.out
# without the -i option to tee the SIGINT handlers defined above do
# not function properly since tee will exit prematurely

if [ ${PIPESTATUS[0]} == 0 ]; then
    if [ "${package_results}" == "yes" ]; then
	echo -n "Packaging data..."
	pushd $output_dir > /dev/null
	if tar cjf ${LOGDIR_NAME}.tar.bz2 $LOGDIR_NAME; then
	    echo "data collected is in ${LOGDIR}.tar.bz2"
	    rm -Rf $LOGDIR
	else
	    echo "error packaging data.  Data is in $LOGDIR"
	fi
	popd > /dev/null
    else
	echo "################################################################################"
	echo "  LPCPU has successfully completed.  Your data is available at:"
	echo ""
	echo "          ${LOGDIR}"
	echo ""
	echo "################################################################################"
    fi
else
    echo "################################################################################"
    echo "  ERROR : LPCPU encountered a critical error forcing it to exit prematurely."
    echo "          Please correct the error and run again.  Data for this run is"
    echo "          available for analysis at:"
    echo ""
    echo "          ${LOGDIR}"
    echo ""
    echo "################################################################################"
fi
