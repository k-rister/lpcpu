
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/html.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module to assist in writing HTML files.

package autobench::html;

use strict;
use warnings;

BEGIN {
    use Exporter();
    our (@ISA, @EXPORT);
    @ISA = "Exporter";
    @EXPORT = qw( &new_html_file
		  &close_html_file );
}

# new_html_file
#
# Create a new html file with the given filename. Print the html header to
# the file with the given title. Return the open file-descriptor for the
# new file.
sub new_html_file($ $)
{
	my $filename = shift;
	my $title = shift;
	my $fp;

	my $rc = open($fp, "> $filename");
	if (!$rc) {
		error("Could not create new html file $filename.");
		return 0;
	}

	print $fp ("<html>\n" .
                   "<head>\n" .
                   "<title>$title</title>\n" .
                   "</head>\n" .
                   "<body>\n");

	return $fp;
}

# close_html_file
#
# Print the html footer to the specified file-descriptor and then close it.
sub close_html_file($)
{
	my $fp = shift;
	print $fp ("</body>\n" .
		   "</html>\n");
	close($fp);
}

END { }

1;
