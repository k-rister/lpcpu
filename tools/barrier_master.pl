#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/barrier_master.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


use strict;
use POSIX qw(ceil floor);
use IO::Socket;
use IO::Select;
use autobench::file;
use autobench::time;

my $stdscr;
my $signal_quit = -1;
my $signal_print_status = 0;
# setup a global variable
use vars qw($signal_quit $signal_print_status);
# configure signal handlers
$SIG{INT} = \&signal_trap_quit;
$SIG{TERM} = \&signal_trap_quit;

# define hashes that store all the important data
my %settings = ();
my %message_window = ();
my %info_window = ();
my %participant_window = ();
my %not_ready_window = ();
my %not_gone_window = ();
my %member_status_window = ();

# setup the initial window geometries
init_window(\%message_window, "message", \%settings);
init_window(\%info_window, "info", \%settings);
init_window(\%participant_window, "participant", \%settings);
init_window(\%not_ready_window, "not-ready", \%settings);
init_window(\%not_gone_window, "not-gone", \%settings);
init_window(\%member_status_window, "status", \%settings);

# read the command line arguments
$settings{'read_timeout'} = 5; # Default timeout for reads from the sockets.
parse_args(\@ARGV, \%settings, \%message_window);

if ($settings{'curses'}) {
    eval {
	require Curses;
	Curses->import();
    };

    # setup curses
    $stdscr = initscr();
    config_screen();

    # grab the initial terminal geometry
    getmaxyx($stdscr, $settings{'term-height'}, $settings{'term-width'});

    # repaint the screen
    refresh();
} else {
    $SIG{USR1} = \&signal_status_print;
}

# setup the initial window geometries
setup_window_geometry(\%message_window, "message", \%settings);
setup_window_geometry(\%info_window, "info", \%settings);
setup_window_geometry(\%participant_window, "participant", \%settings);
setup_window_geometry(\%not_ready_window, "not-ready", \%settings);
setup_window_geometry(\%not_gone_window, "not-gone", \%settings);
setup_window_geometry(\%member_status_window, "status", \%settings);

# do the initial setup of the barrier
setup_barrier(\%settings, \%message_window, \%participant_window, \%not_ready_window);

# grab the initial time
my $current_time = time();

my $loop = 1;
while ($loop == 1) {
    if ($signal_quit != -1) {
	window_println(\%message_window, "Received signal SIG" . $signal_quit, \%settings);
	barrier_timeout(\%message_window, \%settings);
    }

    # check if the terminal has resized
    if ($settings{'curses'} && check_term(\%message_window, \%settings)) {
	#window_println(\%message_window, "Redrawing screen", \%settings);

	endwin();
	config_screen();
	doupdate();
	clear($stdscr);
	refresh($stdscr);

	# update the window geometries
	setup_window_geometry(\%message_window, "message", \%settings);
	setup_window_geometry(\%info_window, "info", \%settings);
	setup_window_geometry(\%participant_window, "participant", \%settings);
	setup_window_geometry(\%not_ready_window, "not-ready", \%settings);
	setup_window_geometry(\%not_gone_window, "not-gone", \%settings);
	setup_window_geometry(\%member_status_window, "status", \%settings);

	# repopulate the participant window since it's size has changed
	# this window does not get updated regularly, so the buffer may have
	# been trimmed necessitating a repopulation if the window is now larger
	# the easiest way to empty the buffer is to delete and recreate it
	my $key;
	delete $participant_window{'display-buffer'};
	@{$participant_window{'display-buffer'}} = ();
	foreach $key (sort keys %{$settings{'members'}}) {
	    window_println(\%participant_window, $key, \%settings);
	}
    }

    if ($settings{'curses'}) {
	# display generic barrier information
	display_info(\%settings, \%info_window, $current_time);

	# display generic member status information
	display_member_status(\%settings, \%member_status_window);
    } else {
	# display updated progress
	non_curses_progress(\%settings, $current_time, \%message_window);

	# print the current barrier status if requested by the user by sending SIGUSR1 to this process
	if ($signal_print_status) {
	    $signal_print_status = 0;
	    non_curses_print_barrier_status(\%settings, $current_time, \%message_window);
	}
    }

    # check the status of the barrier members
    check_members(\%settings, \%message_window, \%not_ready_window, \%not_gone_window, $current_time);

    # check if the barrier has been completed
    if (exists($settings{'done'})) {
	normal_exit(\%settings);
    }

    # sleep
    ($settings{'select-set'}) = IO::Select->select($settings{'socket-read-set'}, undef, undef, $settings{'check-interval'});
    $current_time = time();

    # check if the barrier has timed out
    if ($current_time >= $settings{'end-time'}) {
	$loop = 0;
	barrier_timeout(\%message_window, $current_time, \%settings);
    }
}

