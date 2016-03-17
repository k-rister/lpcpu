#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/block-device-hierarchy.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


use strict;
use warnings;

use Data::Dumper;
use Storable;
use Getopt::Long;

my %options;

# get the cli options and store them for parsing
Getopt::Long::Configure ("bundling");
Getopt::Long::Configure ("no_auto_abbrev");
GetOptions(\%options, 'debug', 'dump=s', 'load=s', 'force', 'top-level-blacklist=s');

if (exists $options{'dump'} && exists $options{'load'}  && ! exists $options{'force'}) {
    print STDERR "ERROR: You specified both --dump and --load.  Why?  If you really want that, use --force also -- but why?";
    exit 1;
}

my %blacklist;

if (exists $options{'top-level-blacklist'}) {
    if (open(TOP_LEVEL_BLACKLIST, "<", $options{'top-level-blacklist'})) {
	while (<TOP_LEVEL_BLACKLIST>) {
	    chomp($_);

	    $blacklist{$_} = 1;
	}
	close TOP_LEVEL_BLACKLIST;
    } else {
	print STDERR "ERROR: Failed to load top level blacklist from $options{'top-level-blacklist'}!\n";
	exit 1;
    }
}

my %data;

if (exists $options{'load'}) {
    # load the block device topology from the specified file

    eval {
	%data = %{Storable::retrieve($options{'load'})};
    };

    if ($@) {
	chomp($@);
	print STDERR "ERROR: Failed to load the archive from $options{'load'} [$@]!\n";
	exit 1;
    }

    if (! exists $data{'block'} || ! exists $data{'adapters'}) {
	print STDERR "ERROR: Loaded archive does not contain valid block device hierarchy information!\n";
	exit 1;
    }
} else {
    # initialize the data structure with the minimum set of entries
    $data{'block'} = {};
    $data{'adapters'} = {};
    $data{'special'} = {};

    # discover the block device topology by inspecting the system

    # get the "master" list of block devices
    if (open(PROC_PARTITIONS, "<", "/proc/partitions")) {
	while (<PROC_PARTITIONS>) {
	    if ($_ =~ /^\s+[0-9]+\s+[0-9]+\s+[0-9]+\s\S+$/) {
		chomp($_);
		$_ =~ s/^\s+//;
		my @array = split(/\s+/, $_);
		$data{'block'}{$array[0] . ":" . $array[1]} = { 'short_name' => $array[3] };
	    }
	}
	close PROC_PARTITIONS;
    } else {
	print STDERR "ERROR: Could not open /proc/partitions!\n";
	exit 1;
    }

    # find the DM devices
    if (open(DMSETUP_LS, "-|", "dmsetup ls")) {
	while (<DMSETUP_LS>) {
	    if ($_ =~ /No devices found/) {
                last;
	    }

	    chomp($_);
	    $_ =~ m/^(\S+)\s+\(([0-9]+):([0-9]+)\)$/;
	    my $long_name = $1;
	    my $major = $2;
	    my $minor = $3;

	    if (exists $data{'block'}{$major . ":" . $minor}) {
		$data{'block'}{$major . ":" . $minor}{'long_name'} = $long_name;
	    } else {
		print STDERR "ERROR: Found major:minor $major:$minor for DM device with name=$long_name which was not previously discovered -- results may be inaccurate!\n";
	    }
	}
	close DMSETUP_LS;
    } else {
	print STDERR "WARNING: Could not get data from 'dmsetup ls' -- results may be inaccurate!\n";
    }

    # find the components that are used to make DM devices
    if (open(DMSETUP_TABLE, "-|", "dmsetup table")) {
	while (<DMSETUP_TABLE>) {
	    if ($_ =~ /No devices found/) {
                last;
	    }

	    chomp($_);

	    my @array = split(/\s+/, $_);
	    my $device_name = $array[0];
	    $device_name =~ s/:$//;

	    my $key;
	    my $major_minor;
	    foreach $key (keys %{$data{'block'}}) {
		if ((exists $data{'block'}{$key}{'long_name'}) &&
		    ($data{'block'}{$key}{'long_name'} eq $device_name)) {
		    $major_minor = $key;
		    $data{'block'}{$key}{'components'} = ();
		    last;
		}
	    }

	    if (! exists $data{'block'}{$major_minor}) {
		print STDERR "ERROR: Could not locate the major:minor for DM device with name=$device_name -- results may be inaccurate!\n";
		next;
	    }

	    for (my $i=0; $i<@array; $i++) {
		if ($array[$i] =~ /[0-9]+:[0-9]+/) {
		    push @{$data{'block'}{$major_minor}{'components'}}, $array[$i];

		    if (exists $data{'block'}{$array[$i]}) {
			if (! exists $data{'block'}{$array[$i]}{'sub_components'}) {
			    $data{'block'}{$array[$i]}{'sub_components'} = ();
			}

			push @{$data{'block'}{$array[$i]}{'sub_components'}}, $major_minor;
		    } else {
			print STDERR "ERROR: Discovered DM component with major:minor=" . $array[$i] . " which does not exist -- results may be inaccurate!\n";
		    }
		} elsif ($array[$i] =~ /multipath/) {
		    $data{'block'}{$major_minor}{'multipath'} = 1;
		}
	    }
	}
	close DMSETUP_TABLE;
    } else {
	print STDERR "WARNING: Could not get data from 'dmsetup table' -- results may be inaccurate!\n";
    }

    # process Linux MD devices
    if (open(MD_DEVICE_MAP, "<", "/proc/mdstat")) {
	while (<MD_DEVICE_MAP>) {
	    if ($_ !~ /active/) {
		next;
	    }

	    chomp($_);

	    my @array = split(/\s+/, $_);

	    my $key;
	    my $major_minor;
	    foreach $key (keys %{$data{'block'}}) {
		if ($data{'block'}{$key}{'short_name'} eq $array[0]) {
		    $major_minor = $key;
		    last;
		}
	    }

	    if (! exists $data{'block'}{$major_minor}) {
		print STDERR "ERROR: Could not locate the major:minor for MD device with ID=$array[0] -- results may be inaccurate!\n";
		next;
	    }

	    $data{'block'}{$major_minor}{'long_name'} = $array[3];
	    $data{'block'}{$major_minor}{'long_name'} =~ s/\S+://;

	    $data{'block'}{$major_minor}{'components'} = ();

	    if (open(MD_DETAIL, "-|", "mdadm --detail /dev/$array[0]")) {
		my $active = 0;
		while (<MD_DETAIL>) {
		    if ($_ =~ /Number\s+Major\s+Minor\s+RaidDevice\s+State/) {
			$active = 1;
			next;
		    }
		    if ($active) {
			chomp($_);
			if (!length($_)) {
			    next;
			}
			my @device_array = split (/\s+/, $_);

			push @{$data{'block'}{$major_minor}{'components'}}, $device_array[2] . ":" . $device_array[3];

			if (exists $data{'block'}{$device_array[2] . ":" . $device_array[3]}) {
			    if (! exists $data{'block'}{$device_array[2] . ":" . $device_array[3]}{'sub_components'}) {
				$data{'block'}{$device_array[2] . ":" . $device_array[3]}{'sub_components'} = ();
			    }

			    push @{$data{'block'}{$device_array[2] . ":" . $device_array[3]}{'sub_components'}}, $device_array[2] . ":" . $device_array[3];
			} else {
			    print STDERR "ERROR: Discovered MD component with major:minor=" . $device_array[2] . ":" . $device_array[3] . " which does not exist -- results may be inaccurate!\n";
			}
		    }
		}
		close MD_DETAIL;
	    } else {
		print STDERR "ERROR: Could not get from mdadm for MD device with ID=$array[0] -- results may be inaccurate!\n";
	    }
	}
	close MD_DEVICE_MAP;
    } else {
	print STDERR "WARNING: Could not get data from /proc/mdstat -- results may be inaccurate!\n";
    }

    # find special case objects
    if (open(BTRFS_SHOW, "-|", "btrfs filesystem show --all-devices")) {
	my $btrfs_label = '';
	my $btrfs_uuid = '';

	while (<BTRFS_SHOW>) {
	    if ($_ =~ /Label.*uuid/) {
		$_ =~ m/Label:\s+(\S+)\s+uuid:\s(\S+)$/;
		$btrfs_label = $1;
		$btrfs_uuid = $2;

		$data{'special'}{$btrfs_uuid}{'type'} = 'btrfs';
		$data{'special'}{$btrfs_uuid}{'components'} = ();

		if (!($btrfs_label eq 'none')) {
		    $btrfs_label =~ s/^'//;
		    $btrfs_label =~ s/'$//;

		    $data{'special'}{$btrfs_uuid}{'label'} = $btrfs_label;
		}
	    } elsif ($_ =~ /devid/) {
		$_ =~ m/\s(\S+)$/;
		my $device = $1;
		my $full_device = $device;
		if (-l $device) {
		    $device = readlink($device);
		}

		$device =~ s/.*\///;

		my $key;
		my $major_minor = "flubber"; # initialize this variable with nonsense to avoid a possible uninitialized variable warning below

		# this loop will likely only run once, but in rare scenarios when the device name is not found it will run a second time
		# for example: when multipath creates device nodes in /dev/mapper that are not symbolic links (seen on Ubuntu 14.10 server)
		#              since these names will not exist in /proc/partitions (which is the list we match against)
		for (my $i=0; $i<2; $i++) {
		    foreach $key (keys %{$data{'block'}}) {
			if ($data{'block'}{$key}{'short_name'} eq $device) {
			    $major_minor = $key;
			    last;
			}
		    }

		    if ((exists $data{'block'}{$major_minor}) || ($i > 0)) {
			# break out of this loop in the likely scenario that we found the major/minor of the device or this is the second pass
			last;
		    } else {
			# since we did not find the major/minor, check udev to see if the device has a different name to search for
			my $tmp_device = get_udev_device_name($full_device);

			if ($tmp_device eq $full_device) {
			    # we got the same device name back, give up
			    last;
			} else {
			    $device = $tmp_device;
			    $device =~ s/.*\///;
			}
		    }
		}

		if (! exists $data{'block'}{$major_minor}) {
		    print STDERR "ERROR: Could not locate the major:minor for BTRFS component '$device' on filesystem '$btrfs_uuid' -- results may be inaccurate!\n";
		    next;
		}

		push @{$data{'special'}{$btrfs_uuid}{'components'}}, $major_minor;
	    }
	}

	close BTRFS_SHOW;
    } else {
	print STDERR "INFO: Could not check for btrfs filesystems.\n";
    }

    # flag low level device partitions
    # these devices will be ignored
    my $key;
    foreach $key (keys %{$data{'block'}}) {
	if (exists $data{'block'}{$key}{'components'}) {
	    next;
	}

	# assuming that any device which does not have components AND ends with 1 or more numbers in the short_name is a partition
	# for example: sda2
	if ($data{'block'}{$key}{'short_name'} =~ /\D[0-9]+$/) {
	    $data{'block'}{$key}{'partition'} = 1;

	    my $parent_device = $data{'block'}{$key}{'short_name'};
	    $parent_device =~ s/[0-9]+$//;

	    my $key2;
	    foreach $key2 (keys %{$data{'block'}}) {
		if ($data{'block'}{$key2}{'short_name'} eq $parent_device) {
		    if (! exists $data{'block'}{$key}{'components'}) {
			$data{'block'}{$key}{'components'} = ();
		    }

		    push @{$data{'block'}{$key}{'components'}}, $key2;

		    if (! exists $data{'block'}{$key2}{'sub_components'}) {
			$data{'block'}{$key2}{'sub_components'} = ();
		    }

		    push @{$data{'block'}{$key2}{'sub_components'}}, $key;

		    last;
		}
	    }
	}
    }

    # determine the initial devices which are at layer 0
    foreach $key (keys %{$data{'block'}}) {
	if (! exists $data{'block'}{$key}{'components'}) {
	    $data{'block'}{$key}{'layer'} = 0;
	}
    }

    my $loop = 1;
    my $loop_counter = 1;
    my $max_loop_iterations = 500;
    while ($loop) {
	foreach $key (keys %{$data{'block'}}) {
	    if (exists $data{'block'}{$key}{'layer'}) {
		# current device already assigned a layer
		next;
	    }

	    if (exists $data{'block'}{$key}{'components'}) {
		my $highest_layer = 0;
		my $assign_layer = 1;
		for (my $i=0; $i<@{$data{'block'}{$key}{'components'}}; $i++) {
		    if (exists $data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'layer'}) {
			if ($data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'layer'} > $highest_layer) {
			    # a component device has a higher layer than was previously detected, update the highest component layer
			    $highest_layer = $data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'layer'};
			}
		    } else {
			# a component device does not yet have a layer assigned, so we cannot assign the parent device a layer
			$assign_layer = 0;
			last;
		    }
		}

		if ($assign_layer) {
		    # a device must be assigned to a layer 1 higher than it's highest component
		    $data{'block'}{$key}{'layer'} = $highest_layer + 1;
		}
	    }
	}

	# assume we are done
	$loop = 0;
	foreach $key (keys %{$data{'block'}}) {
	    # loop until all devices have been assigned a layer
	    if (! exists $data{'block'}{$key}{'layer'}) {
		# not all devices have been assigned a layer
		$loop = 1;
	    }
	}

	$loop_counter++;
	if ($loop_counter > $max_loop_iterations) {
	    print STDERR "WARNING: Broke out of device hierarchy loop after $max_loop_iterations iterations to avoid the possibility of an infinite loop!\n";
	    print STDERR "WARNING: The script is either confused or you have an extremely complicated block device hierarchy!\n";
	    last;
	}
    }

    # promote block devices which are components only to partitions which are not components
    foreach $key (keys %{$data{'block'}}) {
	if ((exists $data{'block'}{$key}{'partition'}) &&
	    (! exists $data{'block'}{$key}{'sub_components'}) &&
	    (exists $data{'block'}{$key}{'components'})) {
	    for (my $i=0; $i<@{$data{'block'}{$key}{'components'}}; $i++) {
		if (exists $data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'sub_components'}) {
		    my $whitelist_it = 1;
		    for (my $x=0; $x<@{$data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'sub_components'}}; $x++) {
			if ((! exists $data{'block'}{$data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'sub_components'}[$x]}{'partition'}) ||
			    (exists $data{'block'}{$data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'sub_components'}[$x]}{'sub_components'})){
			    $whitelist_it = 0;
			    last;
			}
		    }
		    if ($whitelist_it) {
			$data{'block'}{$data{'block'}{$key}{'components'}[$i]}{'top-level-whitelist'} = 1;
		    }
		}
	    }
	}
    }

    # collect per SCSI adapter block device mappings
    my $sys_path = "/sys/class/scsi_host";
    if (opendir(SCSI_HOST_DIR, $sys_path)) {
	while (my $host_entry = readdir(SCSI_HOST_DIR)) {
	    if ($host_entry eq "." || $host_entry eq "..") {
		next;
	    }

	    my $adapter_type;
	    if (-e "$sys_path/$host_entry/model_name" && open(ADAPTER_TYPE, "<", "$sys_path/$host_entry/model_name")) {
		$adapter_type = <ADAPTER_TYPE>;
		close ADAPTER_TYPE;
	    } elsif (-e "$sys_path/$host_entry/modelname" && open(ADAPTER_TYPE, "<", "$sys_path/$host_entry/modelname")) {
		$adapter_type = <ADAPTER_TYPE>;
		close ADAPTER_TYPE;
	    } elsif (-e "$sys_path/$host_entry/proc_name" && open(ADAPTER_TYPE, "<", "$sys_path/$host_entry/proc_name")) {
		$adapter_type = <ADAPTER_TYPE>;
		close ADAPTER_TYPE;
	    } else {
		$adapter_type = "unknown";
	    }

	    my $adapter_desc;
	    if (-e "$sys_path/$host_entry/info" && open(ADAPTER_DESC, "<", "$sys_path/$host_entry/info")) {
		$adapter_desc = <ADAPTER_DESC>;
		close ADAPTER_DESC;
	    } elsif (-e "$sys_path/$host_entry/model_desc" && open(ADAPTER_DESC, "<", "$sys_path/$host_entry/model_desc")) {
		$adapter_desc = <ADAPTER_DESC>;
		close ADAPTER_DESC;
	    } elsif (-e "$sys_path/$host_entry/modeldesc" && open(ADAPTER_DESC, "<", "$sys_path/$host_entry/modeldesc")) {
		$adapter_desc = <ADAPTER_DESC>;
		close ADAPTER_DESC;
	    } else {
		$adapter_desc = "not available";
	    }

	    chomp($adapter_type);
	    chomp($adapter_desc);
	    $data{'adapters'}{$host_entry}{'type'} = $adapter_type;
	    $data{'adapters'}{$host_entry}{'desc'} = $adapter_desc;
	    $data{'adapters'}{$host_entry}{'class'} = "SCSI";

	    my @devices;
	    if (opendir(DEVICE_DIR, "$sys_path/$host_entry/device")) {
		while (my $device_entry = readdir(DEVICE_DIR)) {
		    if ($device_entry =~ /^target/) {
			if (opendir(TARGET_DIR, "$sys_path/$host_entry/device/$device_entry")) {
			    while (my $target_entry = readdir(TARGET_DIR)) {
				if ($target_entry =~ /[0-9]+:[0-9]+:[0-9]+:[0-9]+/) {
				    if (opendir(LUN_DIR, "$sys_path/$host_entry/device/$device_entry/$target_entry/block")) {
					while (my $lun_entry = readdir(LUN_DIR)) {
					    if ($lun_entry eq "." || $lun_entry eq "..") {
						next;
					    }
					    push @devices, $lun_entry;
					}
					close LUN_DIR;
				    }
				}
			    }
			    close TARGET_DIR;
			}
		    } elsif ($device_entry =~ /^port/) {
			if (opendir(PORT_DIR, "$sys_path/$host_entry/device/$device_entry")) {
			    while (my $port_entry = readdir(PORT_DIR)) {
				if ($port_entry =~ /^end/) {
				    if (opendir(END_DEVICE_DIR, "$sys_path/$host_entry/device/$device_entry/$port_entry")) {
					while (my $end_device_entry = readdir(END_DEVICE_DIR)) {
					    if ($end_device_entry =~ /^target/) {
						if (opendir(TARGET_DIR, "$sys_path/$host_entry/device/$device_entry/$port_entry/$end_device_entry")) {
						    while (my $target_entry = readdir(TARGET_DIR)) {
							if ($target_entry =~ /[0-9]+:[0-9]+:[0-9]+:[0-9]+/) {
							    if (opendir(LUN_DIR, "$sys_path/$host_entry/device/$device_entry/$port_entry/$end_device_entry/$target_entry/block")) {
								while (my $lun_entry = readdir(LUN_DIR)) {
								    if ($lun_entry eq "." || $lun_entry eq "..") {
									next;
								    }
								    push @devices, $lun_entry;
								}
								close LUN_DIR;
							    }
							}
						    }
						}
					    }
					}
					close END_DEVICE_DIR;
				    }
				}
			    }
			    close PORT_DIR;
			}
		    } elsif ($device_entry =~ /^rport/) {
			if (opendir(RPORT_DIR, "$sys_path/$host_entry/device/$device_entry")) {
			    while (my $rport_entry = readdir(RPORT_DIR)) {
				if ($rport_entry =~ /^target/) {
				    if (opendir(TARGET_DIR, "$sys_path/$host_entry/device/$device_entry/$rport_entry")) {
					while (my $target_entry = readdir(TARGET_DIR)) {
					    if ($target_entry =~ /[0-9]+:[0-9]+:[0-9]+:[0-9]+/) {
						if (opendir(LUN_DIR, "$sys_path/$host_entry/device/$device_entry/$rport_entry/$target_entry/block")) {
						    while (my $lun_entry = readdir(LUN_DIR)) {
							if ($lun_entry eq "." || $lun_entry eq "..") {
							    next;
							}
							push @devices, $lun_entry;
						    }
						    close LUN_DIR;
						}
					    }
					}
					close TARGET_DIR;
				    }
				}
			    }
			    close RPORT_DIR;
			}
		    }
		}
		close DEVICE_DIR;
	    }

	    for (my $i=0; $i<@devices; $i++) {
		foreach $key (keys %{$data{'block'}}) {
		    if ($devices[$i] eq $data{'block'}{$key}{'short_name'}) {
			$devices[$i] = $key;
		    }
		}
	    }

	    if (@devices) {
		$data{'adapters'}{$host_entry}{'devices'} = ();
		push @{$data{'adapters'}{$host_entry}{'devices'}}, @devices;
	    }
	}
	closedir(SCSI_HOST_DIR);
    } else {
	print STDERR "ERROR: Failed to open /sys/class/scsi_host -- per adapter information is unavailable!\n";
    }
}

