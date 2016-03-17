#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/ksm.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


use strict;

# disable output buffering
$|++;

my $loop = -1;
use vars qw($loop);

my $interval = 5;
my $ksm_src_dir = "/sys/kernel/mm/ksm";

if (@ARGV >= 1) {
    $interval = $ARGV[0];
}

if (@ARGV == 2) {
    $ksm_src_dir = $ARGV[1];
}

my @input_files = ('full_scans',
		   'pages_shared',
		   'pages_sharing',
		   'pages_to_scan',
		   'pages_unshared',
		   'pages_volatile',
		   'run',
		   'sleep_millisecs');

my @file_handles;

if (-d $ksm_src_dir && chdir $ksm_src_dir) {
    print "Capturing data from " . $ksm_src_dir . "\n\n";

    print "date | timestamp";
    for (my $i=0; $i<@input_files; $i++) {
	print " | " . $input_files[$i];
	open($file_handles[$i], "<$input_files[$i]");
    }
    print "\n\n";

    my $value;
    my $timestamp;

    $SIG{INT} = \&my_exit;
    $SIG{TERM} = \&my_exit;

    while ($loop == -1) {
	$timestamp = time();
	print localtime($timestamp) . " | " . $timestamp;

	for (my $i=0; $i<@input_files; $i++) {
	    seek($file_handles[$i], 0, 0);
	    $value = readline($file_handles[$i]);
	    chomp($value);
	    print " | " . $value;
	}

	print "\n";

	sleep $interval;
    }

    for (my $i=0; $i<@input_files; $i++) {
	close $file_handles[$i];
    }
} else {
    print STDERR "ksm : could not locate $ksm_src_dir\n";
    exit 1;
}

sub my_exit {
    my $signal = shift;
    $loop = $signal;
}
