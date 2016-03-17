
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/topology.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module that implements a system topology API

package autobench::topology;

use strict;
use warnings;
use Storable;

#use Data::Dumper;
use Cwd;

# class constructor -- accepts 1 optional argument which is the path
# to where sysfs is mounted in case of non-standard mount point
sub new {
    my $class = shift;
    my $path = shift || "/sys";
    my $load_path = shift || undef;
    my $self = {};
    $self->{DATA} = {};
    bless $self, $class;
    if (defined $load_path) {
	$self->_load($load_path);
    } elsif ($self->_initialize($path)) {
	return undef;
    }
    return $self;
}

################################################################################
#                              Private Functions Below                         #
################################################################################

# private initialization function -- accepts 1 argument which is the
# path to where sysfs is mounted
sub _initialize {
    my $self = shift;
    my $path = shift;

    my $current_directory = getcwd();

    if ($self->check_sysfs_path($path)) {
	return 1;
    }

    $self->is_numa_supported;
    $self->check_sysfs_cpu_topology_support;
    $self->check_sysfs_cpu_cache_support;

    $self->gather_cpu_info;
    $self->gather_numa_info;

    chdir $current_directory;

    return 0;
}

# private initialization function -- accepts 1 argument which is the
# path to load an archive from
sub _load {
    my $self = shift;
    my $load_path = shift;

    eval {
	$self->{DATA} = Storable::retrieve($load_path);
    };

    die "ERROR: Failed to load archive from $load_path!\n" if $@;

    die "ERROR: Loaded archive does not contain valid topology information!\n" if (! exists $self->{DATA}->{'sysfs_path'});
}

# dump the state object data for debugging or archiving purposes
sub dump {
    my $self = shift;
    my $dump_path = shift;

    eval {
	Storable::nstore($self->{DATA}, $dump_path);
    };

    die "ERROR: Failed to dump topology data to $dump_path!\n" if $@;
}

# check that the specified sysfs mount path is valid
sub check_sysfs_path {
    my $self = shift;

    $self->{DATA}->{'sysfs_path'} = shift;

    if (! -d $self->{DATA}->{'sysfs_path'}) {
	print STDERR "Invalid sysfs path [" . $self->{DATA}->{'sysfs_path'} . "]\n";
	return 1;
    }

    return 0;
}

# check if the system supports NUMA
sub is_numa_supported {
    my $self = shift;

    if (-d "$self->{DATA}->{'sysfs_path'}/devices/system/node") {
	$self->{DATA}->{'numa_enabled'} = 1;
    } else {
	$self->{DATA}->{'numa_enabled'} = 0;
    }

    return 0;
}

# check if the system supports sysfs cpu topology information
sub check_sysfs_cpu_topology_support {
    my $self = shift;

    opendir DIR, "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/";

    while (my $dir = readdir DIR) {
	if ($dir =~ /^cpu/) {
	    if (-d "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/$dir/topology") {
		closedir DIR;

		opendir CPU_DIR, "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/$dir/topology";

		my $dir_entry_count = 0;
		while (readdir CPU_DIR) {
		    $dir_entry_count++;
		}

		closedir CPU_DIR;

		if ($dir_entry_count > 2) {
		    $self->{DATA}->{'sysfs_cpu_topology_supported'} = 1;
		} else {
		    $self->{DATA}->{'sysfs_cpu_topology_supported'} = 0;
		}

		return 0;
	    }
	}
    }

    $self->{DATA}->{'sysfs_cpu_topology_supported'} = 0;

    closedir DIR;
    return 0;
}

# check if the system supports sysfs cpu cache information
sub check_sysfs_cpu_cache_support {
    my $self = shift;

    opendir DIR, "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/";

    while (my $dir = readdir DIR) {
	if ($dir =~ /^cpu/) {
	    if (-d "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/$dir/cache") {
		closedir DIR;

		opendir CPU_DIR, "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/$dir/cache";

		my $dir_entry_count = 0;
		while (readdir CPU_DIR) {
		    $dir_entry_count++;
		}

		closedir CPU_DIR;

		if ($dir_entry_count > 2) {
		    $self->{DATA}->{'sysfs_cpu_cache_supported'} = 1;
		} else {
		    $self->{DATA}->{'sysfs_cpu_cache_supported'} = 0;
		}

		return 0;
	    }
	}
    }

    $self->{DATA}->{'sysfs_cpu_cache_supported'} = 0;

    closedir DIR;
    return 0;
}