# perform top level device blacklisting
my $key;
my $key2;
foreach $key (keys %blacklist) {
    foreach $key2 (keys %{$data{'block'}}) {
	if (((exists $data{'block'}{$key2}{'long_name'}) &&
	     ($key eq $data{'block'}{$key2}{'long_name'})) ||
	    ($key eq $data{'block'}{$key2}{'short_name'})) {
	    $data{'block'}{$key2}{'top-level-blacklist'} = 1;

	    # when we blacklist a device we must "promote" any devices
	    # that are components of it, unless the device is not
	    # actually top level
	    if ((! exists $data{'block'}{$key2}{'sub_components'}) &&
		(! exists $data{'block'}{$key2}{'partition'})) {
		for (my $i=0; $i<@{$data{'block'}{$key2}{'components'}}; $i++) {
		    $data{'block'}{$data{'block'}{$key2}{'components'}[$i]}{'top-level-whitelist'} = 1;
		}
	    }
	}
    }
}

############################################################################################################
if (exists $options{'dump'}) {
    eval {
	Storable::nstore(\%data, $options{'dump'});
    };

    print STDERR "ERROR: Failed to dump data to $options{'dump'}!\n" if $@;
}
############################################################################################################

# query udev to acquire a block device's "real" device name
sub get_udev_device_name {
    my $device = shift;

    if (open(UDEV_QUERY, "-|", "udevadm info --root --query=name --name $device")) {
	$device = <UDEV_QUERY>;
	chomp($device);
	close UDEV_QUERY;
    } else {
	print STDERR "ERROR: Could not query UDEV for real device name of $device!\n";
    }

    return $device;
}

