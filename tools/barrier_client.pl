#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/barrier_client.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


use strict;
use warnings;
use IO::Socket;
#use Data::Dumper;
use autobench::file;
use autobench::time;
use threads;

# disable output buffering
$|++;

# routine to provide timestamped logging
sub mylog {
    my $str = shift;

    print "[" . timestamp_format(time) . "] " . $str . "\n";
}

# routine to exit with an error code
sub exit_error {
    my $msg = shift;
    mylog $msg;
    # error code 86 is the Autobench fatal error code
    exit 86;
}

my %settings;

# Default timeout for reading from the sockets.
$settings{'read_timeout'} = 5;

for (my $x=0; $x<@ARGV; $x++) {
    $ARGV[$x] =~ m/(.*)=(.*)/;
    $settings{$1} = $2;
    mylog "Found cli argument '" . $1 . "' with value '" . $2 . "'";
}

if (! exists($settings{'name'})) {
    exit_error "You must specify the client name";
}

if (! exists($settings{'timeout'})) {
    exit_error "You must specify the timeout length";
}

if (! exists($settings{'master'})) {
    exit_error "You must specify the barrier master";
}

if (! exists($settings{'barrier_name'})) {
    exit_error "You must specify the barrier name";
}

# The client timeout is handled by a separate thread. If this thread
# exits, it will cause the whole barrier client process to exit as well.
# If the barrier completes successfully, this thread will exit when the
# main process exits.
sub barrier_timeout($)
{
    my $timeout = shift;
    sleep $timeout;
    exit_error "BARRIER TIMED OUT";
}

my $start_time = time;
mylog "Barrier will timeout at " . timestamp_format($start_time + $settings{'timeout'});
my $timeout_thread = threads->create('barrier_timeout', $settings{'timeout'});
$timeout_thread->detach();

my $state = "verifying";
my $quit_signal = 1;
my $attempts = 0;

while (!exists($settings{'peerport'})) {
    my $socket = new IO::Socket::INET ( PeerAddr => $settings{'master'},
					PeerPort => 1111,
					Proto => 'tcp',
					Timeout => 1 );
    if ($socket) {
	mylog "Connection established to barrier director.";
	$attempts = 0;
	while ($socket->connected) {
	    if (socket_write($socket, "time=" . time . "|type=client|name=" . $settings{'barrier_name'} . "\n")) {
		my $ack = "";
		read_with_timeout($socket, \$ack, $settings{'read_timeout'});
		if ($ack) {
		    chomp($ack);
		    if ($ack =~ /ack (\d+)/) {
			$settings{'peerport'} = $1;
			mylog "Barrier $settings{'barrier_name'} is using port $settings{'peerport'}.";
			last;
		    }
		}
		sleep 3;
	    }
	}
	$socket->shutdown(2);
    } else {
	if (! $attempts) {
	    mylog "Waiting to establish connection to director.";
	}
	$attempts++;
	sleep 3;
    }
}


while ($quit_signal) {
    my $socket = new IO::Socket::INET ( PeerAddr => $settings{'master'},
					PeerPort => $settings{'peerport'},
					Proto => 'tcp',
					Timeout => 1 );

    if ($socket) {
	$attempts = 0;
	mylog "Connection established to barrier master.";

	while ($socket->connected) {
	    if ($state eq "verifying") {
		mylog "Verifying barrier parameters with master.";
		if (socket_write($socket, "time=" . time . "|name=" . $settings{'name'} . "|state=$state|barrier_name=" . $settings{'barrier_name'} . "\n")) {
		    my $ack = "";
		    read_with_timeout($socket, \$ack, $settings{'read_timeout'});
		    if ($ack) {
			chomp($ack);
			if ($ack eq "ack") {
			    $state = "ready";
			} elsif ($ack eq "reject") {
			    # The master is processing a different barrier
			    # right now. Do a read from the socket to wait
			    # for the master to tell the participants of that
			    # barrier to go, then we'll loop around and try
			    # to verify with the server again for this barrier.
			    my $msg = "";
			    read_with_timeout($socket, \$msg, $settings{'read_timeout'});
			    if ($msg) {
				socket_write($socket, "reject\n");
			    }
			}
		    }
		}
	    } elsif ($state eq "ready") {
		mylog "Signaling ready";
		if (socket_write($socket, "time=" . time . "|name=" . $settings{'name'} . "|state=$state\n")) {
		    my $ack = "";
		    read_with_timeout($socket, \$ack, $settings{'read_timeout'});
		    if ($ack) {
			chomp($ack);
			if ($ack eq "ack") {
			    $state = "waiting";
			}
		    }
		}
	    } elsif ($state eq "waiting") {
		mylog "Waiting for go signal.";
		my $msg = "";
		# Different read-timeout value. Because we expect this "wait"
		# to take a while, use half of the barrier-timeout value as
		# the read-timeout value so we don't get flooded with messages
		# about read timeouts.
		read_with_timeout($socket, \$msg, $settings{'timeout'} / 2);
		if ($msg) {
		    chomp($msg);
		    if ($msg eq "go") {
			if (socket_write($socket, "ack\n")) {
			    mylog "Received go signal";
			    $state = "gone";
			}
		    } elsif ($msg eq "timeout") {
			mylog "Received barrier timeout signal from master";
			exit_error "BARRIER TIMED OUT";
		    }
		} else {
		    mylog "Connection dropped";
		    last;
		}
	    } elsif ($state eq "gone") {
		if (socket_write($socket, "time=" . time . "|name=" . $settings{'name'} . "|state=$state\n")) {
		    my $ack = "";
		    read_with_timeout($socket, \$ack, $settings{'read_timeout'});
		    if ($ack) {
			chomp($ack);
			if ($ack eq "ack") {
			    mylog "BARRIER COMPLETED (" . (time - $start_time) . " total seconds elapsed)";
			    $quit_signal = 0;
			    last;
			}
		    }
		}
	    }
	}

	$socket->shutdown(2);
    } else {
	if (! $attempts) {
	    mylog "Waiting to establish connection to master";
	}
	$attempts++;

	sleep 3;
    }
}

exit 0;