# mine the system for information about the cpus
sub gather_cpu_info {
    my $self = shift;

    chdir "$self->{DATA}->{'sysfs_path'}/devices/system/cpu/";
    opendir SYSTEM_CPU_DIR, '.';

    $self->{DATA}->{'cpu'} = {};
    $self->{DATA}->{'opteron'} = 0;
    $self->{DATA}->{'ppc'} = 0;

    # check if the system is Opteron based, can be used to make
    # assumptions if some sysfs data is missing
    open CPUINFO, "</proc/cpuinfo";
    while (<CPUINFO>) {
	if ($_ =~ /opteron/i) {
	    $self->{DATA}->{'opteron'} = 1;
	    last;
	}
    }
    close CPUINFO;

    # check if the system is PPC based, can be used to make
    # assumptions if some sysfs data is missing
    open UNAME, "uname -a|";
    while (<UNAME>) {
	if ($_ =~ /ppc/i) {
	    $self->{DATA}->{'ppc'} = 1;
	    last;
	}
    }
    close UNAME;

    while (my $cpu_dir = readdir SYSTEM_CPU_DIR) {
	if (($cpu_dir =~ /^cpu[0-9]+$/) && (-d $cpu_dir)) {
	    opendir CPU_DIR, $cpu_dir;
	    chdir $cpu_dir;

	    $cpu_dir =~ m/cpu([0-9]+)/;
	    my $cpu_number = $1;

	    $self->{DATA}->{'cpu'}->{$cpu_number} = {};

	    while (my $dir_entry = readdir CPU_DIR) {
		if ($dir_entry eq "online") {
		    open ENTRY, "<$dir_entry";
		    $self->{DATA}->{'cpu'}->{$cpu_number}->{'online_state'} = <ENTRY>;
		    chomp($self->{DATA}->{'cpu'}->{$cpu_number}->{'online_state'});
		    close ENTRY;
		    $self->{DATA}->{'cpu'}->{$cpu_number}->{'offlineable'} = 1;
		} elsif (($dir_entry eq "cache") && $self->{DATA}->{'sysfs_cpu_cache_supported'}) {
		    $self->{DATA}->{'cpu'}->{$cpu_number}->{'cache'} = {};

		    chdir $dir_entry;
		    opendir CPU_CACHE_DIR, '.';

		    while (my $cache_dir_entry = readdir CPU_CACHE_DIR) {
			if ($cache_dir_entry =~ /^index/) {
			    $cache_dir_entry =~ m/index([0-9])+/;
			    my $cache_index = $1;

			    $self->{DATA}->{'cpu'}->{$cpu_number}->{'cache'}->{$cache_index} = {};

			    chdir $cache_dir_entry;
			    opendir CPU_CACHE_INDEX_DIR, '.';

			    while (my $index_dir_entry = readdir CPU_CACHE_INDEX_DIR) {
				if (($index_dir_entry eq "level") ||
				    ($index_dir_entry eq "type") ||
				    ($index_dir_entry eq "size") ||
				    ($index_dir_entry eq "shared_cpu_map")) {
				    open INDEX_ENTRY, "<$index_dir_entry";
				    $self->{DATA}->{'cpu'}->{$cpu_number}->{'cache'}->{$cache_index}->{$index_dir_entry} = <INDEX_ENTRY>;
				    chomp($self->{DATA}->{'cpu'}->{$cpu_number}->{'cache'}->{$cache_index}->{$index_dir_entry});
				    close INDEX_ENTRY;

				    if ($index_dir_entry eq "shared_cpu_map") {
					$self->hex_mask_to_binary_mask(\$self->{DATA}->{'cpu'}->{$cpu_number}->{'cache'}->{$cache_index}->{$index_dir_entry});
				    }
				}
			    }

			    closedir CPU_CACHE_INDEX_DIR;
			    chdir '../';
			}
		    }

		    closedir CPU_CACHE_DIR;
		    chdir '../';
		} elsif (($dir_entry eq "topology") && $self->{DATA}->{'sysfs_cpu_topology_supported'}) {
		    $self->{DATA}->{'cpu'}->{$cpu_number}->{'topology'} = {};

		    chdir $dir_entry;
		    opendir CPU_TOPOLOGY_DIR, '.';

		    while (my $topology_dir_entry = readdir CPU_TOPOLOGY_DIR) {
			if (($topology_dir_entry eq "core_siblings") ||
			    ($topology_dir_entry eq "thread_siblings") ||
			    ($topology_dir_entry eq "core_id") ||
			    ($topology_dir_entry eq "physical_package_id") ||
			    ($topology_dir_entry eq "book_id") ||
			    ($topology_dir_entry eq "book_siblings")) {
			    open TOPOLOGY_ENTRY, "<$topology_dir_entry";
			    $self->{DATA}->{'cpu'}->{$cpu_number}->{'topology'}->{$topology_dir_entry} = <TOPOLOGY_ENTRY>;
			    chomp($self->{DATA}->{'cpu'}->{$cpu_number}->{'topology'}->{$topology_dir_entry});
			    close TOPOLOGY_ENTRY;

			    if (($topology_dir_entry eq "core_siblings") ||
				($topology_dir_entry eq "thread_siblings") ||
				($topology_dir_entry eq "book_siblings")) {
				$self->hex_mask_to_binary_mask(\$self->{DATA}->{'cpu'}->{$cpu_number}->{'topology'}->{$topology_dir_entry});
			    }
			}
		    }

		    closedir CPU_TOPOLOGY_DIR;
		    chdir '../';
		}
	    }

	    if (! exists $self->{DATA}->{'cpu'}->{$cpu_number}->{'online_state'}) {
		$self->{DATA}->{'cpu'}->{$cpu_number}->{'online_state'} = 1;
		$self->{DATA}->{'cpu'}->{$cpu_number}->{'offlineable'} = 0;
	    }

	    if ($self->{DATA}->{'ppc'}) {
		$self->{DATA}->{'cpu'}->{$cpu_number}->{'ppc_core'} = 0;
	    }

	    closedir CPU_DIR;
	    chdir '../';
	}
    }

    closedir SYSTEM_CPU_DIR;

    if ($self->{DATA}->{'ppc'}) {
	$self->{DATA}->{'ppc_cpu'} = {};

	my $proc_device_tree = "/proc/device-tree/cpus";

	if (-d $proc_device_tree) {
	    chdir $proc_device_tree;
	    opendir PROC_DEVICE_TREE, $proc_device_tree;

	    while (my $device_tree_entry = readdir PROC_DEVICE_TREE) {
		if ($device_tree_entry =~ /^PowerPC/) {
		    $device_tree_entry =~ m/.*@([0-9a-fA-F]+)/;
		    my $cpu_in_hex = $1;
		    my $cpu_in_dec = hex $cpu_in_hex;
		    if (exists $self->{DATA}->{'cpu'}->{$cpu_in_dec}) {
			$self->{DATA}->{'cpu'}->{$cpu_in_dec}->{'ppc_core'} = 1;
		    }
		}
	    }

	    close PROC_DEVICE_TREE;
	}
    }
}