# Sort by block device number with format <major>:<minor>
sub block_dev {
    my ($a_maj, $a_min) = split(':', $a);
    my ($b_maj, $b_min) = split(':', $b);

    if ( $a_maj != $b_maj ) {
	return $a_maj <=> $b_maj;
    } else {
	return $a_min <=> $b_min;
    }
}

# Sort by a text string that starts with alphabetic characters and
# ends in a number, e.g., "host0".
sub text_numeric {
    $a =~ /(\D+)(\d*)/;
    my $a_txt = $1;
    my $a_num = $2;

    $b =~ /(\D+)(\d*)/;
    my $b_txt = $1;
    my $b_num = $2;

    if ($a_txt ne $b_txt) {
	return $a_txt cmp $b_txt;
    } else {
	return $a_num <=> $b_num;
    }
}

my $max_layer = 0;
foreach $key (sort block_dev keys %{$data{'block'}}) {
    if ($data{'block'}{$key}{'layer'} > $max_layer) {
	$max_layer = $data{'block'}{$key}{'layer'};
    }
}

my $string;
my $counter;

printf "\n%5s\t%s\n", "Layer", "Devices";
for (my $i=0; $i<=$max_layer; $i++) {
    printf "%5s\t", $i;

    $string = "";
    $counter = 0;

    foreach $key (sort block_dev keys %{$data{'block'}}) {
	if ($data{'block'}{$key}{'layer'} == $i) {
	    $counter++;

	    if (exists $data{'block'}{$key}{'partition'}) {
		$string .= "*";
	    }

	    $string .= $data{'block'}{$key}{'short_name'};

	    if (exists $data{'block'}{$key}{'long_name'}) {
		$string .= "(" . $data{'block'}{$key}{'long_name'} . ")";
	    }

	    $string .= " ";
	}
    }
    print "[" . $counter . "] " . $string . "\n";
}

