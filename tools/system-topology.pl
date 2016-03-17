#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/system-topology.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# this is a Perl implementation of the system topology script

use autobench::topology;
use autobench::numbers;
use Getopt::Long;

use strict;
use warnings;

my %options;

# get the cli options and store them for parsing
Getopt::Long::Configure ("bundling");
Getopt::Long::Configure ("no_auto_abbrev");
GetOptions(\%options, 'debug', 'dump=s', 'load=s');

my $tmp1;
my $tmp2;
my $topology;

if (exists $options{'load'}) {
    if (-f $options{'load'}) {
	print "Loading topology data from $options{'load'}\n\n";
	$topology = new autobench::topology(undef, $options{'load'});
    } else {
	print STDERR "ERROR: The file to load must exist!\n";
	exit 1;
    }
} else {
    $topology = new autobench::topology;
}

if (! $topology) {
    print STDERR "ERROR: Could not initialize topology information!\n";
    exit 1;
}

if ($options{'debug'}) {
    print STDERR "Please uncomment the 3 lines after this print statement to enable debug output\n";
    #use Data::Dumper;
    #$Data::Dumper::Sortkeys = 1;
    #print Dumper $topology;
    exit;
} elsif ($options{'dump'}) {
    $topology->dump($options{'dump'});
}

my $online_processor_count = $topology->get_online_processor_count;
my $offline_processor_count = $topology->get_offline_processor_count;

my @online_processor_list = $topology->get_online_processor_list;
my @offline_processor_list = $topology->get_offline_processor_list;

$tmp1 = 0;
if (@online_processor_list) {
    $tmp1 = length($online_processor_list[@online_processor_list - 1]);
}

$tmp2 = 0;
if (@offline_processor_list) {
    $tmp2 = length($offline_processor_list[@offline_processor_list - 1]);
}

my $processor_length = max($tmp1, $tmp2);

printf("%-45s%s\n", "Number of Online Processors:", $online_processor_count);
printf("%-45s%s\n", "Number of Offline Processors:", $offline_processor_count);

printf("%-45s", "List of Online Processors:");
foreach my $element (@online_processor_list) {
    printf("%0" . $processor_length . "d ", $element);
}
print "\n";

printf("%-45s", "List of Offline Processors:");
foreach my $element (@offline_processor_list) {
    printf("%0" . $processor_length . "d ", $element);
}
print "\n";

if ($topology->check_numa_support) {
    print "\nThe system is NUMA aware\n\n";

    my $node_count = $topology->get_numa_node_count;
    my @node_list = $topology->get_numa_node_list;
    my $total_memory = $topology->get_numa_total_memory;

    printf("%-45s%s\n", "Number of NUMA nodes:", $node_count);

    printf("%-45s", "List of NUMA nodes:");
    foreach my $node (@node_list) {
	print "$node ";
    }
    print "\n";

    printf("%-45s%d %s\n", "Total Memory:", ($total_memory / 1024), "MB");

    print "\nPer Node Information:\n";
    foreach my $node (@node_list) {
	print "\tNode $node\n";

	my $node_online_processor_count = $topology->get_numa_node_online_processor_count($node);
	my $node_offline_processor_count = $topology->get_numa_node_offline_processor_count($node);

	my @node_online_processor_list = $topology->get_numa_node_online_processors($node);
	my @node_offline_processor_list = $topology->get_numa_node_offline_processors($node);

	printf("\t\t%-29s%s\n", "Online Processor Count:", $node_online_processor_count);
	printf("\t\t%-29s%s\n", "Offline Processor Count:", $node_offline_processor_count);

	printf("\t\t%-29s", "Online Processor List:");
	foreach my $online_node_processor (@node_online_processor_list) {
	    printf("%0" . $processor_length . "d ", $online_node_processor);
	}
	print "\n";

	printf("\t\t%-29s", "Offline Processor List:");
	foreach my $offline_node_processor (@node_offline_processor_list) {
	    printf("%0" . $processor_length . "d ", $offline_node_processor);
	}
	print "\n";

	my $node_memory = $topology->get_numa_node_memory($node);

	printf("\t\t%-29s%d %s\n", "Memory Size:", ($node_memory / 1024), "MB");

	printf("\t\t%-29s", "Distance:");
	foreach my $tmp_node (sort { $a <=> $b} (@node_list)) {
	    printf("Node %d:%d  ", $tmp_node, $topology->get_numa_distance($node, $tmp_node));
	}
	printf("\n");
    }
} else {
    print "\nThe system is not NUMA aware\n\n";
}