normal_exit(\%settings);

################################################################################

# setup some curses defaults
sub config_screen {
    curs_set(0);
    clear();
    noecho();
    cbreak();
    keypad(1);
}

# check if the terminal has resized
sub check_term {
    my $msg_window = shift;
    my $settings = shift;
    my $current_x;
    my $current_y;

    # Get the window's current size.
    getmaxyx($stdscr, $current_y, $current_x);

    if (($current_x != $$settings{'term-width'}) || ($current_y != $$settings{'term-height'})) {
	if (exists($$settings{'debug-fh'})) {
	    window_println($msg_window, "Terminal has resized [${current_x}x${current_y} was [$$settings{'term-width'}x$$settings{'term-height'}]", $settings);
	}
	$$settings{'term-width'} = $current_x;
	$$settings{'term-height'} = $current_y;
	return 1;
    } else {
	return 0;
    }
}

# firewall command assumptions:
#   1) usage of iptables (isn't there something "new" coming?)
#      a) use of INPUT chain
#      b) use of ACCEPT chain
#   2) user executing Autobench has suitable privileges to modify the firewall rules (usually root so hopefully not an issue)

sub open_firewall_port {
    my $settings = shift;
    my $window = shift;

    if ($$settings{'firewall'} eq "iptables") {
	# iptables --insert INPUT --protocol tcp --dport <port> --jump ACCEPT

	my $port = $$settings{'socket'}->sockport();
	my $cmd_output = `iptables --insert INPUT --protocol tcp --dport $port --jump ACCEPT`;
	my $ret_val = $? >> 8;

	if ($ret_val != 0) {
	    fatal_error("Could not open firewall port $port through iptables.  RC=$ret_val [$cmd_output]", $settings);
	} else {
	    window_println($window, "Opened port $port through iptables firewall", $settings);
	}
    }
}

sub close_firewall_port {
    my $settings = shift;
    my $window = shift;

    if ($$settings{'firewall'} eq "iptables") {
	# iptables --delete INPUT --protocol tcp --dport <port> --jump ACCEPT

	my $port = $$settings{'socket'}->sockport();
	my $cmd_output = `iptables --delete INPUT --protocol tcp --dport $port --jump ACCEPT`;
	my $ret_val = $? >> 8;

	if ($ret_val != 0) {
	    fatal_error("Could not close firewall port $port through iptables.  RC=$ret_val [$cmd_output]", $settings);
	} else {
	    window_println($window, "Closed port $port through iptables firewall", $settings);
	}
    }
}

sub director_close_barrier {
    my $settings = shift;
    if ($$settings{'director_socket'} && $$settings{'director_socket'}->connected()) {
	my $director_socket = $$settings{'director_socket'};
	if (socket_write($director_socket, "time=" . time() . "|type=master|name=" . $$settings{'name'} . "|cmd=close|uuid=" . $$settings{'director_uuid'} . "\n")) {
	    my $ack = "";
	    read_with_timeout($director_socket, \$ack, $$settings{'read_timeout'});
	    if ($ack) {
		chomp($ack);
		if ($ack =~ /ack/) {
		    $$settings{'director_socket'}->shutdown(2);
		    delete($$settings{'director_socket'});
		}
	    }
	}
    }
}

# trap quit signals so they can be handled appropriately
sub signal_trap_quit {
    my $signame = shift;
    $signal_quit = $signame;
}

# trap a USR1 signal sent to this program as a request to dump the barrier status
# this is used when in non-curses mode by a user wanting to know the current state of the barrier
sub signal_status_print {
    $signal_print_status = 1;
}

# exit gracefully upon barrier timeout
sub barrier_timeout {
    my $msg_window = shift;
    my $current_time = shift;
    my $settings = shift;

    my @writeable = $settings{'socket-read-set'}->can_write(1);
    my $write_socket;
    if (@writeable) {
	window_println($msg_window, "Signaling available clients that timeout has occurred", $settings);
    }
    foreach $write_socket (@writeable) {
	socket_write($write_socket, "timeout\n");
    }

    director_close_barrier($settings);
    close_firewall_port($settings, $msg_window);
    non_curses_print_barrier_status($settings, $current_time, $msg_window);
    window_println($msg_window, "BARRIER TIMED OUT", $settings);
    fatal_error("BARRIER TIMED OUT", $settings);
}