# mine the system for information about the numa topology
sub gather_numa_info {
    my $self = shift;

    if (! $self->{DATA}->{'numa_enabled'}) {
	return 1;
    }

    $self->{DATA}->{'numa'} = {};

    chdir "$self->{DATA}->{'sysfs_path'}/devices/system/node";
    opendir SYSTEM_NODE_DIR, '.';

    while (my $node_dir_entry = readdir SYSTEM_NODE_DIR) {
	if (($node_dir_entry =~ /^node/) && -d $node_dir_entry) {
	    $node_dir_entry =~ m/node([0-9]+)/;
	    my $node_number = $1;

	    $self->{DATA}->{'numa'}->{$node_number} = {};
	    $self->{DATA}->{'numa'}->{$node_number}->{'cpu'} = {};

	    chdir $node_dir_entry;
	    opendir NODE_DIR, '.';

	    while (my $node_entry = readdir NODE_DIR) {
		if ($node_entry =~ /^cpu[0-9]+/) {
		    $node_entry =~ m/cpu([0-9]+)/;

		    if (exists $self->{DATA}->{'cpu'}->{$1}) {
			# provide a reference to the appropriate CPU data, if available
			$self->{DATA}->{'numa'}->{$node_number}->{'cpu'}->{$1} = $self->{DATA}->{'cpu'}->{$1};
		    } else {
			$self->{DATA}->{'numa'}->{$node_number}->{'cpu'}->{$1} = undef;
		    }
		} elsif ($node_entry eq "meminfo") {
		    open NODE_MEMINFO, "<meminfo";
		    while (<NODE_MEMINFO>) {
			if ($_ =~ /MemTotal/) {
			    chomp($_);
			    $_ =~ s/.*MemTotal:\s+([0-9]+)\skB/$1/;
			    $self->{DATA}->{'numa'}->{$node_number}->{'memory'} = $_;
			    last;
			}
		    }
		    close NODE_MEMINFO;
		} elsif ($node_entry eq "distance") {
		    open NODE_DISTANCE, "<distance";
		    my @distances = split(' ', <NODE_DISTANCE>);
		    for (my $i=0; $i<@distances; $i++) {
			chomp($distances[$i]);
			$self->{DATA}->{'numa'}->{$node_number}->{'distance'}->{$i} = $distances[$i];
		    }
		    close NODE_DISTANCE;
		}
	    }

	    closedir NODE_DIR;
	    chdir '../';
	}
    }

    closedir SYSTEM_NODE_DIR;

    # this block is a fixup for discontiguous NUMA nodes (ie. not all nodes are indexed 0,1,2,...,N -- could be 0,1,16,17)
    # without this fixup the distances are incorrectly reported
    my %nodes;
    my $counter = 0;
    foreach my $node (sort {$a <=> $b} (keys %{$self->{DATA}->{'numa'}})) {
	$nodes{$counter++} = $node;
    }
    foreach my $node (sort {$a <=> $b} (keys %{$self->{DATA}->{'numa'}})) {
	foreach my $node_distance (sort {$a <=> $b} (keys %nodes)) {
	    $self->{DATA}->{'numa'}->{$node}->{'distance'}->{$nodes{$node_distance}} = delete $self->{DATA}->{'numa'}->{$node}->{'distance'}->{$node_distance};
	}
    }
}

