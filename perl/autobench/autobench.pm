
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/autobench.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# Perl module for autobench-specific routines.

package autobench::autobench;

use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use autobench::file;
use autobench::log;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT = qw( &get_autodir );
}

# get_autodir
#
# Return the pathname to the root of the Autobench tree. If $AUTODIR is defined in
# the environment, that value will be returned. Otherwise, the name of a file
# in the Autobench tree can be passed to this routine, and the Autobench path will
# be determined based on the location of that file. If the path cannot be found
# based on the specified file, check /etc/autobench_instances for the value of
# the MASTER_AUTODIR variable.
sub get_autodir(;$)
{
	my $file = shift || $0;
	my $full_path = abs_path($file);

	if (defined($ENV{"AUTODIR"})) {
		return $ENV{"AUTODIR"};
	}

	while ($full_path ne "/" &&
	       ! (-f "$full_path/autobench_install" &&
	          -f "$full_path/scripts/autobench")) {
		$full_path = dirname($full_path);
	}

	if ($full_path eq "/") {
		my ($line) = grep_file("MASTER_AUTODIR", "/etc/autobench_instances");
		if (defined($line) && $line =~ /MASTER_AUTODIR=(.*)/) {
			$full_path = $1;
		} else {
			error("File $file is not located in the Autobench tree.");
			$full_path = "";
		}
	}

	return $full_path;
}

END { }

1;