sub ack {
    my $socket = shift;
    my $max_attempts = shift || 3;
    my $attempts = 0;

    while ($attempts < $max_attempts) {
	if (socket_write($socket, "ack\n")) {
	    return 1;
	}
	$attempts++;
    }

    return 0;
}

# check the status of the barrier members
sub check_members {
    my $settings = shift;
    my $msg_window = shift;
    my $not_ready_window = shift;
    my $not_gone_window = shift;
    my $current_time = shift;

    if ($$settings{'curses'}) {
	# Clear the not ready or not gone windows
	if (! exists($$settings{'go-signaled'})) {
	    delete $$not_ready_window{'display-buffer'};
	    @{$$not_ready_window{'display-buffer'}} = ();
	    clear_window($not_ready_window);
	} else {
	    delete $$not_gone_window{'display-buffer'};
	    @{$$not_gone_window{'display-buffer'}} = ();
	    if (! exists($$not_gone_window{'obj'})) {
		create_window($not_gone_window);
	    } else {
		clear_window($not_gone_window);
	    }
	}
    }

    my %member_signals;
    my $socket;
    foreach $socket (@{$$settings{'select-set'}}) {
	if ($socket == $$settings{'socket'}) {
	    window_println($msg_window, "Accepted new client connection", $settings);
	    my $new_connection = $socket->accept();
	    $$settings{'socket-read-set'}->add($new_connection);
	} else {
	    my $msg = "";
	    read_with_timeout($socket, \$msg, $$settings{'read_timeout'});

	    if ($msg) {
		chomp($msg);
		if (exists($$settings{'debug-fh'})) {
		    window_println($msg_window, "Received msg=[$msg]", $settings);
		}
		if ($msg =~ /state=verifying/) {
		    # Check that this client is connecting for the correct barrier.
		    my @fields = split('\|', $msg);
		    my @name = split('=', $fields[1]);
		    my @barrier_name = split('=', $fields[3]);
		    if ($barrier_name[1] eq $$settings{'name'} &&
			exists($$settings{'members'}{$name[1]})) {
			if (!ack($socket)) {
			    window_println($msg_window, "Error sending barrier-verification ack to $name[1]", $settings);
			}
		    } else {
			window_println($msg_window, "Rejected client connection from $name[1] for barrier $barrier_name[1]", $settings);
			socket_write($socket, "reject\n");
		    }
		} elsif (($msg =~ /state=ready/) || ($msg =~ /state=gone/)) {
		    my @fields = split('\|', $msg);
		    my @name = split('=', $fields[1]);
		    my @state = split('=', $fields[2]);
		    if (ack($socket)) {
			$member_signals{$name[1]} = $state[1];
		    } else {
			window_println($msg_window, "Error sending '$state[1]' ack to $name[1]", $settings);
		    }
		}
	    } else {
		window_println($msg_window, "Lost client connection", $settings);
		$$settings{'socket-read-set'}->remove($socket);
		close($socket);
	    }
	}
    }

    my $key;
    foreach $key (sort keys %{$$settings{'members'}}) {
	if ($$settings{'members'}{$key} == 2) {
	    # nothing to do here, this member is already gone
	} elsif ($$settings{'members'}{$key} == 1) {
	    # this member is already ready
	    if (exists($member_signals{$key}) && ($member_signals{$key} eq "gone")) {
		$$settings{'gone-count'}++;
		$$settings{'members'}{$key} = 2;
		window_println($msg_window, "Received gone signal from $key", $settings);
	    } else {
		if (exists($$settings{'go-signaled'}) && $$settings{'curses'}) {
		    # track in the not-gone window
		    window_println($not_gone_window, $key, $settings);
		}
	    }
	} elsif ($$settings{'members'}{$key} == 0) {
	    # waiting for initial signal from this member
	    if (exists($member_signals{$key}) && ($member_signals{$key} eq "ready")) {
		$$settings{'ready-count'}++;
		$$settings{'members'}{$key} = 1;
		window_println($msg_window, "Received ready signal from $key", $settings);
	    } else {
		if (! exists($$settings{'go-signaled'}) && $$settings{'curses'}) {
		    # track in the not-ready window
		    window_println($not_ready_window, $key, $settings);
		}
	    }
	}
    }

    if ($$settings{'ready-count'} == keys(%{$$settings{'members'}})) {
	# all members are in the ready state, create go signal if not already done
	if (! exists($$settings{'go-signaled'})) {
	    $$settings{'go-signaled'} = 0;
	}

	# signal the members to go
	if ($$settings{'go-signaled'} < keys(%{$$settings{'members'}})) {
	    my @writeable = $$settings{'socket-read-set'}->can_write(1);
	    my $write_socket;
	    foreach $write_socket (@writeable) {
		if (socket_write($write_socket, "go\n")) {
		    my $ack = "";
		    read_with_timeout($write_socket, \$ack, $$settings{'read_timeout'});
		    if ($ack) {
			chomp($ack);
			if ($ack eq "ack") {
			    $$settings{'go-signaled'}++;
			}
		    }
		}
	    }

	    window_println($msg_window, "Created go signal", $settings);

	    # shorten the check interval, things should move quickly from here on out
	    $$settings{'check-interval'} = 0.25;
	}
    }

    if ($$settings{'gone-count'} == keys(%{$$settings{'members'}})) {
	# all members are gone

	if (! exists($$settings{'done'})) {
	    $$settings{'done'} = 1;
	    director_close_barrier($settings);
	    close_firewall_port($settings, $msg_window);
	    window_println($msg_window, "BARRIER COMPLETED (" . ($current_time - $$settings{'start-time'}) . " total seconds elapsed)", $settings);
	}
    }

    # debug output
    if (exists($$settings{'debug-fh'})) {
	print { $$settings{'debug-fh'} } "If you want to see the contents of the \$settings data structure you must uncomment the following 2 lines.\n";
	#use Data::Dumper;
	#print { $$settings{'debug-fh'} } Dumper $settings;
    }
}

