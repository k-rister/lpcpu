#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/chart-processor.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# this is a helper script for chart-processor.sh
#
# this script will use the MTJP library to allow for more efficient processing of the chart.sh scripts by keeping
# the execution pipeline full instead of allowing lulls (while waiting)

use strict;

use autobench::mtjp;
use Getopt::Long;
use File::Find;
#use Data::Dumper;

# disable output buffering
$|++;

my %options;
Getopt::Long::Configure("bundling");
Getopt::Long::Configure("no_auto_abbrev");
GetOptions(\%options,
	   'threads=s',
	   'dir=s',
	   'chart=s',
	   'chart-lib=s',
    );

# validate the input options
if (! exists($options{'threads'})) {
    print STDERR "ERROR: This script must be called with '--threads <number of threads>'.  Are you sure you did not mean to call chart-processor.sh?\n";
    exit 1;
}

if (! exists($options{'dir'})) {
    print STDERR "ERROR: This script must be called with '--dir <dirname>'.  Are you sure you did not mean to call chart-processor.sh?\n";
    exit 1;
}

if (! exists($options{'chart'})) {
    print STDERR "ERROR: This script must be called with '--chart <path to chart.pl>'.  Are you sure you did not mean to call chart-processor.sh?\n";
    exit 1;
}

if (! exists($options{'chart-lib'})) {
    print STDERR "ERROR: This script must be called with '--chart-lib <path to the chart-lib>'.  Are you sure you did not mean to call chart-processor.sh?\n";
    exit 1;
}

# array of hashes to contain the jobs to process
my @scripts;

# define the callback routine that the find routine uses to handle the entries it encounters
sub wanted {
    if (($File::Find::name =~ /chart\.sh/) && ($File::Find::name !~ /~$/)) {
	push @scripts, { 'file' => $File::Find::name };
    }
}

# find the files
find ( { 'wanted' => \&wanted, 'follow' => 1 } , $options{'dir'});


# define the callback function that the job processor uses to process each job
sub mtjp_callback {
    my ($job, $log_queue) = @_;

    if ( -e $job->{'file'} && -x $job->{'file'} ) {
	my @args = ();

	push @args, ("nice", "-n", "15", $job->{'file'}, $options{'chart'}, $options{'chart-lib'});

	system(@args);
    } else {
	$log_queue->enqueue("ERROR: \"$job->{'file'}\" either does not exist or is not executable.\n");
    }
}

# if the user specified "--threads=all" we translate that to the number of scripts found
if ($options{'threads'} eq "all") {
    $options{'threads'} = @scripts;
}

# make sure a positive number of threads has been specified
if ($options{'threads'} < 1) {
    print STDERR "ERROR: You must specify jobs/threads greater than 0.\n";
    exit 1;
}

# call the job processor
mtjp(\@scripts, $options{'threads'}, \&mtjp_callback);
