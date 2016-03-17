
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/file.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# Perl module for routines related to file I/O operations.

package autobench::file;

use strict;
use warnings;
use Fcntl;
use Errno;
use autobench::log;
use Socket qw( MSG_NOSIGNAL );

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT   = qw( &read_file
			&write_file
			&append_to_file
			&grep_file
			&read_with_timeout
			&fifo_write
			&socket_write );
}

# read_file
#
# Open and read the entire contents of a file.
#
# Arg1: The file to read.
# Arg2: Optional. Set to 1 to skip chomp'ing each line of the file. Default
#       is to chomp all lines.
#
# Returns: An array of the file's contents. Each line of the file will be a
#          separate entry in the array. Any empty array is returned if the
#          file is empty or if there are any errors while reading the file.
sub read_file($; $)
{
	my $filename = shift;
	my $dont_chomp = shift || 0;
	my $rc = open(my $fp, $filename);
	if (!$rc) {
		error("Cannot open file $filename.");
		return ();
	}
	my @contents = <$fp>;
	if (!$dont_chomp) {
		chomp(@contents);
	}
	close($fp);
	return @contents;
}

# write_file
#
# Arg1: The name of the file to create.
# Arg2: Array of data to write to the file.
#
# Returns: 0 for success, Non-zero for failure.
sub write_file($ @)
{
	my $filename = shift;
	my $rc = open(my $fp, "> $filename");
	if (!$rc) {
		error("Cannot write to file $filename.");
		return 1;
	}
	$rc = print $fp (@_);
	close($fp);
	return ($rc ? 0 : 2);
}

# append_to_file
#
# Arg1: The name of the file to append to.
# Arg2: Array of data to write to the file.
#
# Returns: 0 for success, Non-zero for failure.
sub append_to_file($ @)
{
	my $filename = shift;
	my $rc = open(my $fp, ">> $filename");
	if (!$rc) {
		error("Cannot append to file $filename.");
		return 1;
	}
	$rc = print $fp (@_);
	close($fp);
	return ($rc ? 0 : 2);
}

# grep_file
#
# Arg1: Pattern to grep for.
# Arg2: Name of the file to grep in.
#
# Returns: An array of lines from the file that match the pattern.
sub grep_file($ $)
{
	my $pattern = shift;
	my $filename = shift;
	my @contents = read_file($filename);
	return grep(/$pattern/, @contents);
}

# read_with_timeout
#
# Perform a read with a specified timeout. Do not call this routine if/while
# your script has an "alarm" function registered, since a process can only use
# one alarm at a time.
#
# Arg1: File handle
# Arg2: Reference to a scalar or an array where the read data will be stored.
# Arg3: Timeout, in seconds.
#
# Returns: 1 for success, 0 for failure.
sub read_with_timeout($ $ $)
{
	my $fp = shift;
	my $data = shift;
	my $timeout = shift;
	my $rc = 1;

	eval {
		local $SIG{ALRM} = sub { die("Read timed out after $timeout seconds.\n"); };
		alarm $timeout;

		if (ref($data) eq "SCALAR") {
			$$data = <$fp>;
		} elsif (ref($data) eq "ARRAY") {
			@$data = <$fp>;
		} else {
			error("Invalid reference type: ", ref($data));
			$rc = 0;
		}

		alarm 0;
	};

	if ($@) {
		error($@);
		$rc = 0;
	}

	return $rc;
}

sub fifo_write($ $; $)
{
	my $filename = shift;
	my $msg = shift;
	my $non_blocking = shift || 0;
	my $rc = 1;

	eval {
		local $SIG{PIPE} = sub { die("Error writing to pipe $filename: $msg\n"); };
		my $fp;
		if ($non_blocking) {
			# Need to use sysopen(), since Perl's open() call
			# has no way of specifying non-blocking.
			my $rc2 = sysopen($fp, $filename, O_WRONLY|O_NONBLOCK);
			if (!$rc2 && $!) {
				if ($!{ENXIO}) {
					# No process has the pipe open for
					# reading, so no need to write anything.
					return 0;
				}
				die("Error opening pipe in non-blocking mode: $filename: errno=$!: $msg\n");
			}
		} else {
			open($fp, ">>$filename") || die("Error opening pipe $filename: $msg\n");
		}
		print $fp ("$msg\n");
		close($fp);
	};

	if ($@) {
		error($@);
		$rc = 0;
	}

	return $rc;
}

# returns true(1) on success (the entire message is transmitted) and false(0) otherwise
sub socket_write($ $)
{
	my $socket = shift;
	my $msg = shift;
	my $rc = 1;

	eval {
	    local $SIG{PIPE} = sub { die("Error writing to socket (received SIGPIPE): $msg\n"); };

	    my $ret = $socket->send($msg, MSG_NOSIGNAL);
	    if ($ret) {
		if ($ret != length($msg)) {
		    die("Error writing to socket (partial transmit): $msg\n");
		}
	    } else {
		die("Error writing to socket (send failed): $msg\n");
	    }
	};

	if ($@) {
	    error($@);
	    $rc = 0;
	}

	return $rc;
}

END { }

1;
