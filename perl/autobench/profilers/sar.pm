
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/profilers/sar.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# Perl module for routines related to the Sar profiler.

package autobench::profilers::sar;

use strict;
use warnings;
use autobench::log;
use autobench::file;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT   = qw( &get_cpu_utilization );
}

# get_cpu_utilization
#
# Arg1: The sar.cpu_util file to read.
# Arg2: Optional - the "type" of CPU utilization to return. If not specified,
#       the non-idle utilization is calculated. Allowable values are:
#       user, system, iowait, nice, steal, idle, non-idle
#
# Returns: Desired average CPU utilization percentage, or -1 if no data was
#          found in the input file.
sub get_cpu_utilization($; $)
{
	my $filename = shift;
	my $type = shift || "non-idle";
	my %cpu_util;
	my $tmp1;
	my $tmp2;

	my @lines = read_file($filename);

	my ($cpu_util_data) = grep(/^Average:/, @lines);
	if (!$cpu_util_data) {
		error("No average CPU utilization data found in $filename.");
		return -1;
	}

	($tmp1, $tmp2,
		$cpu_util{'user'},
		$cpu_util{'nice'},
		$cpu_util{'system'},
		$cpu_util{'iowait'},
		$cpu_util{'steal'},
		$cpu_util{'idle'}) = split(/\s+/, $cpu_util_data);

	$cpu_util{'non-idle'} = 100 - $cpu_util{'idle'} - $cpu_util{'iowait'};
	if ($lines[0] !~ /ppc64/i) {
		# Non-ppc systems treat "steal" as idle time.
		$cpu_util{'non-idle'} -= $cpu_util{'steal'}
	}

	return defined($cpu_util{$type}) ? $cpu_util{$type} : $cpu_util{'non-idle'};
}

END { }

1;