print "\nTop Level Devices:\n";
$string = "";
$counter = 0;
foreach $key (sort block_dev keys %{$data{'block'}}) {
    if ((! exists $data{'block'}{$key}{'sub_components'}) &&
	(! exists $data{'block'}{$key}{'partition'}) &&
	(! exists $data{'block'}{$key}{'top-level-blacklist'}) ||
	(exists $data{'block'}{$key}{'top-level-whitelist'})) {
	$counter++;

	$string .= $data{'block'}{$key}{'short_name'};

	if (exists $data{'block'}{$key}{'long_name'}) {
	    $string .= "(" . $data{'block'}{$key}{'long_name'} . ")";
	}
	$string .= " ";
    }
}
print "[" . $counter . "] " . $string . "\n";

printf "\n%-10s\t%-15s\t%s\n", "HostID", "Type", "Devices";
foreach $key (sort text_numeric keys %{$data{'adapters'}}) {
    printf "%-10s\t%-15s\t", $key, $data{'adapters'}{$key}{'type'};

    if (exists $data{'adapters'}{$key}{'devices'}) {
	print "[" . @{$data{'adapters'}{$key}{'devices'}} . "] ";

	for (my $i=0; $i<@{$data{'adapters'}{$key}{'devices'}}; $i++) {
	    if (exists $data{'block'}{$data{'adapters'}{$key}{'devices'}[$i]}) {
		print $data{'block'}{$data{'adapters'}{$key}{'devices'}[$i]}{'short_name'};

		if (exists $data{'block'}{$data{'adapters'}{$key}{'devices'}[$i]}{'long_name'}) {
		    print "(" . $data{'block'}{$data{'adapters'}{$key}{'devices'}[$i]}{'long_name'} . ")";
		}
	    } else {
		print "*" . $data{'adapters'}{$key}{'devices'}[$i];
	    }
	    print " ";
	}
    }
    print "\n";
}
print "\n";

