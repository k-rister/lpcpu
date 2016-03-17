
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/numbers.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module that contains common numeric helper functions

package autobench::numbers;

use strict;
use warnings;

BEGIN {
    use Exporter();
    our (@ISA, @EXPORT);
    @ISA = "Exporter";
    @EXPORT = qw( &max &commify );
}

sub max {
    my $num_1 = shift;
    my $num_2 = shift;

    if ($num_1 > $num_2) {
        return $num_1;
    } else {
        return $num_2;
    }
}

# return a number with comma thousands separator added
sub commify {
    local($_) = shift;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}

END { }

1;