# display a progress indicator for non-curses mode
sub non_curses_progress {
    my $settings = shift;
    my $current_time = shift;
    my $msg_window = shift;
    my $not_ready_count = keys(%{$$settings{'members'}}) - $$settings{'ready-count'};

    my $percent_time_passed = floor(($current_time - $$settings{'start-time'}) / ($$settings{'end-time'} - $$settings{'start-time'}) * 100);

    if ($percent_time_passed >= $$settings{'next-status'}) {
	window_println($msg_window, "$percent_time_passed\% Barrier Time Elapsed [Ready members = " . $$settings{'ready-count'} . "/" . keys(%{$$settings{'members'}}) . " | Not ready members = " . $not_ready_count . "/" . keys(%{$$settings{'members'}}) . "]", $settings);
	$$settings{'next-status'} += $$settings{'status-step-size'};
    }
}

# display the current barrier status when not in curses mode
sub non_curses_print_barrier_status {
    my $settings = shift;
    my $current_time = shift;
    my $msg_window = shift;
    my $not_ready_count = keys(%{$$settings{'members'}}) - $$settings{'ready-count'};

    my $percent_time_passed = floor(($current_time - $$settings{'start-time'}) / ($$settings{'end-time'} - $$settings{'start-time'}) * 100);

    window_println($msg_window, "", $settings);
    window_println($msg_window, "Barrier status for '" . $$settings{'name'} . "'", $settings);
    window_println($msg_window, "$percent_time_passed\% Barrier Time Elapsed", $settings);
    window_println($msg_window, "Barrier will timeout in " . ($$settings{'end-time'} - $current_time) . " seconds", $settings);

    my $ready_members = "";
    my $not_ready_members = "";
    my $gone_members = "";
    my $key;

    foreach $key (sort keys %{$$settings{'members'}}) {
	if ($$settings{'members'}{$key} == 2) {
	    $gone_members .= "$key ";
	} elsif ($$settings{'members'}{$key} == 1) {
	    $ready_members .= "$key ";
	} elsif ($$settings{'members'}{$key} == 0) {
	    $not_ready_members .= "$key ";
	}
    }

    window_println($msg_window, "Not ready members : " . $not_ready_count . "/" . keys(%{$$settings{'members'}}) . " : $not_ready_members", $settings);
    window_println($msg_window, "Ready members : " . $$settings{'ready-count'} . "/" . keys(%{$$settings{'members'}}) . " : $ready_members", $settings);
    window_println($msg_window, "Gone members : " . $$settings{'gone-count'} . "/" . keys(%{$$settings{'members'}}) . " : $gone_members", $settings);
    window_println($msg_window, "", $settings);
}