printf "%-10s\t%-15s\n", "HostID", "Description";
foreach $key (sort text_numeric keys %{$data{'adapters'}}) {
    printf "%-10s\t%-15s\n", $key, $data{'adapters'}{$key}{'desc'};
}
print "\n";

printf "%-20s\t%s\n", "Device", "Multipaths";
foreach $key (sort block_dev keys %{$data{'block'}}) {
    if (exists $data{'block'}{$key}{'multipath'}) {
	my $device_string = $data{'block'}{$key}{'short_name'};

	if (exists $data{'block'}{$key}{'long_name'}) {
	    $device_string .= "(" . $data{'block'}{$key}{'long_name'} . ")";
	}
	printf "%-20s\t", $device_string;

	if (exists $data{'block'}{$key}{'components'}) {
	    print "[" . @{$data{'block'}{$key}{'components'}} . "] ";

	    foreach (sort block_dev @{$data{'block'}{$key}{'components'}}) {
		print $data{'block'}{$_}{'short_name'};

		if (exists $data{'block'}{$_}{'long_name'}) {
		    print "(" . $data{'block'}{$_}{'long_name'} . ")";
		}

		print " ";
	    }
	}

	print "\n";
    }
}
print "\n";

printf "%-20s\t%s\n", "Device", "Components";
foreach $key (sort block_dev keys %{$data{'block'}}) {
    if (! exists $data{'block'}{$key}{'multipath'} &&
	! exists $data{'block'}{$key}{'partition'} &&
	exists $data{'block'}{$key}{'components'}) {
	my $device_string = $data{'block'}{$key}{'short_name'};

	if (exists $data{'block'}{$key}{'long_name'}) {
	    $device_string .= "(" . $data{'block'}{$key}{'long_name'} . ")";
	}
	printf "%-20s\t", $device_string;

	if (exists $data{'block'}{$key}{'components'}) {
	    print "[" . @{$data{'block'}{$key}{'components'}} . "] ";

	    foreach (sort block_dev @{$data{'block'}{$key}{'components'}}) {
		print $data{'block'}{$_}{'short_name'};

		if (exists $data{'block'}{$_}{'long_name'}) {
		    print "(" . $data{'block'}{$_}{'long_name'} . ")";
		}

		print " ";
	    }
	}

	print "\n";
    }
}

if (%{$data{'special'}}) {
    printf "\nBTRFS Filesystems\n%-40s%-20s%s\n", "UUID", "Label", "Components";
    foreach $key (sort keys %{$data{'special'}}) {
	if ($data{'special'}{$key}{'type'} eq 'btrfs') {
	    printf "%-40s", $key;

	    my $label = "n/a";
	    if (exists $data{'special'}{$key}{'label'}) {
		$label = $data{'special'}{$key}{'label'};
	    }

	    printf "%-20s", $label;

	    if (@{$data{'special'}{$key}{'components'}}) {
		print "[" . @{$data{'special'}{$key}{'components'}} . "] ";

		foreach (sort block_dev @{$data{'special'}{$key}{'components'}}) {
		    print $data{'block'}{$_}{'short_name'};

		    if (exists $data{'block'}{$_}{'long_name'}) {
			print "(" . $data{'block'}{$_}{'long_name'} . ")";
		    }

		    print " ";
		}
	    }

	    print "\n";
	}
    }
}

if (exists $options{'debug'}) {
    print "\n";
    $Data::Dumper::Sortkeys = 1;
    print Dumper \%data;
    print Dumper \%blacklist;
}