# convert a hexadecimal bit mask to a binary bit mask -- since some
# systems can have extremely large bit masks that would overflow perl
# numeric data types a string is used to contain the binary bit mask
# -- accepts 1 argument which is the hexadecimal bit mask to convert
sub hex_mask_to_binary_mask {
    my $self = shift;
    my $input = shift;

    my @array = split(',', $$input);
    my $string = "";

    foreach my $x (@array) {
	my $foo = hex $x;
	$string .= sprintf("%032b", $foo);
    }

    $string =~ s/^0+//;

    $$input = $string;
}

# return an array of the 'on' entries in the supplied binary mask in decimal form
# that is the entries that have a 1 and not a 0
sub list_binary_mask_entries {
    my $self = shift;
    my $mask = shift;

    my @list;

    # reverse the array so that lowest order bit as at position zero
    my @array = reverse(split(//, $mask));

    for (my $i=0; $i<@array; $i++) {
	if ($array[$i] eq '1') {
	    push @list, $i;
	}
    }

    return @list;
}

# return the number of 'on' entries in the supplied binary mask
# that is the entries that have a 1 and not a 0
sub count_binary_mask_entries {
    my $self = shift;
    my $mask = shift;
    my $counter = 0;

    # count the number of times a 1 is found by the match
    $counter++ while ($mask =~ m/1/g);

    return $counter;
}

# return an array of the physical packages in the system
sub get_phys_packages {
    my $self = shift;

    my @list;
    my %hash;

    if ($self->{DATA}->{'sysfs_cpu_topology_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    if ($self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
		# store the list elements in a hash to guarantee uniqueness
		$hash{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'core_siblings'}} = 0;
	    }
	}
    }

    # translate the hash to an array
    foreach my $mask (keys %hash) {
	push @list, $mask;
    }

    return @list;
}