# display the generic barrier info
sub display_info {
    my $settings = shift;
    my $window = shift;
    my $current_time = shift;

    # the info window buffer is a bit different than other windows
    # the entire buffer is replaced everytime, its easiest to just delete the
    # buffer and re-initialize
    delete $$window{'display-buffer'};
    @{$$window{'display-buffer'}} = ();

    window_println($window, sprintf("%-20s%s", "Barrier Name:", $$settings{'name'}), $settings);
    window_println($window, sprintf("%-20s%s", "Timeout Length:", $$settings{'timeout'}), $settings);

    window_println($window, sprintf("%-20s%s (%s\%)", "Time Waited:",
				    $current_time - $$settings{'start-time'},
				    floor(($current_time - $$settings{'start-time'}) / ($$settings{'end-time'} - $$settings{'start-time'}) * 100)),
		   $settings);

    window_println($window, sprintf("%-20s%s", "Start Time:", $$settings{'start-time_hr'}), $settings);
    window_println($window, sprintf("%-20s%s", "Timeout time:", $$settings{'end-time_hr'}), $settings);
    window_println($window, sprintf("%-20s%s", "Current Time:", timestamp_format($current_time)), $settings);
}

# display the generic member status info
sub display_member_status {
    my $settings = shift;
    my $window = shift;
    my $not_ready_count = keys(%{$$settings{'members'}}) - $$settings{'ready-count'};
    my $not_gone_count = keys(%{$$settings{'members'}}) - $$settings{'gone-count'};

    # the info window buffer is a bit different than other windows
    # the entire buffer is replaced everytime, its easiest to just delete the
    # buffer and re-initialize
    delete $$window{'display-buffer'};
    @{$$window{'display-buffer'}} = ();

    window_println($window, sprintf("%-20s%d", "Total Members:", (keys(%{$$settings{'members'}}) + 0) ), $settings);
    window_println($window, sprintf("%-20s%d", "Not Ready Members:", $not_ready_count), $settings);
    window_println($window, sprintf("%-20s%s", "Ready Members:", $$settings{'ready-count'}), $settings);
    window_println($window, sprintf("%-20s%d", "Not Gone Members:", $not_gone_count), $settings);
    window_println($window, sprintf("%-20s%s", "Gone Members:", $$settings{'gone-count'}), $settings);
}

