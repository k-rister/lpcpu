
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/sort.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module to assist in sorting

package autobench::sort;

use strict;
use warnings;

BEGIN {
    use Exporter();
    our (@ISA, @EXPORT);
    @ISA = "Exporter";
    @EXPORT = qw( &sort_numeric );
}

# For sorting numerically instead of alphabetically.
sub sort_numeric {
    sort({$a <=> $b} @_);
}

END { }

1;
