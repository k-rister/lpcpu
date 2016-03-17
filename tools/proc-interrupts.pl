#! /usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/proc-interrupts.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# This script calculates the difference in the interrupt counts between two
# successive snapshots of /proc/interrupts taken at a given interval.
# The output, sent to stdout, is in the same format as /proc/interrupts
# only the numbers are replaced with the differences instead of the
# total counts.
#
# Arguments:  [interval]

use strict;
use File::Basename;

# disable output buffering
$|++;

my $interval = 5;
if (@ARGV) {
	$interval = $ARGV[0];
}

my @lines;
my @irq_data_prev;
my @irq_data_curr;

my @headers;
my $cpu_count;
my $i;
my $j;

if (!open(INPUT, "</proc/interrupts")) {
	print STDERR "ERROR: Could not open /proc/interrupts\n";
	exit 1;
}

@lines = <INPUT>;

@headers = split(" ", $lines[0]);
$cpu_count = @headers;

for ($i = 1; $i < @lines; $i++) {
	my @fields = ();
	@fields = split(" ", $lines[$i], $cpu_count + 1);
	# Parse the description out of the last field.
	# The description was purposely not parsed in the previous split
	# because we want to preserve any leading spaces before the
	# description.
	$fields[$#fields] =~ /([0-9]*)(.*)/;
	$fields[$#fields] = $1;
	push @fields, $2;
	$irq_data_prev[$i-1] = \@fields;
}

while (1) {
	sleep $interval;

	seek INPUT, 0, 0;
	@lines = <INPUT>;

	for ($i = 1; $i < @lines; $i++) {
		my @fields = ();
		@fields = split(" ", $lines[$i], $cpu_count + 1);
		# Parse the description out of the last field.
		# The description was purposely not parsed in the previous split
		# because we want to preserve any leading spaces before the
		# description.
		$fields[$#fields] =~ /([0-9]*)(.*)/;
		$fields[$#fields] = $1;
		push @fields, $2;
		$irq_data_curr[$i-1] = \@fields;
	}

	printf "%02d:%02d:%02d / %d\n", (localtime)[2], (localtime)[1], (localtime)[0], time;
	print "      ";
	for ($i = 0; $i < $cpu_count; $i++) {
		printf "%10s", $headers[$i];
	}
	print "\n";

	for ($i = 0; $i < @irq_data_prev; $i++) {
		printf "%6s", $irq_data_prev[$i][0];
		for ($j = 1; $j < $cpu_count + 1; $j++) {
			printf "%10d",  $irq_data_curr[$i][$j]- $irq_data_prev[$i][$j];
		}
		print "$irq_data_curr[$i][$cpu_count + 1]\n";
	}

	print "\n";
	@irq_data_prev = @irq_data_curr;
	@irq_data_curr = ();
}

close INPUT;