# initialize the barrier
sub setup_barrier {
    my $settings = shift;
    my $msg_window = shift;
    my $part_window = shift;
    my $not_ready_window = shift;

    $$settings{'start-time'} = time();
    $$settings{'start-time_hr'} = timestamp_format($$settings{'start-time'});
    $$settings{'end-time'} = $$settings{'start-time'} + ($$settings{'timeout'} + 0);
    $$settings{'end-time_hr'} = timestamp_format($$settings{'end-time'});
    window_println($msg_window, "Starting barrier timing at " . $$settings{'start-time_hr'} . "/" . $$settings{'start-time'}, $settings);
    window_println($msg_window, "Barrier will timeout at " . $$settings{'end-time_hr'} . "/" . $$settings{'end-time'}, $settings);

    # The OS will pick a port at random for us to use. We'll connect
    # to the barrier director and give it that port number.
    $$settings{'socket'} = new IO::Socket::INET ( Proto => 'tcp',
						  Listen => SOMAXCONN,
						  Reuse => 1,
						  Timeout => 1 );

    if (!$$settings{'socket'}) {
	my $msg = "Could not create socket: $!";
	window_println($msg_window, $msg, $settings);
	fatal_error($msg);
    }

    my $attempts = 0;
    while (!exists($$settings{'director_uuid'})) {
	$$settings{'director_socket'} = new IO::Socket::INET( Proto => 'tcp',
								PeerAddr => 'localhost',
								PeerPort => 1111,
								Reuse => 1,
								Timeout => 1 );
	if (!$$settings{'director_socket'}) {
	    $attempts++;
	    sleep 3;
	} else {
	    my $director_socket = $$settings{'director_socket'};
	    window_println($msg_window, "Registering barrier $$settings{'name'} on port " . $$settings{'socket'}->sockport(), $settings);
	    if (socket_write($director_socket, "time=" . time . "|type=master|name=" . $$settings{'name'} . "|cmd=new|port=" .
			     $$settings{'socket'}->sockport() . "|timeout=" . $$settings{'end-time'} . "|pid=" . $$ . "\n")) {
		my $msg = "";
		read_with_timeout($director_socket, \$msg, $$settings{'read_timeout'});
		if ($msg) {
		    chomp($msg);
		    if ($msg =~ /ack (\w+)/) {
			$$settings{'director_uuid'} = $1;
			window_println($msg_window, "Obtained UUID $$settings{'director_uuid'} for barrier $$settings{'name'}.", $settings);

			open_firewall_port($settings, $msg_window);
		    } else {
			window_println($msg_window, "Invalid message from director: $msg", $settings);
			$attempts++;
			$$settings{'director_socket'}->shutdown(2);
			sleep 3;
		    }
		} else {
		    window_println($msg_window, "Null message from director socket", $settings);
		    $attempts++;
		    $$settings{'director_socket'}->shutdown(2);
		    sleep 3;
		}
	    } else {
		window_println($msg_window, "Write to director socket failed when attempting to register barrier $$settings{'name'}", $settings);
		$attempts++;
		$$settings{'director_socket'}->shutdown(2);
		sleep 3;
	    }
	}

	if ($attempts > 5) {
	    my $msg = "Could not negotiate with barrier director: $!";
	    window_println($msg_window, $msg, $settings);
	    fatal_error($msg);
	}
    }

    $$settings{'socket-read-set'} = new IO::Select();
    $$settings{'socket-read-set'}->add($$settings{'socket'});

    if ($$settings{'curses'}) {
	# populate the participant window
	my $key;
	foreach $key (sort keys %{$$settings{'members'}}) {
	    window_println($part_window, $key, $settings);
	    window_println($not_ready_window, $key, $settings);
	}
    } else {
	# must be less than 100 :)
	$$settings{'status-steps'} = 10;

	$$settings{'status-step-size'} = floor(100 / $$settings{'status-steps'});
	$$settings{'next-status'} = $$settings{'status-step-size'};
    }

    # check for signals every 1 second until go signal is sent
    $$settings{'check-interval'} = 1;

    # init some variables
    $$settings{'ready-count'} = 0;
    $$settings{'gone-count'} = 0;
}

# initialize a window
sub init_window {
    my $window = shift;
    my $type = shift;
    my $settings = shift;

    $$window{'id'} = $type;

    # initialize queue
    @{$$window{'display-buffer'}} = ();

    # plug the queue
    $$window{'queue'} = "plugged";
}

# initialize a window's geometry
sub setup_window_geometry {
    my $window = shift;
    my $type = shift;
    my $settings = shift;
    my $draw_window = 1;

    if (! $$settings{'curses'}) {
	$$window{'queue'} = "unplugged";
	return;
    }

    if ($$settings{'term-width'} < 80) {
	$$settings{'term-width'} = 80;
    }

    if ($$settings{'term-height'} < 24) {
	$$settings{'term-height'} = 24;
    }

    my $vertical_border = 0;
    my $horizontal_border = 1;
    my $row1_column_width = floor(($$settings{'term-width'} - 3 * $horizontal_border) / 2);
    my $row2_column_width = floor(($$settings{'term-width'} - 3 * $horizontal_border) / 2);
    my $total_width = 2 * $row2_column_width + 1 * $horizontal_border;

    my $message_window_height = 6;
    my $row1_window_height = 8;

    # define the geometry of the specified window
    if ("$type" eq "info") {
	$$window{'height'} = $row1_window_height;
	$$window{'width'} = $row1_column_width;
	$$window{'starty'} = $vertical_border;
	$$window{'startx'} = $horizontal_border;
	$$window{'label'} = " General Information ";
    } elsif ("$type" eq "participant") {
	$$window{'height'} = $$settings{'term-height'} - $row1_window_height - $message_window_height - 4 * $vertical_border;
	$$window{'width'} = $row2_column_width;
	$$window{'starty'} = 2 * $vertical_border + $row1_window_height;
	$$window{'startx'} = $horizontal_border;
	$$window{'label'} = " Members ";
    } elsif ("$type" eq "not-ready") {
	$$window{'height'} = $$settings{'term-height'} - $row1_window_height - $message_window_height - 4 * $vertical_border;
	$$window{'width'} = $row2_column_width;
	$$window{'starty'} = 2 * $vertical_border + $row1_window_height;
	$$window{'startx'} = $row2_column_width + 2 * $horizontal_border;
	$$window{'label'} = " Not Ready Members ";
	if (exists($$settings{'go-signaled'})) {
	    $draw_window = 0;
	}
    } elsif ("$type" eq "not-gone") {
	$$window{'height'} = $$settings{'term-height'} - $row1_window_height - $message_window_height - 4 * $vertical_border;
	$$window{'width'} = $row2_column_width;
	$$window{'starty'} = 2 * $vertical_border + $row1_window_height;
	$$window{'startx'} = $row2_column_width + 2 * $horizontal_border;
	$$window{'label'} = " Not Gone Members ";
	if (! exists($$settings{'go-signaled'})) {
	    $draw_window = 0;
	}
    } elsif ("$type" eq "message") {
	$$window{'height'} = 6;
	$$window{'width'} = $horizontal_border + 2 * $row1_column_width;
	$$window{'starty'} = $$settings{'term-height'} - $$window{'height'} - $vertical_border;
	$$window{'startx'} = $horizontal_border;
	$$window{'label'} = " Messages ";
    } elsif ("$type" eq "status") {
	$$window{'height'} = $row1_window_height;
	$$window{'width'} = $row1_column_width;
	$$window{'starty'} = $vertical_border;
	$$window{'startx'} = $row1_column_width + 2 * $horizontal_border;
	$$window{'label'} = " Member Status ";
    }

    # if this is the first initialization of a window then we just draw it
    # otherwise we draw the window, trim the buffer (if required), and reprint the buffer
    if ($draw_window) {
	if (! exists($$window{'obj'})) {
	    create_window($window);

	    if ($$window{'queue'} eq "plugged") {
		$$window{'queue'} = "unplugged";
		window_print_buffer($window);
	    }
	} else {
	    # move the window to the new x,y position
	    mvwin($$window{'obj'}, $$window{'starty'}, $$window{'startx'});
	    # resize the window to the new dimensions
	    resize($$window{'obj'}, $$window{'height'}, $$window{'width'});
	    erase($$window{'obj'});
	    draw_window($window);
	    trim_buffer($window);
	    window_print_buffer($window);
	}
    }
}

