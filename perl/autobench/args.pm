
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/args.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# Perl module for routines related to parsing command-line arguments.

package autobench::args;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT = qw( &parse_arguments
		      &csv_list_to_array );
}

# parse_arguments
#
# Parse arguments from the command line in key=value pairs.
#
# Arg1: Reference to a hash for storing the key=value pairs.
# Arg2: Array of "key=value" strings.
sub parse_arguments($ @)
{
	my $args = shift;

	foreach my $arg (@_) {
		if ($arg =~ /(.*)=(.*)/) {
			my $key = $1;
			my $val = $2;
			$args->{$key} = $val;
		}
	}
}

# csv_list_to_array
#
# Split a comma-seperated-values list into separate tokens.
#
# Arg1: String containing a CSV list.
# Returns: A reference to an array of the individual tokens.
sub csv_list_to_array($)
{
	my $csv_list = shift;
	return [ split(/,/, $csv_list) ];
}

END { }

1;
