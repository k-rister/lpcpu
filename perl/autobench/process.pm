
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/process.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# Perl module for routines related to controlling processes.

package autobench::process;

use strict;
use warnings;

use POSIX 'setsid';

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT = qw( &daemonize );
}

# daemonize
#
# Detach the running process from the controlling terminal.
# This routine is based on the discussion at:
# http://www.perlmonks.org/?node_id=374409
sub daemonize(;$)
{
	my $dont_close = shift || 0;

	my $pid = fork();
	if ($pid) {
		exit 0;
	} elsif (!defined($pid)) {
		exit 1;
	}

	setsid();

	$pid = fork();
	if ($pid) {
		exit 0;
	} elsif (!defined($pid)) {
		exit 1;
	}

	chdir('/') || die("Cannot change directory to /.\n");
	umask(0);

	if (!$dont_close) {
		close(STDIN);
		close(STDOUT);
		close(STDERR);
	}
}

END { }

1;