print "\nSystem Processor Topology\n\n";

my $socket_count = $topology->get_socket_count;
my $core_count = $topology->get_core_count;

my $threading_status = $topology->get_hardware_threading_status;
if ($threading_status) {
    $threading_status = "yes";
} else {
    $threading_status = "no";
}

my %socket_thread_list = $topology->get_socket_thread_list;
my %core_thread_list = $topology->get_core_thread_list;
my @book_list = $topology->get_book_list;
my %book_socket_thread_list = $topology->get_book_socket_thread_list;

printf("%-45s%s\n", "Processor sockets:", $socket_count);
printf("%-45s%s\n", "Processor cores:", $core_count);
printf("%-45s%s\n", "Hardware Threading Enabled:", $threading_status);
if (@book_list) {
    printf("%-45s%d\n", "Processor Books:", scalar(@book_list));
}

print "\nPer Socket Information (these are logical sockets, not physical sockets)\n";
foreach my $socket_key (sort { $a <=> $b } (keys %socket_thread_list)) {
    print "\tSocket\n";

    printf("\t\t%-29s", "Threads:");

    foreach my $thread (sort @{$socket_thread_list{$socket_key}}) {
	printf("%0" . $processor_length . "d ", $thread);
    }
    print "\n";
}

if (@book_list) {
    print "\nBook Topology Information\n";

    foreach my $book_key (sort { $a <=> $b } (keys %book_socket_thread_list)) {
	print "\tBook\n";

	foreach my $socket_key (sort { $a <=> $b } (keys %{$book_socket_thread_list{$book_key}})) {
	    print "\t\tSocket\n";

	    printf("\t\t\t%-21s", "Threads:");

	    foreach my $thread (sort @{$book_socket_thread_list{$book_key}{$socket_key}}) {
		printf("%0" . $processor_length . "d ", $thread);
	    }
	    print "\n";
	}
    }
}

print "\nPer Core Information\n";

foreach my $core_key (sort { $a <=> $b } (keys %core_thread_list)) {
    print "\tCore $core_key\n";

    printf("\t\t%-29s", "Threads:");

    foreach my $thread (@{$core_thread_list{$core_key}}) {
	printf("%0" . $processor_length . "d ", $thread);
    }
    print "\n";
}

if ($topology->check_sysfs_topology_support) {
    print "\nPer Core Sibling Information:\n";

    foreach my $cpu (@online_processor_list) {
	print "\tCPU $cpu\n";

	my $core_level_siblings = $topology->get_core_level_sibling_count($cpu);
	my $thread_level_siblings = $topology->get_thread_level_sibling_count($cpu);

	printf("\t\t%-29s%s\n", "Core Level Siblings:", $core_level_siblings);
	printf("\t\t%-29s%s\n", "Thread Level Siblings:", $thread_level_siblings);
    }
} else {
    print "\nSysfs topology information not present\n";
}

if ($topology->check_sysfs_cache_support) {
    print "\nCache Level Information:\n";

    my @cache_levels = $topology->get_cache_levels;
    my $level;

    foreach $level (@cache_levels) {
	print "\tCache Level: $level\n";

	my @cache_types = $topology->get_cache_level_types($level);

	foreach my $type (@cache_types) {
	    my $size = $topology->get_cache_level_type_size($level, $type);

	    printf("\t\t%-29s%s [%s]\n", "Cache Type [size]:", $type, $size);
	}
    }

    print "\nThreads that share a given cache level:\n";

    foreach $level (@cache_levels) {
	print "\tCache Level: $level\n";

	my %cache_share_sets = $topology->get_shared_cache_list($level);

	$tmp1 = 0;
	foreach my $share_set (sort { $a <=> $b } (keys %cache_share_sets)) {
	    printf("\t\t\t%-29s", "Share Set $tmp1:");

	    foreach my $set_member (sort { $a <=> $b } (@{$cache_share_sets{$share_set}})) {
		printf("%0" . $processor_length . "d ", $set_member);
	    }
	    print "\n";

	    $tmp1++;
	}
    }
} else {
    print "\nSysfs cache information not present\n";
}
