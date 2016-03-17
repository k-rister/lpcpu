#! Perl module for working with charts and plot-files.

#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/chart.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


package autobench::chart;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use autobench::log;
use autobench::file;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA = "Exporter";
	@EXPORT = qw( &create_chart_script
			&read_plot_file
			&create_plot_file
			&create_aggregate_plot_files
			&plot_file_average
			&set_plot_file_label
			&combine_bar_plot_files
			&compare_plot_files
		    );
}

# create_chart_script
#
# Create a chart.sh script, which will be run by the chart-processor.sh script
# in Autobench.
#
# Arg1: Directory to create the script in.
# Arg2: Title of the html file that will be generated by the chart.sh script.
# Arg3: Extra text to include at the top of the generated html file.
# Arg4: Array of commands to insert in the script for creating the charts. Each
#       of these should start with "\$SCRIPT".
#
# Returns: 0 for success, non-zero for failure.
sub create_chart_script($ $ $ @)
{
	my $dir = shift;
	my $title = shift;
	my $header = shift;
	my @commands = @_;
	my $chart_script = "$dir/chart.sh";

	my $rc = open(my $chart_fp, "> $chart_script");
	if (!$rc) {
		error("Cannot create chart-script $chart_script.");
		return 1;
	}

        print $chart_fp ("#!/bin/bash\n\n" .
			 "DIR=`dirname \$0`\n" .
			 "if [ \$# -ne 2 ]; then\n" .
			 "    echo \"You must specify the path to the chart.pl script and the Chart Directory libraries.\"\n" .
			 "    exit 1\n" .
			 "fi\n\n" .
			 "SCRIPT=\$1\n" .
			 "LIBRARIES=\$2\n" .
			 "export PERL5LIB=\$LIBRARIES\n\n" . 
			 "pushd \$DIR > /dev/null\n\n");

	foreach my $command (@commands) {
		print $chart_fp ("$command\n");
	}

	$title =~ s/-vs-/ vs /g;
	$header =~ s/\n/<br>\\n/g;
	print $chart_fp ("\n" .
			 "echo '<html>' > chart.html\n" .
			 "echo '<head>' >> chart.html\n" .
			 "echo '<title>$title</title>' >> chart.html\n" .
			 "echo '</head>' >> chart.html\n" .
			 "echo '<body>' >> chart.html\n" .
			 "echo '<h2>$title</h2>' >> chart.html\n" .
			 "echo -e '$header' >> chart.html\n" .
			 "echo '<br>' >> chart.html\n" .
			 "for i in `find -name '*.png'`; do\n" .
			 '    echo -e "<table>\n<tr valign=\'top\'>\n" >> chart.html' . "\n" .
			 '    echo -e "<td><img src=\'$i\'></td>\n" >> chart.html' . "\n" .
			 '    html_file=`echo $i | sed -e "s/png/html/"`' . "\n" .
			 '    if [ -e $html_file ]; then' . "\n" .
			 '      echo -e "<td>\n" >> chart.html' . "\n" .
			 '      cat $html_file >> chart.html' . "\n" .
			 '      echo -e "</td>\n" >> chart.html' . "\n" .
			 '    fi' . "\n" .
			 '    echo -e "</tr>\n</table>\n" >> chart.html' . "\n" .
			 "done\n\n" .
			 "echo '</body>' >> chart.html\n" .
			 "echo '</html>' >> chart.html\n\n" .
			 "popd > /dev/null\n");

	close($chart_fp);
	chmod(0755, $chart_script);
	return 0;
}

# read_plot_file
#
# Arg1: Name of a plot-file
# Arg2: Reference to hash for storing the plot-file data.
#       "x" values will be the keys in the hash.
# Arg3: Reference to a scalar for storing the plot-file's label.
#
# Returns: 0 for success, non-zero for failure.
sub read_plot_file($ $ $)
{
	my $plot_filename = shift;
	my $data_ref = shift;
	my $label_ref = shift;

	my $rc = open(my $fp, $plot_filename);
	if (!$rc) {
		error("Cannot open plot-file $plot_filename.");
		return 1;
	}

	while (my $line = <$fp>) {
		if ($line =~ /^#/) {
			if ($line =~ /#LABEL:\s*(.+)$/) {
				$$label_ref = $1;
			}
		} else {
			my ($x, $y) = split(/\s+/, $line);
			$data_ref->{$x} = $y;
		}
	}

	close($fp);
	return 0;
}

