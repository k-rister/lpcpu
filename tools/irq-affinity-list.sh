#! /bin/bash

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/irq-affinity-list.sh
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# Print a list of the IRQs and their CPU pinnings.
# Print both the mask and the human readable list.
# If the OS does not provide an affinity list, build one from the mask.

ARCH=`uname -i`
if [ "${ARCH}" == "s390x" ]; then
    echo "This script does not currently support s390x architecture"
    exit 1
fi

# mask_to_cpu_list <mask>
# Given a CPU mask, generate a human readable CPU list.
# For example, a mask of 02e9 yields a CPU list of "0,3,5-7,9".
function mask_to_cpu_list {
    local MASK="${1//,/}"	# Remove commas from the mask.
    declare -i BIN_MASK		# Treat BIN_MASK as an integer so we can do
				# bit-wise math on it.
    local CPU=0
    local MATCH=0
    local DELIM=''
    local CPU_LIST=''

    while [ -n "$MASK" ]; do
	# Grab the last nybble in the mask.
	BIN_MASK=0x${MASK:-1:1}
	# Strip off the last nybble from the mask.
	# MASK=${MASK:0:-1} is cleaner, but that syntax isn't supported on
	# earlier versions of bash.
	MASK=${MASK:0:$((${#MASK}-1))}

	for (( i=0; i<4; i++ )); do
	    if (( BIN_MASK&1 )); then
		case $MATCH in
		    0)
			CPU_LIST+="$DELIM$CPU"
			DELIM=","
		    ;;
		    1)
			CPU_LIST+="-"
		    ;;
		    *)
		    ;;
		esac

		(( MATCH++ ))

	    else
		if [ $MATCH -gt 1 ]; then
		    CPU_LIST+=$(( CPU-1 ))
		fi
		MATCH=0
	    fi

	    (( BIN_MASK>>=1 ))
	    (( CPU++ ))
	done
    done

    if [ $MATCH -gt 1 ]; then
	CPU_LIST+=$(( CPU-1 ))
    fi

    echo $CPU_LIST
}

IRQ_HEADER="IRQ"
MASK_HEADER="Mask"
LIST_HEADER="List"
DESC_HEADER="Description"

# Set miminum column widths to the size of the heading.
IRQ_LEN=${#IRQ_HEADER}
MASK_LEN=${#MASK_HEADER}
LIST_LEN=${#LIST_HEADER}

COUNT=0
while read LINE; do
    if [ "${LINE/[0-9]:/}" = "$LINE" ]; then continue; fi

    IRQ=$(echo "$LINE" | sed -e 's/^ *\([0-9]\+\):.*/\1/')
    if [ ${#IRQ} -gt $IRQ_LEN ]; then
	IRQ_LEN=${#IRQ}
    fi
    DESC=$(echo "$LINE" | sed -e 's/.*edge *//' -e 's/.*fasteoi *//' -e 's/.*[Ll]evel *//g')
    MASK="$(cat /proc/irq/$IRQ/smp_affinity)"
    if [ ${#MASK} -gt $MASK_LEN ]; then
	MASK_LEN=${#MASK}
    fi

    if [ -e /proc/irq/$IRQ/smp_affinity_list ]; then
	LIST="$(cat /proc/irq/$IRQ/smp_affinity_list)"
    else
	LIST="$(mask_to_cpu_list $MASK)"
    fi
    if [ ${#LIST} -gt $LIST_LEN ]; then
	LIST_LEN=${#LIST}
    fi

    IRQS[$COUNT]="$IRQ"
    MASKS[$COUNT]="$MASK"
    LISTS[$COUNT]="$LIST"
    DESCS[$COUNT]="$DESC"

    (( COUNT++ ))

done < /proc/interrupts

FORMAT="%-${IRQ_LEN}s  %-${MASK_LEN}s  %-${LIST_LEN}s  %s\n"

printf "$FORMAT" $IRQ_HEADER $MASK_HEADER $LIST_HEADER $DESC_HEADER

for (( i=0; i<COUNT; i++ )); do
    printf "$FORMAT" "${IRQS[$i]}" "${MASKS[$i]}" "${LISTS[$i]}" "${DESCS[$i]}"
done

