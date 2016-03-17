#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/barrier_director.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

#
# Barrier director.
# Listen for connections on the well-know barrier port (1111).
# Barrier masters will connect and:
# - Register a new barrier. It will send us the port number to assign to
#   this barrier, and we will generate a UUID for the barrier and return
#   it to the master.
# or
# - Remove an existing barrier. It will send us the name and UUID of the
#   barrier that it wants to close.
# Barrier clients will connect and request the port number for a
#  barrier. If that barrier has been created, we will return the port
#  number.
#
# We also record the timeout for each barrier (adding 20% just to be safe).
# If the barrier master does not connect and close the barrier before the
# timeout, we will remove it from our list.
#
# If no barriers are currently in our list, and there's no activity on
# the socket for 10 seconds, we will exit.
#
# This script is started from the 'barrier' script when run on the master.
# We attempt to lock a file to determine if another instance of the director
# is already running. If so, we just exit.

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Fcntl qw(:flock LOCK_EX LOCK_UN LOCK_NB);
use IO::Socket;
use IO::Select;
use Socket;
use autobench::args;
use autobench::file;
use autobench::process;
use autobench::time;

my $debug = 1;

my %barrier_data;
my $processed_barriers = 0;
my $listen_socket;
my $select_timeout = 3;
my $idle_timeout = 60;
my $idle_time;
my $autodir = $ENV{'AUTODIR'} ? $ENV{'AUTODIR'} : "/autobench";
my $lock_file = "$autodir/var/tmp/barrier_director.lock";
my $log_file = "$autodir/var/tmp/barrier_director.log";
my $state_file = "$autodir/var/tmp/barrier_director.state";
my $read_timeout = 5;
my %settings = ();

# read the command line arguments
parse_args(\@ARGV, \%settings);

# Ensure only one copy of this script is running at a time.
my $rc = open(my $lock_fp, ">$lock_file");
if (!$rc) {
	die("Error opening barrier director lock file: $lock_file\n");
}
$rc = flock($lock_fp, LOCK_EX|LOCK_NB);
if (!$rc) {
	die("Barrier director is already running. Lock file $lock_file is already locked.\n");
}

daemonize(1);

# If the state file contains any data, then most likely the barrier director
# died on the last run. In that case, append to the log file instead of
# overwriting it in case it needs to be debugged.
my $log_file_string;
if (-e $state_file && -s $state_file) {
	$log_file_string = ">>$log_file";
} else {
	$log_file_string = ">$log_file";
}

# Create a logfile, since we won't be able to print to STDOUT or STDERR.
open(my $log_fp, $log_file_string) ||
	die("Cannot open log file $log_file.\n");

# Disable output buffering for the log file.
my $tmp_fp = select $log_fp;
$| = 1;

# Redirect stdout and stderr to the log file and disable buffering.
open(STDOUT, ">&=", $log_fp) || close(STDOUT);
open(STDERR, ">&=", $log_fp) || close(STDERR);
close(STDIN);

select STDOUT;
$| = 1;
select STDERR;
$| = 1;

select $tmp_fp;

# parse the command line arguments
sub parse_args {
    my $ARGS = shift;
    my $settings = shift;

    for (my $x=0; $x<@{$ARGS}; $x++) {
	$$ARGS[$x] =~ m/(.*)=(.*)/;
	$$settings{$1} = $2;
	print("Found cli argument '" . $1 . "' with value '" . $2 . "'\n");
    }

    if (! exists($$settings{'firewall'})) {
	$$settings{'firewall'} = "none";
    } else {
	if (!($$settings{'firewall'} eq "iptables") &&
	    !($$settings{'firewall'} eq "none")) {
	    die("You must specify a supported firewall type [iptables|none] (not '$$settings{'firewall'})", $settings);
	}
    }
}

sub mylog(@)
{
	print $log_fp ("[", timestamp_format(time), "] ", @_, "\n");
}