# create a new window
sub create_window {
    my $window = shift;

    if (exists $$window{'obj'}) {
	delwin($$window{'obj'});
    }

    $$window{'obj'} = newwin($$window{'height'}, $$window{'width'}, $$window{'starty'}, $$window{'startx'});

    draw_window($window);
}

# draw a blank window with a border and label
sub draw_window {
    my $window = shift;

    box($$window{'obj'}, 0, 0);

    addstr($$window{'obj'}, 0, 5, $$window{'label'});

    refresh($$window{'obj'});
}

# add a string to a buffer then call the window/buffer print function
sub window_println {
    my $window = shift;
    my $text = shift;
    my $settings = shift;

    # if the destination window is the message window prepend a timestamp to the string
    if ($$window{'id'} eq "message") {
	my $date = timestamp_format(time());
	$text = "[$date] $text";
    }

    # debug output
    if ((exists($$settings{'debug-fh'})) && ($$window{'id'} eq "message")) {
	print { $$settings{'debug-fh'} } "$text\n";
    }

    if ((exists($$settings{'log-file'})) && ($$window{'id'} eq "message")) {
	# open and close to properly write to Autobench named pipe
	# do an append operation in case not writing to named pipe
	fifo_write($$settings{'log-file'}, "$text");
    }

    if ($$settings{'curses'} || ! exists($$settings{'curses'})) {
	# the display size is the height of the window minus 2 (1 for the top border and 1 for bottom border)
	# if the buffer length is equal then we need to pop an item before adding a new one
	if (($$window{'queue'} eq "unplugged") &&
	    (@{$$window{'display-buffer'}} >= ($$window{'height'} - 2))) {
	    while (@{$$window{'display-buffer'}} >= ($$window{'height'} - 2)) {
		my $foo = pop @{$$window{'display-buffer'}};
	    }
	}

	# enqueue new message
	unshift(@{$$window{'display-buffer'}}, $text);

	# print the buffer to the window
	window_print_buffer($window);
    } else {
	if (@{$$window{'display-buffer'}}) {
	    # clear any existing buffer contents

	    for (my $x=0; $x<@{$$window{'display-buffer'}}; $x++) {
		print $$window{'display-buffer'}[$x] . "\n";
	    }

	    @{$$window{'display-buffer'}} = ();
	}

	# print the message
	print "$text\n";
    }
}

