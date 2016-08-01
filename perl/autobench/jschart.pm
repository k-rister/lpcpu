
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/jschart.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module that implements a framework for generating SVG charts using client-side Javascript

package autobench::jschart;

use strict;
use warnings;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

# class constructor
sub new {
    my $class = shift;
    my $page_title = shift || "page title undefined";
    my $self = {};
    $self->{OBJECTS} = {};
    $self->{OBJECT_INDEX} = 0;
    $self->{PAGE_TITLE} = $page_title;
    $self->{LIBRARY_LOCATION} = "local";
    $self->{FILES_LOCATION} = "";
    $self->{PACKED_PLOTFILES} = 0;
    $self->{PLOTFILE_LOCATION} = "";
    $self->{PACKED_PLOTFILE_DICTIONARY} = {};
    $self->{RAW_DATA_LOCATION} = "";
    bless $self, $class;
    return $self;
}

# set the library location to be remote
sub set_library_remote() {
    my $self = shift;

    $self->{LIBRARY_LOCATION} = "remote";
}

# set the library location to be local
sub set_library_local() {
    my $self = shift;

    $self->{LIBRARY_LOCATION} = "local";
}

# optionally set the relative location to the plot-files directory
sub set_files_location($) {
    my $self = shift;
    my $location = shift;

    $self->{FILES_LOCATION} = $location;
}

# optionally enable linking to the raw data files which were used to generate a chart
sub enable_raw_data_file_links($) {
    my $self = shift;
    my $location = shift;

    $self->{RAW_DATA_LOCATION} = $location;
}

# optionally enable packed plotfile creation
sub enable_packed_plotfiles($) {
    my $self = shift;
    my $location = shift;

    # validate that the provided location is reachable
    if (-e $location) {
	$self->{PACKED_PLOTFILES} = 1;
	$self->{PLOTFILE_LOCATION} = $location;
	return 0;
    } else {
	print STDERR "ERROR: Enabling jschart plotfile packing failed!\n";

	return 1;
    }
}

# add a chart to the page
#
# Arg1 = chart identifier, a unique identifier for the chart on the page
# Arg2 = chart type (supported types: line; stacked)
# Arg3 = chart title
# Arg4 = x-axis label
# Arg5 = y-axis label
#
sub add_chart($ $ $ $ $) {
    my $self = shift;
    my $id = shift;
    my $type = shift;
    my $title = shift;
    my $x_label = shift;
    my $y_label = shift;

    if (exists $self->{OBJECTS}->{$id}) {
	return 0;
    } else {
	if ($type eq 'line') {
	    $type = 0;
	} elsif ($type eq 'stacked') {
	    $type = 1;
	} else {
	    return 0;
	}

	$self->{OBJECTS}->{$id} = {
	    'object_type' => 'chart',
	    'index' => $self->{OBJECT_INDEX}++,
	    'type' => $type,
	    'title' => $title,
	    'x_label' => $x_label,
	    'y_label' => $y_label,
	};

	$self->{OBJECTS}->{$id}->{'plots'} = [];
	$self->{OBJECTS}->{$id}->{'legend_entries'} = [];
	$self->{OBJECTS}->{$id}->{'axis_bounds'} = {};
	$self->{OBJECTS}->{$id}->{'raw_data_sources'} = [];

	return 1;
    }
}

# add a section to the page
#
# Arg1 = section identifer, a unique identifier for the section on the page
# Arg2 = label text
#
sub add_section($ $) {
    my $self = shift;
    my $id = shift;
    my $text = shift;

    if (exists $self->{OBJECTS}->{$id}) {
	return 0;
    } else {
	$self->{OBJECTS}->{$id} = {
	    'object_type' => 'section',
	    'index' => $self->{OBJECT_INDEX}++,
	    'text' => $text,
	};

	return 1;
    }
}

# add a link to the page
#
# Arg1 = link identifier, a unique identifier for the link on the page
# Arg2 = link target
# Arg3 = link text
#
sub add_link($ $ $) {
    my $self = shift;
    my $id = shift;
    my $target = shift;
    my $text = shift;

    if (exists $self->{OBJECTS}->{$id}) {
	return 0;
    } else {
	$self->{OBJECTS}->{$id} = {
	    'object_type' => 'link',
	    'index' => $self->{OBJECT_INDEX}++,
	    'target' => $target,
	    'text' => $text,
	};

	return 1;
    }
}

