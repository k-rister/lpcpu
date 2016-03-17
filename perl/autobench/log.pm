
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/log.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module with some simple logging routines.

package autobench::log;

use strict;
use warnings;
use File::Basename;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT = qw( &log
			&error
			&warning
			&debug
			&usage
		    );
}

sub get_logfile()
{
	my $logfile;

	if (defined($ENV{"LOGFILE"})) {
		$logfile = $ENV{"LOGFILE"};
	} elsif (defined($ENV{"LOGDIR"})) {
		$logfile = "$ENV{'LOGDIR'}/logfile";
	} elsif (defined($ENV{"AUTODIR"})) {
		$logfile = "$ENV{'AUTODIR'}/logs/logfile";
	} else {
		$logfile = "/autobench/logs/logfile";
	}

	return $logfile;
}

sub get_timestamp()
{
	my $stamp = `date +%Y%m%d-%H:%M:%S.%N`;
	chomp($stamp);
	return $stamp;
}

sub append_to_log(@)
{
	my $logfile = get_logfile();
	if (-f $logfile) {
		open(my $fp, ">> $logfile") || return;
		print $fp ("[", get_timestamp(), "] ", @_);
		close($fp);
	}
}

sub log(@)
{
	my $function_name = "";
	if ($ENV{'AUTOBENCH_DEBUG'}) {
		$function_name = (caller(1))[3] . ": ";
	}
	print($function_name, @_, "\n");
	append_to_log($function_name, @_, "\n");
}

sub error(@)
{
	my $function_name = "";
	if ($ENV{'AUTOBENCH_DEBUG'}) {
		$function_name = (caller(1))[3] . ": ";
	}
	print STDERR ("ERROR: ", $function_name, @_, "\n");
	append_to_log("ERROR: ", $function_name, @_, "\n");
}

sub warning(@)
{
	my $function_name = "";
	if ($ENV{'AUTOBENCH_DEBUG'}) {
		$function_name = (caller(1))[3] . ": ";
	}
	print STDERR ("WARNING: ", $function_name, @_, "\n");
	append_to_log("WARNING: ", $function_name, @_, "\n");
}

sub debug(@)
{
	my $function_name = "";
	if ($ENV{'AUTOBENCH_DEBUG'}) {
		$function_name = (caller(1))[3] . ": ";
	}
	print STDERR ("DEBUG: ", $function_name, @_, "\n");
	append_to_log("DEBUG: ", $function_name, @_, "\n");
}

sub usage(@)
{
	die("USAGE: ", basename($0), " ", @_, "\n");
}

END { }

1;