# shorten a buffer if the window size has shrunk
sub trim_buffer {
    my $window = shift;

    while (@{$$window{'display-buffer'}} > ($$window{'height'} - 2)) {
	my $foo = pop @{$$window{'display-buffer'}};
    }
}

# print a buffer to its window
sub window_print_buffer {
    my $window = shift;

    if ($$window{'queue'} eq "unplugged") {
	for (my $x=@{$$window{'display-buffer'}}, my $line=1; $x>0; $x--, $line++) {
	    # padding the string with enough spaces to clear the line, subtract 3,
	    # 2 from the width for the borders as above, and 1 since we are printing at horizontal offset 2
	    my $print_string = sprintf("%-" . ($$window{'width'} - 3) . "s", $$window{'display-buffer'}[$x - 1]);
	    # chop the string if it is too long
	    $print_string = substr($print_string, 0, $$window{'width'} - 3);
	    addstr($$window{'obj'}, $line, 2, $print_string);
	}

	refresh($$window{'obj'});
    }
}

# clear the contents of the window
sub clear_window {
    my $window = shift;

    # print a number of lines equal to the height of the window - 2 (for the top and bottom borders)
    # clearing each line inside the window
    for (my $x=1; $x<=($$window{'height'} - 2); $x++) {
	# padding the string with enough spaces to clear the line, subtract 3,
	# 2 from the width for the borders as above, and 1 since we are printing at horizontal offset 2
	my $print_string = sprintf("%-" . ($$window{'width'} - 3) . "s", "");
	addstr($$window{'obj'}, $x, 2, $print_string);
    }
}

# parse the command line arguments
# ensure that required args are specified
sub parse_args {
    my $ARGS = shift;
    my $settings = shift;
    my $window = shift;

    for (my $x=0; $x<@{$ARGS}; $x++) {
	$$ARGS[$x] =~ m/(.*)=(.*)/;
	$$settings{$1} = $2;
	window_println($window, "Found cli argument '" . $1 . "' with value '" . $2 . "'", $settings);
    }

    if (exists($$settings{'debug-file'})) {
	open($$settings{'debug-fh'}, ">$$settings{'debug-file'}");
    }

    if (! exists($$settings{'timeout'})) {
	fatal_error("You must specify the timeout length", $settings);
    }

    if (! exists($$settings{'name'})) {
	fatal_error("You must specify the barrier name", $settings);
    }

    if (! exists($$settings{'firewall'})) {
	$$settings{'firewall'} = "none";
    } else {
	if (!($$settings{'firewall'} eq "iptables") &&
	    !($$settings{'firewall'} eq "none")) {
	    fatal_error("You must specify a supported firewall type [iptables|none] (not '$$settings{'firewall'})", $settings);
	}
    }

    if (exists($$settings{'mode'}) && ($$settings{'mode'} eq "no-curses")) {
	# disable output buffering
	$|++;

	$$settings{'curses'} = 0;
    } else {
	$$settings{'curses'} = 1;
    }

    if (!exists($$settings{'members'})) {
	fatal_error("You must specify the barrier members", $settings);
    } else {
	# convert the barrier members from a string list to a hash
	my @members = split(' ', $$settings{'members'});
	delete $$settings{'members'};
	$$settings{'members'} = {};
	for (my $x=0; $x<@members; $x++) {
	    $$settings{'members'}{$members[$x]} = 0;
	}
    }
}

# exit fatally
sub fatal_error {
    my $msg = shift;
    my $settings = shift;

    print STDERR "ERROR: $msg\n";

    if (exists($$settings{'log-file'})) {
	# open and close to properly write to Autobench named pipe
	# do an append operation in case not writing to named pipe
	fifo_write($$settings{'log-file'}, "ERROR: $msg", 1);
    }

    exit_error($settings);
}

sub cleanup {
    my $settings = shift;

    if (exists($$settings{'socket'})) {
	$$settings{'socket'}->shutdown(2);
    }
    if (exists($$settings{'director_socket'})) {
	$$settings{'director_socket'}->shutdown(2);
    }

    if (exists($$settings{'debug-fh'})) {
	close $$settings{'debug-fh'};
    }

    if ($$settings{'curses'}) {
	endwin();
	print "\n";
    }
}

# exit in error state but gracefully
sub exit_error {
    my $settings = shift;
    cleanup($settings);
    # 86 is the Autobench code for fatal error
    exit 86;
}

# usual exit
sub normal_exit {
    my $settings = shift;
    cleanup($settings);
    exit 0;
}