# add plotfile(s) to a chart
#
# Arg1 = chart identifier, the id of the chart to add the plot to
# Arg2 = plot file name(s)
#
sub add_plots($ @) {
    my $self = shift;
    my $id = shift;
    my @plots = @_;

    if ((exists $self->{OBJECTS}->{$id}) && ($self->{OBJECTS}->{$id}->{'object_type'} eq 'chart')) {
	foreach my $plot (@plots) {
	    push @{$self->{OBJECTS}->{$id}->{'plots'}}, 'plot-files/' . $plot . '.plot';
	}

	return 1;
    } else {
	return 0;
    }
}

# add legend entries to a chart
#
# Arg1 = chart identifier, the id of the chart to add the plot to
# Arg2 = legend entries
#
sub add_legend_entries($ @) {
    my $self = shift;
    my $id = shift;
    my @entries = @_;

    if ((exists $self->{OBJECTS}->{$id}) && ($self->{OBJECTS}->{$id}->{'object_type'} eq 'chart')) {
	foreach my $entry (@entries) {
	    push @{$self->{OBJECTS}->{$id}->{'legend_entries'}}, $entry;
	}

	return 1;
    } else {
	return 0;
    }
}

# add axis range bounds to a chart
#
# Arg1 = chart identifier, the id of the chart to add the bounds to
# Arg2 = the axis to apply to (values: x; y)
# Arg3 = the constraint to add (values: min; max)
# Arg4 = the value to apply to the constraint
#
sub add_axis_range_bound($ $ $ $) {
    my $self = shift;
    my $id = shift;
    my $axis = shift;
    my $constraint = shift;
    my $value = shift;

    if ((! exists $self->{OBJECTS}->{$id}) ||
	((! $axis eq 'x') && (! $axis eq 'y')) ||
	((! $constraint eq 'min') && (! $constraint eq 'max'))) {
	return 0;
    }

    $self->{OBJECTS}->{$id}->{'axis_bounds'}->{$axis . '_' . $constraint} = $value;

    return 1;
}

# add a link to the raw data to a chart
#
# Arg1 = chart identifier, the id of the chart to add the link to
# Arg2 = the filename to link to
#
# This feature must be "enabled" via the "enable_raw_data_file_links" subroutine
#
sub add_raw_data_sources($ @) {
    my $self = shift;
    my $id = shift;
    my @files = @_;

    if ((exists $self->{OBJECTS}->{$id}) && ($self->{OBJECTS}->{$id}->{'object_type'} eq 'chart')) {
	foreach my $file (@files) {
	    push @{$self->{OBJECTS}->{$id}->{'raw_data_sources'}}, $file;
	}

	return 1;
    } else {
	return 0;
    }
}

# return the header for the html page
sub get_page_header() {
    my $self = shift;

    my $string = "<html>\n<head>\n<title>" . $self->{PAGE_TITLE} . "</title>\n";

    $string .= "<link rel=\"stylesheet\" href=\"" . $self->{FILES_LOCATION} . "../jschart.pm/jschart.css\"/>\n";

    $string .= "</head>\n<body>\n";

    if ($self->{LIBRARY_LOCATION} eq "local") {
	$string .= "<script src=\"" . $self->{FILES_LOCATION} . "../jschart.pm/d3.min.js\" charset=\"utf-8\"></script>\n";
	$string .= "<script src=\"" . $self->{FILES_LOCATION} . "../jschart.pm/d3-queue.min.js\" charset=\"utf-8\"></script>\n";
    } elsif ($self->{LIBRARY_LOCATION} eq "remote") {
	$string .= "<script src=\"http://d3js.org/d3.v3.min.js\" charset=\"utf-8\"></script>\n";
	$string .= "<script src=\"http://d3js.org/d3-queue.v3.min.js\" charset=\"utf-8\"></script>\n";
    }

    $string .= "<script src=\"" . $self->{FILES_LOCATION} . "../jschart.pm/jschart.js\" charset=\"utf-8\"></script>\n";

    return $string;
}

# return the footer for the html page
sub get_page_footer() {
    my $self = shift;

    my $string = "\n<script>finish_page()</script>\n";

    $string .= "\n</body>\n</html>\n";

    return $string;
}

# return the html that is generated for a single section
sub get_section_html($) {
    my $self = shift;
    my $id = shift;

    my $string = "<a name='" . $id . "'></a><hr/><div align='center'><h1>" . $self->{OBJECTS}->{$id}->{'text'} . "</h1></div><hr/>\n";

    return $string;
}