sub mydebug(@)
{
	if ($debug) {
		mylog(@_);
	}
}

sub barrier_director_exit($)
{
	if ($listen_socket) {
		$listen_socket->shutdown(2);
	}
	close($log_fp);
	flock($lock_fp, LOCK_UN);
	close($lock_fp);
	exit(shift);
}

sub read_barrier_state_file($)
{
	my $data = shift;

	if (!-e $state_file || -z $state_file) {
		return 0;
	}

	open(my $fp, $state_file) || return 1;
	my @contents = <$fp>;
	close($fp);

	my %tmp;
	foreach my $line (@contents) {
		parse_arguments(\%tmp, split('\|', $line));
		$data->{$tmp{'name'}} = { %tmp };
		mylog("Importing barrier from state file:\n" .
		      "\tname: $tmp{'name'}\n" .
		      "\tpid: $tmp{'pid'}\n" .
		      "\tport: $tmp{'port'}\n" .
		      "\ttimeout: $tmp{'timeout'}\n" .
		      "\tuuid: $tmp{'uuid'}\n");
	}
}

sub write_barrier_state_file($)
{
	my $data = shift;
	open(my $fp, ">$state_file") || return 1;
	foreach my $name (sort(keys(%{$data}))) {
		print $fp ("name=$name|pid=$data->{$name}{'pid'}|port=$data->{$name}{'port'}|timeout=$data->{$name}{'timeout'}|uuid=$data->{$name}{'uuid'}\n");
	}
	close($fp);
}

# firewall command assumptions:
#   1) usage of iptables (isn't there something "new" coming?)
#      a) use of INPUT chain
#      b) use of ACCEPT chain
#   2) user executing Autobench has suitable privileges to modify the firewall rules (usually root so hopefully not an issue)

sub open_firewall_port {
    my $settings = shift;

    if ($$settings{'firewall'} eq "iptables") {
	# iptables --insert INPUT --protocol tcp --dport <port> --jump ACCEPT

	my $port = 1111;
	my $cmd_output = `iptables --insert INPUT --protocol tcp --dport $port --jump ACCEPT`;
	my $ret_val = $? >> 8;

	if ($ret_val != 0) {
	    mylog("ERROR: Could not open firewall port $port through iptables.  RC=$ret_val [$cmd_output]");
	} else {
	    mylog("Opened port $port through iptables firewall");
	}
    }
}

sub close_firewall_port {
    my $settings = shift;

    if ($$settings{'firewall'} eq "iptables") {
	# iptables --delete INPUT --protocol tcp --dport <port> --jump ACCEPT

	my $port = 1111;
	my $cmd_output = `iptables --delete INPUT --protocol tcp --dport $port --jump ACCEPT`;
	my $ret_val = $? >> 8;

	if ($ret_val != 0) {
	    mylog("ERROR: Could not close firewall port $port through iptables.  RC=$ret_val  [$cmd_output]");
	} else {
	    mylog("Closed port $port through iptables firewall");
	}
    }
}

read_barrier_state_file(\%barrier_data);

mylog("Creating socket.");
$listen_socket = new IO::Socket::INET( LocalPort => 1111,
					Proto => 'tcp',
					Listen => SOMAXCONN,
					Reuse => 1,
					Timeout => 1 );
if (!$listen_socket) {
	mylog("Could not create listening socket: $!");
	barrier_director_exit(1);
}

open_firewall_port(\%settings);

mylog("Creating select set.");
my $select_set = new IO::Select;
$select_set->add($listen_socket);

