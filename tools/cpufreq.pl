#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/cpufreq.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


use Data::Dumper;

use strict;
use warnings;

my $sysfs_dir = "/sys/devices/system/cpu";

if (opendir(SYSFS, $sysfs_dir)) {
    my %cpus;

    while (my $cpu = readdir(SYSFS)) {
	if (-d $sysfs_dir . "/" . $cpu && $cpu =~ /^cpu/) {
	    process_dir($sysfs_dir . "/" . $cpu . "/cpufreq", $cpu, \%cpus);
	}
    }

    $Data::Dumper::Sortkeys = \&sort_filter;
    print Dumper \%cpus;

    closedir(SYSFS);
}

exit;

sub read_file {
    my $filename = shift;

    if (open(FILE, "<", $filename)) {
	my $input = <FILE>;
	chomp($input);
	close(FILE);
	return $input;
    } else {
	return "Failed to open $filename";
    }
}

sub sort_filter {
    my ($hash) = @_;

    foreach my $key (keys %{$hash}) {
	if ($key =~ /^cpu/) {
	    # assume we are at the top level of the hash (the cpus)
	    return [ (sort { substr($a, 3) <=> substr($b, 3) } keys %{$hash}) ];
	} else {
	    # assume we are at the lower level of the hash (cpufreq properties)
	    return [ (sort keys %{$hash}) ];
	}
    }

    return [];
}

sub process_dir {
    my ($dir, $hash_key, $hash) = @_;

    if (opendir(my $dh, $dir)) {

	$hash->{$hash_key} = {};

	while (my $dir_entry = readdir($dh)) {
	    if ($dir_entry eq "." || $dir_entry eq "..") {
		next;
	    }

	    if (-d $dir . "/" . $dir_entry) {
		process_dir($dir . "/" . $dir_entry, $dir_entry, \%{$hash->{$hash_key}});

		next;
	    }

	    $hash->{$hash_key}{$dir_entry} = read_file($dir . "/" . $dir_entry);
	}

	closedir($dh);
    }
}