# return the html that is generated for a single link
sub get_link_html($) {
    my $self = shift;
    my $id = shift;

    my $string = "<a href='" . $self->{OBJECTS}->{$id}->{'target'} . "'>" . $self->{OBJECTS}->{$id}->{'text'} . "</a><br/>\n";

    return $string;
}

# internal function used to pack plotfiles for the specified chart object
sub __pack_plotfiles($) {
    my $self = shift;
    my $id = shift;

    my $plotfiles_list_checksum = md5_hex("@{$self->{OBJECTS}->{$id}->{'plots'}}");
    my $packed_plotfile_filename = 'jschart_packed-plot-file_' . $plotfiles_list_checksum . '.plot';

    # check for a "cache" hit
    if ((! exists $self->{PACKED_PLOTFILE_DICTIONARY}->{$plotfiles_list_checksum}) &&
	(! -e $self->{PLOTFILE_LOCATION} . "/packed-plot-files/" . $packed_plotfile_filename)) {
	# the requested packed plot file does not exist so create it

	if (open(PACKED_PLOTFILE, ">", $self->{PLOTFILE_LOCATION} . '/packed-plot-files/' . $packed_plotfile_filename)) {
	    for (my $i=0; $i<@{$self->{OBJECTS}->{$id}->{'plots'}}; $i++) {
		my $filename = $self->{OBJECTS}->{$id}->{'plots'}[$i];

		# if the filename has been escaped for printing we need to remove the escapes so that the open will succeed
		$filename =~ s/\\//g;

		if (open(PACKED_INPUT, "<", $self->{PLOTFILE_LOCATION} . '/' . $filename)) {
		    print PACKED_PLOTFILE "--- JSChart Packed Plot File V1 ---\n";

		    while (<PACKED_INPUT>) {
			print PACKED_PLOTFILE $_;
		    }

		    close PACKED_INPUT;
		} else {
		    printf STDERR "ERROR: Could not open %s for consumption!\n", $self->{PLOTFILE_LOCATION} . '/' . $filename;
		}
	    }

	    close PACKED_PLOTFILE;

	    $self->{PACKED_PLOTFILE_DICTIONARY}->{$plotfiles_list_checksum} = 1;
	} else {
	    printf STDERR "ERROR: Could not open %s for creation!\n", $self->{PLOTFILE_LOCATION} . '/packed-plot-files/' . $packed_plotfile_filename;
	}
    }

    return $packed_plotfile_filename;
}