while (1) {
	mydebug("Waiting for socket activity.");

	my ($read_set) = IO::Select->select($select_set, undef, undef, $select_timeout);

	if ((!$read_set || !@$read_set) && ! keys(%barrier_data)) {
		mydebug("Barrier director is waiting for something to do.");
		$idle_time += $select_timeout;
		if ($processed_barriers && ($idle_time > $idle_timeout)) {
			close_firewall_port(\%settings);
			mylog("No barriers remaining. Exiting.");
			barrier_director_exit(0);
		}
	} elsif ($read_set) {
		$idle_time = 0;
	}

	foreach my $socket (@$read_set) {
		mydebug("Processing socket");

		if ($socket == $listen_socket) {
			mylog("Accepting connection\n");
			my $new_socket = $socket->accept();
			$select_set->add($new_socket);
		} elsif ($socket) {
			my $peer_host = "unknown_host";
			my $foo1 = $socket->peerhost();
			if ($foo1) {
				my $foo2 = inet_aton($foo1);
				if ($foo2) {
					$peer_host = gethostbyaddr($foo2, AF_INET);
					if (!$peer_host) {
						$peer_host = "$foo1";
						mylog("Failed name resolution for $foo1.");
					}
				} else {
				    mylog("Failed to translate remote host address for $foo1.");
				}
			} else {
			    mylog("Failed to retrieve remote host address from socket.");
			}
			if ($peer_host eq "unknown_host") {
				mylog("Socket is in unknown state. Closing.");
				$select_set->remove($socket);
				close($socket);
				next;
			}

			mydebug("Reading data from socket for $peer_host.");
			my $buf = "";
			read_with_timeout($socket, \$buf, $read_timeout);
			if (!$buf) {
				mylog("Client $peer_host closed connection.\n");
				$select_set->remove($socket);
				close($socket);
				next;
			}
			chomp($buf);

			my %socket_data;
			parse_arguments(\%socket_data, split('\|', $buf));

			if (!exists($socket_data{'type'}) ||
			    !exists($socket_data{'name'})) {
				mylog("Protocol error from $peer_host: Missing 'type' and/or 'name'.");
				next;
			}

			if ($socket_data{'type'} eq "master") {
				# Connection from a barrier master.
				if (!exists($socket_data{'cmd'})) {
					mylog("Protocol error from $peer_host: Missing 'cmd'.");
					next;
				}

				if ($socket_data{'cmd'} eq "new") {
					# Starting a new barrier. Record
					# the port number and timeout
					# given by the master. Generate
					# an MD5 checksum for the master
					# to use when closing the barrier.
					if (!exists($socket_data{'port'}) || !exists($socket_data{'timeout'})) {
						mylog("Protocol error from $peer_host: Missing 'port' and/or 'timeout'.");
						next;
					}

					if (exists($barrier_data{$socket_data{'name'}})) {
						if (($barrier_data{$socket_data{'name'}}{'port'} != $socket_data{'port'}) ||
						    ($barrier_data{$socket_data{'name'}}{'pid'}  != $socket_data{'pid'})) {
							mylog("Error creating barrier $socket_data{'name'}: barrier already exists.");
							if (!socket_write($socket, "reject\n")) {
							    mylog("Error sending reject\n");
							}
						} else {
							mylog("Re-registering existing barrier $socket_data{'name'}.\n" .
							      "\tpid: $socket_data{'pid'}\n" .
							      "\tport: $socket_data{'port'}\n" .
							      "\ttimeout: $barrier_data{$socket_data{'name'}}{'timeout'}\n" .
							      "\tuuid: $barrier_data{$socket_data{'name'}}{'uuid'}");
							if (!socket_write($socket, "ack $barrier_data{$socket_data{'name'}}{'uuid'}\n")) {
							    mylog("Error sending ack\n");
							}
						}
					} else {
						$barrier_data{$socket_data{'name'}} = {
							'pid' => $socket_data{'pid'},
							'port' => $socket_data{'port'},
							'timeout' => $socket_data{'timeout'} + 
								     ($socket_data{'timeout'} - time()) * 1.2,
							'uuid' => md5_hex($socket_data{'name'},
									  $socket_data{'port'},
									  $socket->peerport())
						};
						mylog("Creating new barrier $socket_data{'name'}.\n" .
						      "\tpid: $socket_data{'pid'}\n" .
						      "\tport: $socket_data{'port'}\n" .
						      "\ttimeout: $socket_data{'timeout'}\n" .
						      "\tuuid: $barrier_data{$socket_data{'name'}}{'uuid'}");
						if (!socket_write($socket, "ack $barrier_data{$socket_data{'name'}}{'uuid'}\n")) {
						    mylog("Error sending ack\n");
						}
						write_barrier_state_file(\%barrier_data);
						$processed_barriers++;
					}
				} elsif ($socket_data{'cmd'} eq "close") {
					# Closing a completed barrier.
					# Check that the MD5 checksums match.
					if (!exists($socket_data{'uuid'})) {
						mylog("Protocol error from $peer_host: Missing 'uuid'.");
						next;
					}

					if (exists($barrier_data{$socket_data{'name'}}) &&
					    $barrier_data{$socket_data{'name'}}{'uuid'} eq $socket_data{'uuid'}) {
						mylog("Closing barrier $socket_data{'name'} with UUID " .
						      $barrier_data{$socket_data{'name'}}{'uuid'});
						delete($barrier_data{$socket_data{'name'}});
						if (!socket_write($socket, "ack\n")) {
						    mylog("Error sending ack\n");
						}
						write_barrier_state_file(\%barrier_data);
					} else {
						mylog("Error closing barrier $socket_data{'name'}: " .
						      "barrier does not exist or uuid is incorrect.");
						if (!socket_write($socket, "reject\n")) {
						    mylog("Error sending reject\n");
						}
					}
				}
			} elsif ($socket_data{'type'} eq "client") {
				# Connection from a barrier client. If
				# the desired barrier exists, return
				# the port number to connect to the
				# master with.
				if (exists($barrier_data{$socket_data{'name'}})) {
					mylog("Directing client $peer_host for barrier $socket_data{'name'} " .
					      "to port $barrier_data{$socket_data{'name'}}{'port'}.");
					if (!socket_write($socket, "ack $barrier_data{$socket_data{'name'}}{'port'}\n")) {
					    mylog("Error sending ack\n");
					}
				} else {
					mylog("Client $peer_host trying to connect " .
					      "to non-existent barrier $socket_data{'name'}.");
					if (!socket_write($socket, "reject\n")) {
					    mylog("Error sending reject\n");
					}
				}
			} else {
				mylog("Protocol error from $peer_host: 'type' must be 'master' or 'client'.");
			}
		}
	}

	mydebug("Processed " . @$read_set . " socket(s)");

	foreach my $name (keys(%barrier_data)) {
		if (time > $barrier_data{$name}{'timeout'}) {
			mylog("Timeout expired for barrier $name. Game over.\n");
			delete($barrier_data{$name});
			write_barrier_state_file(\%barrier_data);
			next;
		}

		my $kill_barrier = 1;
		if (open(PID_CHECK_FH, "</proc/" . $barrier_data{$name}{'pid'} . "/cmdline")) {
		    my $file_contents = <PID_CHECK_FH>;
		    close PID_CHECK_FH;

		    if ($file_contents && ($file_contents =~ /barrier_master\.pl/) && ($file_contents =~ /name=$name/)) {
			$kill_barrier = 0;
		    } else {
			mylog("PID check for barrier_master.pl with barrier name '$name' and PID '" . $barrier_data{$name}{'pid'} . "' failed.");
		    }
		}
		if ($kill_barrier == 1) {
		    mylog("Signaling barrier script that barrier '$name' needs cleanup.");
		    my $rc = fifo_write("$autodir/var/tmp/barrier/$name/$name.pipe", "BARRIER MASTER DIED", 1);
		    if (!$rc) {
			mylog("Failed to write to barrier pipe for '$name'.");
		    }
		    delete($barrier_data{$name});
		    write_barrier_state_file(\%barrier_data);
		}
	}
}

