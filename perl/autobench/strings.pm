
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/strings.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module that contains common string helper functions

package autobench::strings;

use strict;
use warnings;

BEGIN {
    use Exporter();
    our (@ISA, @EXPORT);
    @ISA = "Exporter";
    @EXPORT = qw( &prepend &auto_prepend &manual_prepend &indent_string &pretty_print_bytes );
}

sub prepend {
    my $num = shift;
    my $length = length($num);

    return manual_prepend($num, $length);
}

sub auto_prepend {
    my $num = shift;
    my $max_num = shift;

    return manual_prepend($num, length($max_num));
}

sub manual_prepend {
    my $num = shift;
    my $length = shift;
    return sprintf("%0" . $length . "d", $num);
}

sub indent_string {
    my ($msg, $level, $char) = @_;

    my $str = "";
    for (my $i=0; $i<$level; $i++) {
        $str .= $char;
    }

    return $str . $msg;
}

# Take input in bytes and pretty print it with units, converting if necessary.
sub pretty_print_bytes($)
{
	my $output = shift;
	my @prefixes = ("", "KB", "MB", "GB", "TB", "PB", "EB");
	my $prefix = 0;

	while ($output >= 1024) {
		$output /= 1024;
		$prefix++;
	}
	$output = sprintf("%.1f%s", $output, $prefixes[$prefix]);

	return $output;
}

END { }

1;