# return the html that is generated for a single chart
#
# Arg1 = chart identifier, the id of the chart to generate the html for
# Arg2 = index, index to be used in the chart titles
#
sub get_chart_html($) {
    my $self = shift;
    my $id = shift;
    my $index = shift;

    my $chart_label = 'jschart_' . md5_hex($id);

    my $string = "<hr id='chart_nav_" . $id . "'/>\n";

    if (exists $self->{OBJECTS}->{$id}->{'prev_chart'}) {
	$string .= "<a onclick='navigate_to_chart(\"chart_nav_" . $self->{OBJECTS}->{$id}->{'prev_chart'} . "\");'>Previous Chart</a>\n";
    }

    if ((exists $self->{OBJECTS}->{$id}->{'prev_chart'}) && (exists $self->{OBJECTS}->{$id}->{'next_chart'})) {
	$string .= "&nbsp;|&nbsp;\n";
    }

    if (exists $self->{OBJECTS}->{$id}->{'next_chart'}) {
	$string .= "<a onclick='navigate_to_chart(\"chart_nav_" . $self->{OBJECTS}->{$id}->{'next_chart'} . "\");'>Next Chart</a>\n";
    }

    $string .= "<div id='" . $chart_label . "'>\n  <script>\n";

    $string .= "    create_graph(";

    $string .= $self->{OBJECTS}->{$id}->{'type'} . ', ';
    $string .= '"xy", ';
    $string .= '"' . $chart_label . '", ';
    $string .= '"' . $index . '. ' .$self->{OBJECTS}->{$id}->{'title'} . '", ';
    $string .= '"' . $self->{OBJECTS}->{$id}->{'x_label'} . '", ';
    $string .= '"' . $self->{OBJECTS}->{$id}->{'y_label'} . '", ';
    $string .= '{ ';

    foreach my $key (sort { $a cmp $b } (keys %{$self->{OBJECTS}->{$id}->{'axis_bounds'}})) {
	$string .= $key . ': ' . $self->{OBJECTS}->{$id}->{'axis_bounds'}->{$key} . ', ';
    }

    if (! $self->{PACKED_PLOTFILES}) {
	$string .= 'plotfiles: [ ';
	for (my $i=0; $i<@{$self->{OBJECTS}->{$id}->{'plots'}}; $i++) {
	    $string .= '"' . $self->{FILES_LOCATION} . $self->{OBJECTS}->{$id}->{'plots'}[$i] . '"';

	    if (($i + 1) < @{$self->{OBJECTS}->{$id}->{'plots'}}) {
		$string .= ', ';
	    }
	}
	$string .= ' ]';
    } else {
	$string .= 'packed: ' . @{$self->{OBJECTS}->{$id}->{'plots'}} . ', ';
	$string .= 'plotfile: "' . $self->{FILES_LOCATION} . 'packed-plot-files/' . $self->__pack_plotfiles($id) . '"';
    }

    if (@{$self->{OBJECTS}->{$id}->{'legend_entries'}}) {
	$string .= ', legend_entries: [ ';

	for (my $i=0; $i<@{$self->{OBJECTS}->{$id}->{'legend_entries'}}; $i++) {
	    $string .= '"' . $self->{OBJECTS}->{$id}->{'legend_entries'}[$i] . '"';

	    if (($i + 1) < @{$self->{OBJECTS}->{$id}->{'legend_entries'}}) {
		$string .= ', ';
	    }
	}

	$string .= ' ]';
    }

    if (! ($self->{RAW_DATA_LOCATION} eq "") && @{$self->{OBJECTS}->{$id}->{'raw_data_sources'}}) {
	$string .= ', raw_data_sources: [';

	for (my $i=0; $i<@{$self->{OBJECTS}->{$id}->{'raw_data_sources'}}; $i++) {
	    $string .= '"' . $self->{RAW_DATA_LOCATION} . '/' . $self->{OBJECTS}->{$id}->{'raw_data_sources'}[$i] . '"';

	    if (($i + 1) < @{$self->{OBJECTS}->{$id}->{'raw_data_sources'}}) {
		$string .= ', ';
	    }
	}

	$string .= ' ]';
    }

    $string .= ', sort_datasets: false }';
    $string .= ");\n";

    $string .= "  </script>\n</div>\n";

    return $string;
}

# return the html that contains all the charts
sub get_all_object_html() {
    my $self = shift;

    my $string = "";

    my $chart_counter = 0;

    my $prev;
    foreach my $key (sort {$self->{OBJECTS}->{$a}->{'index'} <=> $self->{OBJECTS}->{$b}->{'index'}} keys %{$self->{OBJECTS}}) {
	if ($self->{OBJECTS}->{$key}->{'object_type'} eq 'chart') {
	    if ($prev) {
		$self->{OBJECTS}->{$key}->{'prev_chart'} = $prev;
		$self->{OBJECTS}->{$prev}->{'next_chart'} = $key;
	    }
	    $prev = $key;
	}
    }

    foreach my $key (sort {$self->{OBJECTS}->{$a}->{'index'} <=> $self->{OBJECTS}->{$b}->{'index'}} keys %{$self->{OBJECTS}}) {
	if ($self->{OBJECTS}->{$key}->{'object_type'} eq 'chart') {
	    $chart_counter++;
	    $string .= $self->get_chart_html($key, $chart_counter);
	} elsif ($self->{OBJECTS}->{$key}->{'object_type'} eq 'link') {
	    $string .= $self->get_link_html($key);
	} elsif ($self->{OBJECTS}->{$key}->{'object_type'} eq 'section') {
	    $string .= $self->get_section_html($key);
	} else {
	    print STDERR 'ERROR: No appropriate handler for a object of type ' . $self->{OBJECTS}->{$key}->{'object_type'} . "!\n";
	}
    }

    return $string;
}

# dump the html page that creates the charts
sub dump_page() {
    my $self = shift;

    if ($self->{PACKED_PLOTFILES}) {
	if (! -d $self->{PLOTFILE_LOCATION} . "/packed-plot-files") {
	    mkdir $self->{PLOTFILE_LOCATION} . "/packed-plot-files";
	}
    }

    my $string = $self->get_page_header;

    $string .= $self->get_all_object_html;

    $string .= $self->get_page_footer;

    return $string;
}

sub dump {
    my $self = shift;

    print Dumper \$self;
}

1;