# get the number of physical cores in the system
sub count_cores {
    my $self = shift;

    my @package_list = $self->get_phys_packages;

    if (@package_list) {
	my %cpu_list;
	my %socket_list;
	my @thread_siblings;

	foreach my $socket (@package_list) {
	    $socket_list{$socket} = 0;
	}

	foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'cpu'}})) {
	    if (exists $cpu_list{$cpu} ||
		! $self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
		# this cpu has already been processed or is offline
		next;
	    } else {
		# this thread has not been processed before, so add a
		# core to the specified socket
		$socket_list{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'core_siblings'}} += 1;

		# get the list of threads that share a core
		@thread_siblings = $self->list_binary_mask_entries($self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'thread_siblings'});

		# add the threads to the list of cpus to skip
		foreach my $thread (@thread_siblings) {
		    $cpu_list{$thread} = 0;
		}
	    }
	}

	my $core_count = 0;

	foreach my $socket (keys %socket_list) {
	    # count the cores on each socket
	    $core_count += $socket_list{$socket};
	}

	return $core_count;
    } else {
	return -1;
    }
}

# return an array of the online ppc cores
sub ppc_list_online_cores {
    my $self = shift;

    my @list;

    if ($self->{DATA}->{'ppc'}) {
	foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'cpu'}})) {
	    if ($self->{DATA}->{'cpu'}->{$cpu}->{'online_state'} &&
		$self->{DATA}->{'cpu'}->{$cpu}->{'ppc_core'}) {
		push @list, $cpu;
	    }
	}
    }

    return @list;
}

################################################################################
#                              Public Functions Below                          #
################################################################################

# return the sysfs cache status of the system
sub check_sysfs_cache_support {
    my $self = shift;

    return $self->{DATA}->{'sysfs_cpu_cache_supported'};
}

# return the sysfs topology status of the system
sub check_sysfs_topology_support {
    my $self = shift;

    return $self->{DATA}->{'sysfs_cpu_topology_supported'};
}

# return the numa status of the system
sub check_numa_support {
    my $self = shift;

    return $self->{DATA}->{'numa_enabled'};
}

# return the number of numa nodes
sub get_numa_node_count {
    my $self = shift;

    if ($self->{DATA}->{'numa_enabled'}) {
	return keys %{$self->{DATA}->{'numa'}};
    }

    return 0;
}

# return an array with an element describing each numa node
sub get_numa_node_list {
    my $self = shift;

    my @list;

    if ($self->{DATA}->{'numa_enabled'}) {
	foreach my $node (sort { $a <=> $b } (keys %{$self->{DATA}->{'numa'}})) {
	    push @list, $node;
	}
    }

    return @list;
}

# return the total amount of memory across all numa nodes
sub get_numa_total_memory {
    my $self = shift;

    my $total = 0;

    if ($self->{DATA}->{'numa_enabled'}) {
	foreach my $node (keys %{$self->{DATA}->{'numa'}}) {
	    $total += $self->{DATA}->{'numa'}->{$node}->{'memory'};
	}
    }

    return $total;
}

# return the amount of memory on a specified numa node
# return -1 on error
sub get_numa_node_memory {
    my $self = shift;
    my $node = shift;

    if ($self->{DATA}->{'numa_enabled'} &&
	($node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$node}) {
	return $self->{DATA}->{'numa'}->{$node}->{'memory'};
    }

    return -1;
}

# return the total number of processors in a system
sub get_processor_count {
    my $self = shift;

    return keys %{$self->{DATA}->{'cpu'}};
}

# return the total number of online processors in a system
sub get_online_processor_count {
    my $self = shift;

    my $online_processors = 0;

    foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	if ($self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
	    $online_processors++;
	}
    }

    return $online_processors;
}

# return the total number of offline processors in a system
sub get_offline_processor_count {
    my $self = shift;

    my $offline_processors = 0;

    foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	if (! $self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
	    $offline_processors++;
	}
    }

    return $offline_processors;
}

# return an array with an element for each online processor
sub get_online_processor_list {
    my $self = shift;

    my @list;

    foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'cpu'}})) {
	if ($self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
	    push @list, $cpu;
	}
    }

    return @list;
}

# return an array with an element for each offline processor
sub get_offline_processor_list {
    my $self = shift;

    my @list;

    foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'cpu'}})) {
	if (! $self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
	    push @list, $cpu;
	}
    }

    return @list;
}

# return the number of processors on a given numa node
sub get_numa_node_processor_count {
    my $self = shift;
    my $node = shift;

    if ($self->{DATA}->{'numa_enabled'} &&
	($node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$node}) {
	return keys %{$self->{DATA}->{'numa'}->{$node}->{'cpu'}};
    }

    return -1;
}

