#!/bin/bash

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/chart-wrapper.sh
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


CHART_DIR=`dirname $0`

case "`uname -m`" in
    "x86_64")
	VERSION="64bit"
	;;
    "i386"|"i686")
	VERSION="32bit"
	;;
    *)
	echo "ERROR: You are running on a CPU architecture that is incompatible with this program"
	exit 1
	;;
esac

export PERL5LIB="${CHART_DIR}/chart-lib.${VERSION}"

exec ${CHART_DIR}/chart.pl "$@"
