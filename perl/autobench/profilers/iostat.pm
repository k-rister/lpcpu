
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/profilers/iostat.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# Perl module for routines related to the Iostat profiler.

package autobench::profilers::iostat;

use strict;
use warnings;

use autobench::chart;
use autobench::log;
use autobench::file;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT   = qw( &get_disk_utilization 
			&get_disk_throughput );
}

sub get_iostat_plot_dir($; $)
{
	my $results_dir = shift;
	my $run_number = shift || "001";

	my $iostat_dir = "$results_dir/analysis/iostat-processed.0.$run_number/plot-files";
	if (! -d $iostat_dir) {
		$iostat_dir = "$results_dir/analysis/iostat-processed.$run_number/plot-files";
		if (! -d $iostat_dir) {
			warning("Cannot find iostat-processed directory for results in $results_dir.");
			$iostat_dir = "";
		}
	}

	return $iostat_dir;
}

# translate_device_name
#
# If a device is an LVM volume or device-mapper device, it's device name as
# found in /dev may not be the same as the name used by iostat, which comes
# from /sys/block. Use the dmsetup info collected during the run to try to
# translate the LVM-style name into a sysfs-style name.
sub translate_device_name($ $; $)
{
	my $device = shift;
	my $results_dir = shift;
	my $run_number = shift || "001";
	my $new_device = $device;

	# Remove "/dev/" from the front of the device name.
	$new_device =~ s|^/dev/||;

	# If the device name is "/dev/mapper/<name>", use the
	# last portion of the name.
	if ($new_device =~ /^mapper\/(\S+)/) {
		$new_device = $1;

	# If the device name is "/dev/group/volume", concatenate the middle
	# and last parts of the name.
	} elsif ($new_device =~ /^([^\/]+)\/(\S+)/) {
		$new_device = "$1-$2";
	}

	# Look for the name in the dmsetup_ls file.
	my $dmsetup_ls_file = "$results_dir/config/dmsetup_ls.after.$run_number";
	if (! -f $dmsetup_ls_file) {
		warning("Cannot find file $dmsetup_ls_file needed to translate device name $device.");
		return "";
	}

	my ($line) = grep_file($new_device, $dmsetup_ls_file);
	if (!defined($line) || $line !~ /^$new_device\s+\((\d)+,\s*(\d+)\)/) {
		warning("Cannot find device '$new_device' in $dmsetup_ls_file.");
		return "";
	}

	return "dm-$2";
}

# get_disk_utilization
#
# Arg1: Name of device to get utilization for, with or without "/dev/".
# Arg2: Autobench results directory.
# Arg3: (Optional) Run-number. Default = 001.
#
# Returns: Average disk utilization percentage, or -1 if no data was found.
sub get_disk_utilization($ $; $)
{
	my $device = shift;
	my $results_dir = shift;
	my $run_number = shift || "001";

	# Remove "/dev/" from the front of the device name.
	$device =~ s|^/dev/||;

	my $iostat_dir = get_iostat_plot_dir($results_dir, $run_number);
	if (!$iostat_dir) {
		return -1;
	}

	if (! -f "$iostat_dir/$device.util.plot") {
		# If the device is an LVM volume or device-mapper device, we
		#  may have to "translate" the name to find it in iostat.
		my $new_device = translate_device_name($device, $results_dir, $run_number);
		if (! -f "$iostat_dir/$new_device.util.plot") {
			warning("Cannot find iostat utilization plot-file for device '$device'",
				$new_device ? " or device $new_device" : "",
				" in $iostat_dir.");
			return -1;
		}

		$device = $new_device;
	}

	return plot_file_average("$iostat_dir/$device.util.plot");
}

# get_disk_throughput
#
# Arg1: Name of device to get throughput for, with or without "/dev/".
# Arg2: Autobench results directory.
# Arg3: (Optional) Run-number. Default = 001.
#
# Returns: An array of two values containing the read and write throughput in
#          kB/sec, or (-1, -1) if no data was found.
sub get_disk_throughput($ $; $)
{
	my $device = shift;
	my $results_dir = shift;
	my $run_number = shift || "001";

	# Remove "/dev/" from the front of the device name.
	$device =~ s|^/dev/||;

	my $iostat_dir = get_iostat_plot_dir($results_dir, $run_number);
	if (!$iostat_dir) {
		return (-1, -1);
	}

	if (! -f "$iostat_dir/$device.rkb.plot" ||
	    ! -f "$iostat_dir/$device.wkb.plot") {
		# If the device is an LVM volume or device-mapper device, we
		#  may have to "translate" the name to find it in iostat.
		my $new_device = translate_device_name($device, $results_dir, $run_number);
		if (! -f "$iostat_dir/$new_device.rkb.plot" ||
		    ! -f "$iostat_dir/$new_device.wkb.plot") {
			error("Cannot find iostat throughput plot-files for device $device or device $new_device in $iostat_dir.");
			return (-1, -1);
		}

		$device = $new_device;
	}

	my $read_throughput = plot_file_average("$iostat_dir/$device.rkb.plot");
	my $write_throughput = plot_file_average("$iostat_dir/$device.wkb.plot");

	return ($read_throughput, $write_throughput);
}

END { }

1;
