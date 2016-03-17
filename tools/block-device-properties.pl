#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/block-device-properties.pl
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

my $sysfs_dir = "/sys/block";

if (opendir(SYSFS, $sysfs_dir)) {
    my %devices;

    while (my $block_device = readdir(SYSFS)) {
	if ($block_device eq "." || $block_device eq "..") {
	    next;
	}

	$devices{$block_device} = {};

        if (opendir(BLOCK, $sysfs_dir . "/" . $block_device)) {
            while (my $dir_entry = readdir(BLOCK)) {
                if ($dir_entry eq "." | $dir_entry eq "..") {
                    next;
                }

                if (($dir_entry eq "cache_type") ||
                    ($dir_entry eq "size")) {
                    $devices{$block_device}{$dir_entry} = read_file($sysfs_dir . "/" . $block_device . "/" . $dir_entry);
                }
            }

            closedir(BLOCK);
        }

	if (opendir(BLOCK, $sysfs_dir . "/" . $block_device . "/queue")) {
	    while (my $dir_entry = readdir(BLOCK)) {
		if ($dir_entry eq "." || $dir_entry eq "..") {
		    next;
		}

		if (($dir_entry eq "scheduler") ||
		    ($dir_entry eq "add_random") ||
		    ($dir_entry eq "hw_sector_size") ||
		    ($dir_entry eq "nr_requests") ||
		    ($dir_entry eq "read_ahead_kb") ||
		    ($dir_entry eq "rotational") ||
		    ($dir_entry eq "minimum_io_size")) {
		    $devices{$block_device}{$dir_entry} = read_file($sysfs_dir . "/" . $block_device . "/queue/" . $dir_entry);
		}
	    }

	    closedir(BLOCK);
	}
    }

    $Data::Dumper::Sortkeys = \&sort_filter;
    print Dumper \%devices;

    closedir(SYSFS);
}

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

    return [ (sort blocksort keys %{$hash}) ];
}

# special sorting function
sub blocksort {
    # return -1 if $a < $b
    # return 0 if $a == $b
    # return 1 if $a > $b

    # first, split the two elements to be sorted on a number boundary after removing any '-' characters
    my $foo = $a;
    $foo =~ s/-//;
    my @array_a = split(/([0-9]+)/, $foo);

    $foo = $b;
    $foo =~ s/-//;
    my @array_b = split(/([0-9]+)/, $foo);

    # if the two resulting arrays are both of size 2, that means we
    # have two device names that both are of the form <a-z+><0-9>
    # ex. sda5 vs. dm-4
    # if the first array element of each array is the same, this
    # means we need to do a numeric sort based on the second
    # element
    # ex. dm-5 vs. dm-20
    if ((@array_a == 2) && (@array_b == 2) && ($array_a[0] eq $array_b[0])) {
	return $array_a[1] <=> $array_b[1];
    } else {
	# either the arrays are not of the same size or the first
	# array elements of each array do not match...assuming that if
	# the first 2 letters match, $a and $b are related
	# ex. a=sdc and b=sdba
	# we always want sdc to come before sdba ... so do a length based
	# comparison
	if (substr($array_a[0], 0, 2) eq substr($array_b[0], 0, 2)) {
	    if (length($array_a[0]) < length($array_b[0])) {
		# $a < $b
		return -1;
	    } elsif (length($array_a[0]) > length($array_b[0])) {
		# $a > $b
		return 1;
	    }
	}
    }

    # if we have fallen to this point, fall back on using a lexical comparison
    return $a cmp $b;
}