# create_plot_file
#
# Arg1: Name of plot-file to create.
# Arg2: Label for the first line of the plot-file.
# Arg3: Reference to a hash containing the data to write to the plot file.
# Arg4: When creating a plot-file for a bar-chart, there is normally only
#       a single line with a single value (following the line with the label).
#       To create such a plot-file, pass "0" for Arg3, and use this argument
#       to pass the single value for the plot-file.
# Arg5: CSV-list data.
#
# Returns: 0 for success, non-zero for failure.
sub create_plot_file($ $ $; $ $)
{
	my $plot_file_name = shift;
	my $label = shift;
	my $data = shift;
	my $data_val = shift || 0;
	my $csv_list = shift || 0;
	my $numerical = 1;
	my $seperator = " ";

	my $rc = open(my $plot_fp, "> $plot_file_name");
	if (!$rc) {
		error("Cannot create plot-file $plot_file_name.");
		return 1;
	}

	if ($csv_list) {
		$seperator = ",";
	}

	print $plot_fp ("#LABEL:$label\n");

	if ($data) {
		foreach my $key (keys(%{$data})) {
			if (!looks_like_number($key)) {
				$numerical = 0;
				last;
			}
		}

		my @keys;
		if ($numerical) {
			@keys = sort({$a <=> $b} keys(%{$data}));
		} else {
			@keys = sort(keys(%{$data}));
		}
		foreach my $key (@keys) {
			print $plot_fp ("$key$seperator$data->{$key}\n");
		}
	} else {
		print $plot_fp ("$data_val\n");
	}

	close($plot_fp);
	return 0;
}

# create_aggregate_plot_files
#
# For a set of plot-files, create one plot-file that is the summation of all
# the plot-files, and one plot-file that is the average of all the plot-files.
#
# Arg1: Basename of the output files (without '.plot'). The summation file will
#       append ".sum.plot" to this name, and the average file will append
#       ".average.plot".
# Arg2: Array of plot-file names to aggregate.
#
# Returns: 0 for success, non-zero for failure. No output files will be created
#          if there's an error reading any of the input files.
sub create_aggregate_plot_files($ @)
{
	my $output_file = shift;
	my @input_files = @_;
	my %aggregate_data;

	foreach my $input_file (@input_files) {
		my %data;
		my $label;
		my $rc = read_plot_file($input_file, \%data, \$label);
		if ($rc) {
			error("No data found for plot-file $input_file.");
			error("No aggregate plot-files will be created.");
			return $rc;
		}
		foreach my $x (keys(%data)) {
			if (!defined($aggregate_data{'values'}{$x})) {
				$aggregate_data{'values'}{$x} = 0;
				$aggregate_data{'counts'}{$x} = 0;
			}
			$aggregate_data{'values'}{$x} += $data{$x};
			$aggregate_data{'counts'}{$x}++;
		}
	}

	create_plot_file($output_file . ".sum.plot", $output_file, $aggregate_data{'values'});

	foreach my $x (keys(%{$aggregate_data{'values'}})) {
		$aggregate_data{'values'}{$x} /= $aggregate_data{'counts'}{$x};
	}

	create_plot_file($output_file . ".average.plot", $output_file, $aggregate_data{'values'});
}

# plot_file_average
#
# Calculate the average value of all "y" values in the specified plot file.
#
# Arg1: Name of the plot-file.
#
# Returns: Average of "y" values.
sub plot_file_average($)
{
	my $plot_file = shift;
	my $count = 0;
	my $sum = 0;
	my $label;
	my %data;

	read_plot_file($plot_file, \%data, \$label);

	foreach my $key (keys(%data)) {
		$sum += $data{$key};
		$count++;
	}

	if (!$count) {
		error("No data found in plot-file $plot_file.\n");
		return 0;
	} else {
		return $sum / $count;
	}
}

# set_plot_file_label
#
# Change the label on the first line of an existing plot-file.
#
# Arg1: Name of the plot-file to modify.
# Arg2: String to use as the new label.
#
# Returns: 0 for success, non-zero for failure.
sub set_plot_file_label($ $)
{
	my $plot_file_name = shift;
	my $label = shift;
	my $rc = 0;

	my @contents = read_file($plot_file_name, 1);
	if (!@contents) {
		error("No data read from file $plot_file_name");
		$rc = 1;
	}
        if ($contents[0] =~ s/\#LABEL:.*/\#LABEL:$label/i) {
        	write_file($plot_file_name, @contents);
	} else {
		error("No plot-file label found in file $plot_file_name");
		$rc = 1;
	}

	return $rc;
}