# return a count of the number of online processors on a given numa node
sub get_numa_node_online_processor_count {
    my $self = shift;
    my $node = shift;

    my $online_processors = 0;

    if ($self->{DATA}->{'numa_enabled'} &&
	($node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$node}) {
	foreach my $cpu (keys %{$self->{DATA}->{'numa'}->{$node}->{'cpu'}}) {
	    if ($self->{DATA}->{'numa'}->{$node}->{'cpu'}->{$cpu}->{'online_state'}) {
		$online_processors++;
	    }
	}
    } else {
	return -1;
    }

    return $online_processors;
}

# return a count of the number of offline processors on a given numa node
sub get_numa_node_offline_processor_count {
    my $self = shift;
    my $node = shift;

    my $offline_processors = 0;

    if ($self->{DATA}->{'numa_enabled'} &&
	($node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$node}) {
	foreach my $cpu (keys %{$self->{DATA}->{'numa'}->{$node}->{'cpu'}}) {
	    if (! $self->{DATA}->{'numa'}->{$node}->{'cpu'}->{$cpu}->{'online_state'}) {
		$offline_processors++;
	    }
	}
    } else {
	return -1;
    }

    return $offline_processors;
}

# return an array with an element for each online processor on a given numa node
sub get_numa_node_online_processors {
    my $self = shift;
    my $node = shift;

    my @list;

    if ($self->{DATA}->{'numa_enabled'} &&
	($node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$node}) {
	foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'numa'}->{$node}->{'cpu'}})) {
	    if ($self->{DATA}->{'numa'}->{$node}->{'cpu'}->{$cpu}->{'online_state'}) {
		push @list, $cpu;
	    }
	}
    }

    return @list;
}

# return an array with an element for each offline processor on a given numa node
sub get_numa_node_offline_processors {
    my $self = shift;
    my $node = shift;

    my @list;

    if ($self->{DATA}->{'numa_enabled'} &&
	($node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$node}) {
	foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'numa'}->{$node}->{'cpu'}})) {
	    if (! $self->{DATA}->{'numa'}->{$node}->{'cpu'}->{$cpu}->{'online_state'}) {
		push @list, $cpu;
	    }
	}
    }

    return @list;
}

# return the NUMA distance between the specified nodes
sub get_numa_distance {
    my $self = shift;
    my $primary_node = shift;
    my $secondary_node = shift;

    if ($self->{DATA}->{'numa_enabled'} &&
	($primary_node >= 0) &&
	($secondary_node >= 0) &&
	exists $self->{DATA}->{'numa'}->{$primary_node}->{'distance'}->{$secondary_node}) {
	return $self->{DATA}->{'numa'}->{$primary_node}->{'distance'}->{$secondary_node};
    }

    return -1;
}

# return the number of sockets in the system
sub get_socket_count {
    my $self = shift;

    my @packages = $self->get_phys_packages;

    if (@packages) {
	return scalar(@packages);
    } elsif ($self->{DATA}->{'opteron'} || $self->{DATA}->{'ppc'}) {
	my $nodes = $self->get_numa_node_count;

	if ($nodes > 0) {
	    return $nodes;
	}
    }

    return -1;
}

# return the number of cores in the system
sub get_core_count {
    my $self = shift;

    my $core_count = $self->count_cores;

    if ($core_count != -1) {
	return $core_count;
    } elsif ($self->{DATA}->{'opteron'}) {
	return $self->get_processor_count;
    } elsif ($self->{DATA}->{'ppc'}) {
	return scalar($self->ppc_list_online_cores);
    }

    return -1;
}

# return a hash of processor threads per socket
# each hash element contains an array of the threads on that socket
# the sockets are logical sockets, there is no direct mapping to a physical socket
sub get_socket_thread_list {
    my $self = shift;

    my @sockets_list = $self->get_phys_packages;
    my %hash;

    if (@sockets_list) {
	for (my $i=0; $i<@sockets_list; $i++) {
	    $hash{$i} = ();
	    my @thread_list = $self->list_binary_mask_entries($sockets_list[$i]);
	    push @{$hash{$i}}, @thread_list;
	}

	return %hash;
    } elsif ($self->{DATA}->{'opteron'} || $self->{DATA}->{'ppc'}) {
	my @numa_nodes = $self->get_numa_node_list;

	foreach my $node (@numa_nodes) {
	    $hash{$node} = ();

	    my @node_cpu_list = $self->get_numa_node_online_processors($node);
	    push @{$hash{$node}}, @node_cpu_list;
	}

	return %hash;
    } else {
	return ();
    }
}

