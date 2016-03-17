#!/bin/bash

#
# LPCPU (Linux Performance Customer Profiler Utility): ./download-jschart-dependencies.sh
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


DIR=`dirname $0`

URLS[0]="http://d3js.org/d3.v3.min.js"
URLS[1]="http://d3js.org/queue.v1.min.js"

FILES[0]="d3.min.js"
FILES[1]="queue.min.js"

if pushd ${DIR}/tools/jschart.pm > /dev/null; then
    if which wget > /dev/null 2>&1; then
	for ((i=0; $i<${#URLS[*]}; i++)); do
	    if ! wget -O ${FILES[$i]} ${URLS[$i]}; then
		echo "ERROR: Failed to wget from ${URLS[$i]}"
		exit 1
	    fi
	done
    elif which curl > /dev/null 2>&1; then
	for ((i=0; $i<${#URLS[*]}; i++)); do
	    if ! curl -o ${FILES[$i]} ${URLS[$i]}; then
		echo "ERROR: Failed to curl from ${URLS[$i]}"
		exit 1
	    fi
	done
    else
	echo "ERROR: You need to install wget or curl for this script to work..."
	echo "       ...or perform the above logic so other way manually."
	exit 1
    fi
else
    echo "ERROR:  Could not change to the proper directory"
    exit 1
fi