# combine_bar_plot_files
#
# Combine one or more bar-chart plot-files into a single plot file. For each
# "old" plot-file, the label will be used as the "x" value and the single
# value will be used as the "y" value. Plot files with more than one data entry
# cannot be combined.
#
# Arg1: Name of plot file to create.
# Arg2: Label for the new plot file.
# Arg3: Array of plot-filenames to be combined.
sub combine_bar_plot_files($ $ @)
{
	my $new_plot_filename = shift;
	my $new_label = shift;
	my @plot_files = @_;
	my %new_data;

	foreach my $plot_file (@plot_files) {
		my %data;
		my $label = "";
		read_plot_file($plot_file, \%data, \$label);
		my @keys = keys(%data);

		if (@keys != 1) {
			error("Bar plot-files can only contain one entry.\n");
			return;
		}

		if (!$label) {
			error("No label found in plot-file $plot_file.\n");
			return;
		}

		$label =~ s/\s+/_/g;
		$new_data{$label} = $keys[0];
	}

	create_plot_file($new_plot_filename, $new_label, \%new_data);
}

# compare_plot_files
#
# Compare the "y" values in two plot files and create a third plot file
# containing the comparison data.
#
# Arg1: "New" plot-file.
# Arg2: "Old" plot-file.
# Arg3: Name of plot-file to create with compared data.
# Arg4: Label for the new plot-file.
# Arg5: Reference to a hash to store the plot-file and comparison data.
#       This hash will have 
# Arg6: Polarity: +1 if a larger number is an improvement, or -1 if a
#       smaller number is an improvement. (optional, default = +1).
# Arg7: Tolerance (optional, default = 3.0).
# Arg8: Comparison Type: "raw_delta" to compare using the difference of the two
#                        values, or "percent_delta" to compare using the
#                        percentage-difference of the two values.
#                        (optional, default = "percent_delta").
sub compare_plot_files($ $ $ $ $; $ $ $)
{
	my $plot_file_new = shift;
	my $plot_file_prev = shift;
	my $output_plot_file = shift;
	my $output_plot_file_label = shift;
	my $data = shift;
	my $polarity = shift || 1;
	my $tolerance = shift || 3.0;
	my $comparison_type = shift || "";
	my $improvements = 0;
	my $regressions = 0;
	my $within_tolerance = 0;
	my @sorted_keys;
	my $numeric_sort = 1;

	if ($polarity != -1) {
		$polarity = 1;
	}

	$comparison_type = lc($comparison_type);
	if ($comparison_type ne "raw_delta") {
		$comparison_type = "percent_delta";
	}

	# Read in the data from all plot files.
	$data->{'raw'}{'new'} = {};
	$data->{'raw'}{'prev'} = {};
	read_plot_file($plot_file_new,  $data->{'raw'}{'new'},  \$data->{'label'}{'new'});
	read_plot_file($plot_file_prev, $data->{'raw'}{'prev'}, \$data->{'label'}{'prev'});

	# Calculate the difference between the "new" and "prev" values,
	# and calculate the "new" values as percentage-improvements of
	# the "prev" values.
	foreach my $x (keys(%{$data->{'raw'}{'new'}})) {
		my $y_new = $data->{'raw'}{'new'}->{$x};
		my $y_prev = $data->{'raw'}{'prev'}->{$x};

		if (defined($y_prev) && $y_prev != 0 &&
		    looks_like_number($y_new) &&
		    looks_like_number($y_prev)) {

			$data->{'raw_delta'}{$x} = ($y_new - $y_prev) * $polarity;
			$data->{'percent_delta'}{$x} = $data->{'raw_delta'}{$x} * 100 / $y_prev;

			if ($data->{$comparison_type}{$x} > $tolerance) {
				$data->{'improvement'}{$x} = 1;
				$improvements++;
			} elsif ($data->{$comparison_type}{$x} < -$tolerance) {
				$data->{'improvement'}{$x} = -1;
				$regressions++;
			} else {
				$data->{'improvement'}{$x} = 0;
				$within_tolerance++;
			}
		}
	}

	create_plot_file($output_plot_file, $output_plot_file_label, $data->{$comparison_type});

	return ($improvements, $regressions, $within_tolerance);
}

END { }

1;