# return a hash of processor threads per core
# each hash element contains an array of the threads on that core
sub get_core_thread_list {
    my $self = shift;

    my %cores;
    my %cpu_list;

    if ($self->{DATA}->{'sysfs_cpu_topology_supported'}) {
	foreach my $cpu (sort { $a <=> $b } (keys %{$self->{DATA}->{'cpu'}})) {
	    if ($self->{DATA}->{'cpu'}->{$cpu}->{'online_state'}) {
		my @thread_siblings = $self->list_binary_mask_entries($self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'thread_siblings'});

		if (exists $cores{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'thread_siblings'}}) {
		    next;
		} else {
		    $cores{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'thread_siblings'}} = ();
		    push @{$cores{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'thread_siblings'}}}, @thread_siblings;
		}
	    }
	}

	# convert mask index to core index
	my $counter = 0;
	foreach my $core (sort { $a <=> $b } (keys %cores)) {
	    $cores{$counter} = $cores{$core};
	    delete $cores{$core};
	    $counter++;
	}

	return %cores;
    } elsif ($self->{DATA}->{'opteron'}) {
	# Opteron has never had HT/SMT, so each processor is a core
	my @processors = $self->get_online_processor_list;

	my $counter = 0;
	foreach my $cpu (@processors) {
	    $cores{$counter} = ();
	    push @{$cores{$counter}}, $cpu;
	    $counter++;
	}

	return %cores;
    } elsif ($self->{DATA}->{'ppc'}) {
	my $processors = $self->get_processor_count;
	my @ppc_cores = $self->ppc_list_online_cores;

	if ($processors != scalar(@ppc_cores)) {
	    # SMT appears active
	    my $counter = 0;

	    foreach my $cpu (@ppc_cores) {
		# assumption here is that on PPC an sibling HT is the
		# cpu immediately following the primary thread of the
		# core -- this would break on systems with SMT4, but
		# hopefully systems like that have the proper sysfs
		# topology information to not fall down this code path
		my $sibling = $cpu + 1;
		$cores{$counter} = ();
		push @{$cores{$counter}}, $cpu;

		if ((exists $self->{DATA}->{'cpu'}->{$sibling}) &&
		    $self->{DATA}->{'cpu'}->{$sibling}->{'online_state'}) {
		    push @{$cores{$counter}}, $sibling;
		}

		$counter++;
	    }
	} else {
	    # SMT appears to not be active
	    my $counter = 0;
	    foreach my $cpu (@ppc_cores) {
		$cores{$counter} = ();
		push @{$cores{$counter}}, $cpu;
		$counter++;
	    }
	}

	return %cores;
    }
}

# return the number of core level siblings of a particular cpu
sub get_core_level_sibling_count {
    my $self = shift;
    my $cpu = shift;

    if ((exists $self->{DATA}->{'cpu'}->{$cpu}) &&
	$self->{DATA}->{'sysfs_cpu_topology_supported'}) {
	my $core_siblings = $self->count_binary_mask_entries($self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'core_siblings'});

	if ($core_siblings > 0) {
	    $core_siblings--;
	    return $core_siblings;
	}
    }

    return -1;
}

# return the number of thread level siblings of a particular cpu
sub get_thread_level_sibling_count {
    my $self = shift;
    my $cpu = shift;

    if ((exists $self->{DATA}->{'cpu'}->{$cpu}) &&
	$self->{DATA}->{'sysfs_cpu_topology_supported'}) {
	my $thread_siblings = $self->count_binary_mask_entries($self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'thread_siblings'});

	if ($thread_siblings > 0) {
	    $thread_siblings--;
	    return $thread_siblings;
	}
    }

    return -1;
}

# check if the system supports hyperthreading (HT) or SMT
# return 1 if SMT/HT is present, return 0 if not
sub get_hardware_threading_status {
    my $self = shift;

    # opterons do not have HT/SMT under any circumstances
    if (! $self->{DATA}->{'opteron'}) {
	my $processors = $self->get_processor_count;
	my $cores = $self->get_core_count;

	if (($processors > 0) &&
	    ($cores > 0) &&
	    ($processors != $cores)) {
	    return 1;
	}
    }

    return 0;
}

# return the number of hardware threads per core
sub get_hardware_threads_per_core {
    my $self = shift;

    # opterons do not have HT/SMT under any circumstances
    if ($self->{DATA}->{'opteron'}) {
	return 1;
    } else {
	my $processors = $self->get_processor_count;
	my $cores = $self->get_core_count;

	if (($processors > 0) &&
	    ($cores > 0)) {
	    return ($processors / $cores);
	}
    }

    return -1;
}

# return an array of the cache levels present in the system
sub get_cache_levels {
    my $self = shift;

    my %hash;
    my @list;

    if ($self->{DATA}->{'sysfs_cpu_cache_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    foreach my $cache (keys %{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}}) {
		$hash{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'level'}} = 0;
	    }
	}
    }

    # translate hash to array
    # a hash is initially used to ensure uniqueness
    foreach my $key (sort { $a <=> $b } (keys %hash)) {
	push @list, $key;
    }

    return @list;
}

# return an array of the cache types for a given cache level
sub get_cache_level_types {
    my $self = shift;
    my $level = shift;

    my %hash;
    my @list;

    if ($self->{DATA}->{'sysfs_cpu_cache_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    foreach my $cache (keys %{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}}) {
		if ($level == $self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'level'}) {
		    $hash{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'type'}} = 0;
		}
	    }
	}
    }

    # translate hash to array
    # a hash is initially used to ensure uniqueness
    foreach my $key (keys %hash) {
	push @list, $key;
    }

    return @list;
}

# return the cache size for a given cache level type
sub get_cache_level_type_size {
    my $self = shift;
    my $level = shift;
    my $type = shift;

    if ($self->{DATA}->{'sysfs_cpu_cache_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    foreach my $cache (keys %{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}}) {
		if (($level == $self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'level'}) &&
		    ($type eq $self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'type'})) {
		    return $self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'size'};
		}
	    }
	}
    }

    return -1;
}

# return a hash of the the processor threads that share a specified
# cache level -- each hash element represents a different cache -- the
# array elements of each hash element represent the different
# processors that share that specific cache
sub get_shared_cache_list {
    my $self = shift;
    my $level = shift;

    my %hash;

    if ($self->{DATA}->{'sysfs_cpu_cache_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    foreach my $cache (keys %{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}}) {
		if ($level == $self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'level'}) {
		    if (exists $hash{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'shared_cpu_map'}}) {
			next;
		    } else {
			$hash{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'shared_cpu_map'}} = ();
			push @{$hash{$self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'shared_cpu_map'}}}, $self->list_binary_mask_entries($self->{DATA}->{'cpu'}->{$cpu}->{'cache'}->{$cache}->{'shared_cpu_map'});
		    }
		}
	    }
	}
    }

    # convert mask index to core index
    my $counter = 0;
    foreach my $mask (sort { $a <=> $b } (keys %hash)) {
	$hash{$counter} = $hash{$mask};
	delete $hash{$mask};
	$counter++;
    }

    return %hash;
}

# return a list of book ids, if present
sub get_book_list {
    my $self = shift;

    my %list;

    if ($self->{DATA}->{'sysfs_cpu_topology_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    if (exists $self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}) {
		$list{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}} = 1;
	    }
	}
    }

    return sort (keys %list);
}

# return a hash of book ids and the sockets on those books and the threads on those sockets
sub get_book_socket_thread_list {
    my $self = shift;

    my %hash;

    if ($self->{DATA}->{'sysfs_cpu_topology_supported'}) {
	foreach my $cpu (keys %{$self->{DATA}->{'cpu'}}) {
	    if (exists $self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}) {
		if (! exists $hash{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}}) {
		    $hash{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}} = {};
		}

		if (! exists $hash{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}}{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'physical_package_id'}}) {
		    $hash{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}}{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'physical_package_id'}} = ();
		}

		push @{$hash{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'book_id'}}{$self->{DATA}->{'cpu'}->{$cpu}->{'topology'}->{'physical_package_id'}}}, $cpu;
	    }
	}
    }

    return %hash;
}

1;
