#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/chart.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# import perl libraries
use strict;
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
use POSIX qw(ceil floor);

# global variables
my %options;
my %inputs;
my @saved_argv = @ARGV;

# function to sum all the elements of an array
sub array_sum
{
    my $array = shift;
    my $array_size = $#{$array} + 1;
    my $sum = 0;
    my $i;

    for ($i=0; $i<$array_size; $i++)
    {
	$sum += ${$array}[$i];
    }

    return $sum;
}

# function to initialize options that have 2 input methods from the cli
# option1, option2, default
sub double_option_init
{
    my $option1 = shift(@_);
    my $option2 = shift(@_);
    my $default = shift(@_);
    my $ret_val = $default;

    $ret_val = $option1 if $option1;
    $ret_val = $option2 if $option2;

    return $ret_val;
}

# function to initialize options that have 1 input method from the cli
# option1, default
sub single_option_init
{
    my $option1 = shift(@_);
    my $default = shift(@_);
    my $ret_val = $default;

    $ret_val = $option1 if $option1;

    return $ret_val;
}

# function to determine if a string based variable is set
sub string_is_set
{
    my $var = shift(@_);
    $var = length $var;

    if ($var == 0)
    {
        return 0;
    }
    else
    {
        return 1;
    }
}

# function to only push on a new value (rejects values already in the array)
sub push_unique
{
    my $array = shift(@_);
    my $value = shift(@_);
    my $item;

    for $item (@{$array}) {
        if ($value eq $item) {
            return;
        }
    }

    push @{$array}, $value
}

# function to check if an array as unique values
sub array_is_unique
{
    my $array = shift;
    my $i = 1;
    my $array_size = $#{$array} + 1;

    if ($array_size < 1)
    {
	return 0;
    }

    my $value = ${$array}[0];

    for ($i=1; $i<$array_size; $i++)
    {
	if (${$array}[$i] != $value)
	{
	    return 1;
	}
    }

    return 0;
}

# function to check for the presence of a value in an array
sub is_in_array
{
    my $value = shift;
    my $array = shift;
    my $i;
    my $array_size = $#{$array} + 1;

    if ($array_size < 1)
    {
	return 0;
    }

    for ($i=0; $i<$array_size; $i++)
    {
	if ("${$array}[$i]" eq "$value")
	{
	    return 1;
	}
    }

    return 0;
}

# function to return the largest of two values
sub max
{
    my $one = shift;
    my $two = shift;

    if ($one > $two)
    {
	return $one;
    }
    else
    {
	return $two;
    }
}

# function to scale the y values by the multiply-y-by option
sub multiply_y
{
    my $array = shift;
    map { $_ *= $inputs{'multiply-y-by'} } @{$array};
    return $array;
}

# function to scale the x values by the multiply-x-by option
sub multiply_x
{
    my $array = shift;
    map { $_ *= $inputs{'multiply-x-by'} } @{$array};
    return $array;
}

my $key;
my $counter;
my $counter2;
my $counter3;

# parse the cli options ################################################################

# uncomment to print the bare unmodified cli arguments
#print Dumper \@ARGV;

# uncomment to print the environment
#print Dumper \%ENV;

# get the cli options and store them for parsing
Getopt::Long::Configure ("bundling");
Getopt::Long::Configure ("no_auto_abbrev");
Getopt::Long::Configure ("pass_through");     # allows the --plot-axis and --trend option to fall down into the input file parsing block
GetOptions(\%options, 't=s', 'title=s',       # set the title on the plot, this also serves as the output filename
                      'x=s', 'x-label=s',     # set the x-axis label on the plot
                      'y=s', 'y-label=s',     # set the y-axis label on the plot
                      's=s', 'style=s',       # set the style on the plot -- may be one of: lines, linespoints, stackedlines, stackedlinespoints, compare, barcompare, stackedbar, stackedbarcompare, bar, groupedbar, groupedstackedbar, groupedstackedbarcompare, scalability --  default is linespoints
                      'baseline=s',           # plotfile to use as the baseline for a scalability, compare, barcompare, groupedstackedbarcompare, or stackedbarcompare graph -- for stackedbarcompare input is either the bar name to use or one of auto:first, auto:last
                      'm=s', 'smooth=s',      # set the type of smoothing
                      'k=s', 'key=s',         # deprecated option, only included for backwards compatabilibity
                      'f=s', 'font=s',        # set the font
                      'o=s', 'outdir=s',      # set the output file directory, defaults to current directory
                      'O=s', 'outfile=s',     # set the output filename, defaults to the chart's title 
                      'i=s', 'image=s',       # set the ouptut image type, default is png
                      'table=s',              # output the data in a table (non-graphical) format
                      'help', 'h',            # show the help and exit
                      'man',                  # show the complete man page and exit
                      'x-tics=s',             # set the major tick to be used for log scale on the x-axis
                      'y-tics=s',             # set the major tick to be used for log scale on the y-axis
                      'x-range=s',            # set the range of the x-axis in the form A:B
                      'x-scale=s',            # set the x-axis scale -- may be one of: linear or log -- default is linear
                      'x-label-angle=i',      # set the angle of the labels on the x-axis -- default is 0.
                      'y-range=s',            # set the range of the y-axis in the form A:B
                      'y-scale=s',            # set the y-axis scale -- may be one of: linear or log -- default is linear
                      'y2-label=s',           # set the 2nd y-axis label
                      'y2-range=s',           # set the range of the y2-axis in the form A:B
                      'y2-scale=s',           # set the y2-axis scale -- may be one of: linear or log -- default is linear
                      'font-size=i',          # set the font size -- default is 8
                      'legend-font-size=i',   # set the legend font size -- default is font-size
                      'title-font-size=i',    # set the title font size -- default is font-size + 2
                      'axis-font-size=i',     # set the axis font size -- default is font-size
                      'axis-label-font-size=i', # set the axis label font size -- default is font-size + 1
                      'chart-label-font-size=i', # set the chart label font size -- default is font-size
                      'graphtype=s',          # set the graphtype -- may be one of: 
                      'vert-zone=s@',         # set a veritcal zone of the form X1:X2:color:label, can be used multiple times
                      'vert-line=s@',         # set a vertical line of the form X:color:label, can be used multiple times
                      'horz-zone=s@',         # set a horizontal zone of the form Y1:Y2:color:label, can be used multiple times
                      'horz-line=s@',         # set a horizontal line of the form Y:color:label, can be used multiple times
                      'legend-entry=s@',      # add a note to the legend, can be used multiple times
                      'omit-empty-plotfiles', # set this option to omit plot files that either have no plot data or all plot files are the same
                      'suppress-bar-labels',  # set this option to suppress labels at the tops of the bars, useful for large data sets where the bars become unreadable
                      'bar-label-angle=i',    # set the angle of the labels on top of bars
                      'legend-position=s',    # no longer a valid option, left to avoid errors
	              'x-pixels=s',           # set the number of x-pixels to use
                      'q', 'quiet',           # turn on quiet mode, this will disable informational messages
	              'group=s',              # specify an axis for a group in a groupedstackedbar or groupstackedbarcompare, takes a value such as 2:x1y2 where 2 is the group index that belongs on the x1y2 axis
	              'demo',                 # specify that demo mode is to be used -- this must be specified along with the style (s) -- all other arguments are ignored
                      'multiply-y-by=f',      # multiply all y data values by this amount
                      'multiply-x-by=f',      # multiple all x data values by this amount
                      'datapoint-compression-threshold=i', # if the number of datapoints exceeds the number of x pixels in the plot area times this value the, datapoints will be compressed to improve rendering accuracy -- default is 5
                      'no-stackedline-zero-insertion', # if specified do not insert zero values into "holes" in the stacked datasets
                      'd=i', 'debug=i');      # enable specific debug output by setting this to something other than 0

if ($options{'h'} || $options{'help'})
{
    pod2usage(-verbose => 1);
}

pod2usage(-verbose => 2) if ($options{'man'});

# when in demo mode, behavior is quite different
# only the style must also be specified
if ($options{'demo'})
{
    if ($options{'s'} || $options{'style'})
    {
	my $style;
	my $debug;

	if ($options{'s'})
	{
	    $style = $options{'s'};
	}

	if ($options{'style'})
	{
	    $style = $options{'style'};
	}

	if ($options{'d'})
	{
	    $debug = $options{'d'};
	}

	if ($options{'debug'})
	{
	    $debug = $options{'debug'};
	}

	demo_mode($style, $debug);
    }
    else
    {
	print STDERR "ERROR: You must specify a style with -s or --style when in demo mode\n";
	exit;
    }
}
else
{
    # process the title
    if ($options{'t'} || $options{'title'})
    {
	$inputs{'chart_title'} = $options{'t'} if $options{'t'};
	$inputs{'chart_title'} = $options{'title'} if $options{'title'};
    }
    else
    {
	print STDERR "ERROR: You must specify a title with -t or --title\n";
	exit;
    }
}

# process the axis labels
$inputs{'x_label'} = double_option_init($options{'x'}, $options{'x-label'}, "");
$inputs{'y_label'} = double_option_init($options{'y'}, $options{'y-label'}, "");
$inputs{'y2_label'} = single_option_init($options{'y2-label'}, "");

# process the style option
$inputs{'style'} = double_option_init($options{'s'}, $options{'style'}, "linespoints");

# process the smoothing option
$inputs{'smooth'} = double_option_init($options{'m'}, $options{'smooth'}, "");

# process the key option
# deprecated option, only included for backwards compatabilibity
$inputs{'key'} = double_option_init($options{'k'}, $options{'key'}, "right");

# process the font option
$inputs{'font'} = double_option_init($options{'f'}, $options{'font'}, ""); #"pcrb8a.pfb"); #"FreeMonoBold.ttf"); 

# process the output directory and file options
$inputs{'outdir'} = double_option_init($options{'o'}, $options{'outdir'}, ".");
$inputs{'outfile'} = double_option_init($options{'O'}, $options{'outfile'}, $inputs{'chart_title'});

# process the default output type option
$inputs{'image_type'} = double_option_init($options{'i'}, $options{'image'}, "png");

# process the debug option
$inputs{'debug'} = double_option_init($options{'d'}, $options{'debug'}, 0);

# process the x-tics option
$inputs{'x-tics'} = single_option_init($options{'x-tics'}, 0);

# process the y-tics option
$inputs{'y-tics'} = single_option_init($options{'y-tics'}, 0);

# process the axis range options
$inputs{'x-range'} = single_option_init($options{'x-range'}, "");
$inputs{'y-range'} = single_option_init($options{'y-range'}, "");
$inputs{'y2-range'} = single_option_init($options{'y2-range'}, "");

# process the axis scale options
$inputs{'x-scale'} = single_option_init($options{'x-scale'}, "");
$inputs{'y-scale'} = single_option_init($options{'y-scale'}, "");
$inputs{'y2-scale'} = single_option_init($options{'y2-scale'}, "");

# process the x-axis labels angle
$inputs{'x-label-angle'} = single_option_init($options{'x-label-angle'}, 0);

# process the font-size option
$inputs{'font-size'} = single_option_init($options{'font-size'}, 8);

# process the legend-font-size option
$inputs{'legend-font-size'} = single_option_init($options{'legend-font-size'}, $inputs{'font-size'});

# process the title-font-size option
$inputs{'title-font-size'} = single_option_init($options{'title-font-size'}, $inputs{'font-size'} + 2);

# process the axis-font-size option
$inputs{'axis-font-size'} = single_option_init($options{'axis-font-size'}, $inputs{'font-size'});

# process the axis-label-font-size option
$inputs{'axis-label-font-size'} = single_option_init($options{'axis-label-font-size'}, $inputs{'font-size'} + 1);

# process the axis-label-font-size option
$inputs{'chart-label-font-size'} = single_option_init($options{'chart-label-font-size'}, $inputs{'font-size'});

# process the vertical/horizontal zone and vertical/horizontal line options
$inputs{'vert-zone'} = single_option_init($options{'vert-zone'}, "");
$inputs{'vert-line'} = single_option_init($options{'vert-line'}, "");
$inputs{'horz-zone'} = single_option_init($options{'horz-zone'}, "");
$inputs{'horz-line'} = single_option_init($options{'horz-line'}, "");

# process the legend entries options
$inputs{'legend-entry'} = single_option_init($options{'legend-entry'}, "");

# process the graphtype option
$inputs{'graphtype'} = single_option_init($options{'graphtype'}, "0:0");

# process the baseline option
$inputs{'baseline'} = single_option_init($options{'baseline'}, "");

# process the omit empty plotfiles option
$inputs{'omit-empty-plotfiles'} = single_option_init($options{'omit-empty-plotfiles'}, 0);

# process the suppress bar label option
$inputs{'suppress-bar-labels'} = single_option_init($options{'suppress-bar-labels'}, 0);

# process the bar label angle option
$inputs{'bar-label-angle'} = single_option_init($options{'bar-label-angle'}, 0);

# process the table option
$inputs{'table'} = single_option_init($options{'table'}, 0);

# process the legend position option
$inputs{'legend-position'} = single_option_init($options{'legend-position'}, "default");

# process the quiet mode option
$inputs{'quiet'} = double_option_init($options{'q'}, $options{'quiet'}, 0);

# process the group option
$inputs{'group'} = single_option_init($options{'group'}, "");

# process the x-pixels option
$inputs{'x-pixels'} = single_option_init($options{'x-pixels'}, 1000);

# process the multiply-y-by option
$inputs{'multiply-y-by'} = single_option_init($options{'multiply-y-by'}, 1);

# process the multiply-x-by option
$inputs{'multiply-x-by'} = single_option_init($options{'multiply-x-by'}, 1);

# process the datapoint-compression-threshold
$inputs{'datapoint-compression-threshold'} = single_option_init($options{'datapoint-compression-threshold'}, 5);

# process the no-stackedline-zero-insertion
$inputs{'no-stackedline-zero-insertion'} = single_option_init($options{'no-stackedline-zero-insertion'}, 0);

if ($inputs{'x-pixels'} < 1000)
{
    print "ERROR: Minimum x-pixels is 1000 (not $inputs{'x-pixels'}), correcting.\n";
    $inputs{'x-pixels'} = 1000;
}

if ($inputs{'debug'} == 1)
{
    print "options hash =\n";
    print Dumper \%options;
}

if ($inputs{'debug'} == 2)
{
    print "inputs hash =\n";
    print Dumper \%inputs;
}

# end of parse the cli options #########################################################


# process the input files ##############################################################

my @fields;
my @datasets;
my $file;
my $plot_axis = "x1y1";
my $trend = "no";

my $is_defined_style = 0;

if (($inputs{'style'} eq "compare") || ($inputs{'style'} eq "bar") || ($inputs{'style'} eq "barcompare"))
{
    $is_defined_style = 1;

    my $bar_counter = 0;

    if (($inputs{'style'} eq "compare") || ($inputs{'style'} eq "barcompare"))
    {
	# add the baseline file to the list of input files
	unshift @ARGV, $inputs{'baseline'};
    }

    foreach $file (@ARGV)
    {
        if ((($inputs{'style'} eq "compare") || ($inputs{'style'} eq "barcompare")) && ($file eq "baseline"))
        {
            next;
        }

        if ($file =~ /plot-axis/)
        {
            $file =~ m/--plot-axis=(.*)/;
            $plot_axis = $1;
            next;
        }

        my $dataset_title = "";
        my @dataset_x;
        my @dataset_y;
        my $is_baseline = 0;

        if ((($inputs{'style'} eq "compare") || ($inputs{'style'} eq "barcompare")) && ($file eq $inputs{'baseline'}))
        {
            if (! -f $file)
            {
                print STDERR "ERROR: compare baseline file could not be found\n";
                exit 1;
            }
            $is_baseline = 1;
        }

        if (!open(INPUT, "<$file"))
        {
            print STDERR "ERROR: could not open $file\n";
            print STDERR "ERROR: pwd is " . `pwd` . "\n";
            next;
        }
        #print "Reading in \"$file\"\n";

        while (<INPUT>)
        {
            chomp($_);

            if ($_ =~ /\#LABEL/i)
            {
                @fields = split(":", $_, 2);
                $dataset_title = $fields[1];
                next;
            }

            $dataset_x[0] = $bar_counter;
            $dataset_y[0] = $_;
        }

        if (($is_baseline == 1) || ($inputs{'omit-empty-plotfiles'} == 0) || (($inputs{'omit-empty-plotfiles'} == 1) && (@dataset_y > 0) && array_is_unique(\@dataset_y)))
	{
	    push @datasets, { 'filename' => $file, 'title' => $dataset_title, 'x_data' => [ @dataset_x ], 'y_data' => [ @dataset_y ], 'is_baseline' => $is_baseline };
	    $bar_counter++;
	}
	else
	{
	    if ($inputs{'quiet'} == 0)
	    {
		print "Omitting datafile \"$file\"\n";
	    }
	}
    }
}

if (($inputs{'style'} eq "lines") || ($inputs{'style'} eq "linespoints") || ($inputs{'style'} eq "stackedlines") || ($inputs{'style'} eq "stackedlinespoints") || ($inputs{'style'} eq "groupedbar"))
{
    $is_defined_style = 1;
    my @stackedline_x_values;

    foreach $file (@ARGV)
    {
        if ($file eq "baseline")
        {
            next;
        }

        if ($file =~ /plot-axis/)
        {
            $file =~ m/--plot-axis=(.*)/;
            $plot_axis = $1;
            next;
        }

	if ($file =~ /trend/)
	{
	    if (($inputs{'style'} eq "stackedlines") || ($inputs{'style'} eq "stackedlinespoints"))
	    {
		print STDERR "Ignoring --trend since graph style is stacked\n";
		next;
	    }

	    $file =~ m/--trend=(.*)/;
	    $trend = $1;
	    next;
	}

        if (!open(INPUT, "<$file"))
        {
            print STDERR "ERROR: could not open $file\n";
            print STDERR "ERROR: pwd is " . `pwd` . "\n";
            next;
        }
        #print "Reading in \"$file\"\n";

        my $dataset_title = "";
        my @dataset_x;
        my @dataset_y;
        my $dataset_counter = 0;

        while (<INPUT>)
        {
            chomp($_);

            if ($_ =~ /\#LABEL/i)
            {
                @fields = split(":", $_, 2);
                $dataset_title = $fields[1];
                next;
            }

            @fields = split(" ", $_);
            $dataset_x[$dataset_counter] = $fields[0];
	    if ($inputs{'style'} eq "stackedlines")
	    {
		push @stackedline_x_values, $fields[0] + 0;
	    }
            $dataset_y[$dataset_counter] = $fields[1];
            $dataset_counter++;
        }

        if (($inputs{'omit-empty-plotfiles'} == 0) || (($inputs{'omit-empty-plotfiles'} == 1) && (@dataset_y > 0) && (array_sum(\@dataset_y) > 0)))
	{
	    push @datasets, { 'filename' => $file, 'title' => $dataset_title, 'x_data' => [ @dataset_x ], 'y_data' => [ @dataset_y ], 'plot-axis' => $plot_axis, 'trend' => $trend };
	}
	else
	{
	    if ($inputs{'quiet'} == 0)
	    {
		print "Omitting datafile \"$file\"\n";
	    }
	}
    }

    # when using a stacked line graph, each subsequent dataset must include all the x values
    # this is because if an x value is missing it is given an implied value instead of zero
    # this implied value comes from the line drawn between the existing surrounding data points
    # ie. if x=4,y=5 and x=6,y=5 in dataset A but there is no x=5 while another dataset B has a
    # x=5, then in dataset A y will be assumed to be y=5 at x=5 since a line will be drawn
    # straight from x=4,y=5 to x=6,y=5
    #
    # there may be situations where the user desires to disable this "feature", allow that with
    # a CLI option
    if (($inputs{'no-stackedline-zero-insertion'} != 1) && (($inputs{'style'} eq "stackedlines") || ($inputs{'style'} eq "stackedlinespoints")))
    {
	my $prev;

	# sort the array
	@stackedline_x_values = sort {$a <=> $b} @stackedline_x_values;

	# remove duplicate entries in the array
	$prev = "not equal to $stackedline_x_values[0]";
	@stackedline_x_values = grep($_ ne $prev && ($prev = $_, 1), @stackedline_x_values);

	for ($counter=0; $counter<@datasets; $counter++)
	{
	    my $foo = $datasets[$counter];
	    my @tmp_x = @{$foo->{'x_data'}};
	    my @tmp_y = @{$foo->{'y_data'}};

	    my %count = ();
	    my %diff = ();
	    my $e;

	    # create a hash with the number of occurences in each element across the two arrays
	    foreach $e (@tmp_x, @stackedline_x_values)
	    {
		$count{$e}++;
	    }

	    # use the hash created above to determine if an element does not occur in both arrays
	    # if it does not, make an entry for it in the difference hash
	    foreach $e (keys %count)
	    {
		if ($count{$e} != 2)
		{
		    $diff{$e} = 1;
		}
	    }

	    # if the difference array is not of size zero, then we must merge the arrays
	    if (keys(%diff) != 0)
	    {
		# inserting array elements into the middle of large arrays is extremely expensive
		# from a computational perspective
		# rather than do that, clear the arrays and then copy the data back in, adding the
		# new elements as we reach the proper index locations
		@{$datasets[$counter]->{'x_data'}} = ();
		@{$datasets[$counter]->{'y_data'}} = ();

		$counter3 = 0;
		foreach $key (sort { $a <=> $b } (keys %diff))
		{
		    while (($tmp_x[$counter3] < $key) && ($counter3 < @tmp_x))
		    {
			push @{$datasets[$counter]->{'x_data'}}, $tmp_x[$counter3];
			push @{$datasets[$counter]->{'y_data'}}, $tmp_y[$counter3];

			$counter3++;
		    }

		    push @{$datasets[$counter]->{'x_data'}}, $key;
		    push @{$datasets[$counter]->{'y_data'}}, 0;

		    # keep track of inserted x values
		    if (! exists $datasets[$counter]->{'inserted_x_values'}{$key})
		    {
			# 1 is an arbitrary value, the important value is the hash key
			$datasets[$counter]->{'inserted_x_values'}{$key} = 1;
		    }
		}

		for (; $counter3<@tmp_x; $counter3++)
		{
			push @{$datasets[$counter]->{'x_data'}}, $tmp_x[$counter3];
			push @{$datasets[$counter]->{'y_data'}}, $tmp_y[$counter3];
		}
	    }
	}
    }
}

my @stackedbar_labels;
my %stackedbar_labels_count;
my %families;
my @families_keys;
my %families_and_labels;
my $family_id = 1;

if (($inputs{'style'} eq "stackedbar") || ($inputs{'style'} eq "stackedbarcompare") || ($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
{
    $is_defined_style = 1;
 
    my $bar_counter = 0;

    foreach $file(@ARGV)
    {
	if ((($inputs{'style'} eq "stackedbarcompare") ||  ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability")) && ($file eq "baseline"))
	{
	    next;
	}

	if ($file =~ /plot-axis/)
	{
	    $file =~ m/--plot-axis=(.*)/;
	    $plot_axis = $1;
	    next;
	}
 
	my $dataset_label = "";

	if (!open(INPUT, "<$file"))
	{
	    print STDERR "ERROR: could not open $file\n";
	    print STDERR "ERROR: pwd is " . `pwd` . "\n";
	    next;
	}

	my $datagroup = 0;
	my $family_key;
 
	while (<INPUT>)
	{
	    chomp($_);
 
	    if ($_ =~ /\#LABEL/i)
	    {
		@fields = split(":", $_, 2);
		$dataset_label = $fields[1];
		if (($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
		{
		    if (! exists($stackedbar_labels_count{$dataset_label}))
		    {
			#print STDERR "dataset_label = $dataset_label\n";
			$stackedbar_labels_count{$dataset_label} = 0;
		    }
		    if ($inputs{'style'} ne "scalability")
		    {
			$stackedbar_labels_count{$dataset_label}++;
			$datagroup = $stackedbar_labels_count{$dataset_label};
			$dataset_label = $dataset_label . "__SUFFIX__" . $datagroup;
		    }
		}
		else
		{
		    if (is_in_array($dataset_label, \@stackedbar_labels))
		    {
			print STDERR "ERROR: Plot files detected with the same label for stackedbar graph style.  The generated graph will be incorrect.\n";
		    }
		}
		if ($inputs{'style'} ne "scalability")
		{
		    push @stackedbar_labels, $dataset_label;
		}
		next;
	    }
 
	    @fields = split(",", $_);

	    if ($inputs{'style'} eq "scalability")
	    {
		if (! exists($families_and_labels{$fields[0]}))
		{
		    $families_and_labels{$fields[0]} = $family_id++;
		}

		if (! exists($families_and_labels{$dataset_label}->{$fields[0]}))
		{
		    $families_and_labels{$dataset_label}->{$fields[0]} = 1;
		    $stackedbar_labels_count{$dataset_label}++;
		}
		else
		{
		    $families_and_labels{$dataset_label}->{$fields[0]}++;
		}
		$datagroup = $families_and_labels{$fields[0]}; #$families_and_labels{$dataset_label}->{$fields[0]};
		$dataset_label = $dataset_label . "__SUFFIX__" . $datagroup;
		if (! is_in_array($dataset_label, \@stackedbar_labels))
		{
		    push @stackedbar_labels, $dataset_label;
		}
	    }

	    if (($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
	    {
		if ($inputs{'style'} eq "scalability")
		{
		    $family_key = $fields[0] . "__SUFFIX__" . $families_and_labels{$fields[0]};
		}
		else
		{
		    $family_key = $fields[0] . "__SUFFIX__" . $datagroup;
		}
	    }
	    else
	    {
		$family_key = $fields[0];
	    }
	    push_unique(\@families_keys, $family_key);
	    $families{$family_key}->{$dataset_label} = $fields[1];
	}

	$bar_counter++;
    }

#    print "1 "; print Dumper \%stackedbar_labels_count;
#    print "2 "; print Dumper \@stackedbar_labels;
#    print "3 "; print Dumper \%families_and_labels;
#    print "4 "; print Dumper \@families_keys;
#    print "5 "; print Dumper \%families;
    my $key;
    my $i;

    # create the dataset from the data read in above
    # fill in a zero for values that are missing (ie a family does not have an entry from a given plot file)
    foreach $key (@families_keys)
    {
	my @dataset_y;
	my $datagroup = 0;

	if (($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
	{
	    $key =~ m/.*__SUFFIX__([0-9]+)/;
	    $datagroup = $1;
	}

	for($i=0; $i<@stackedbar_labels; $i++)
	{
	    if (($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
	    {
		$stackedbar_labels[$i] =~ m/.*__SUFFIX__([0-9]+)/;
		if ($datagroup != $1)
		{
		    next;
		}
	    }

	    if (exists($families{$key}->{$stackedbar_labels[$i]}))
	    {
		push @dataset_y, $families{$key}->{$stackedbar_labels[$i]};
	    }
	    else
	    {
		push @dataset_y, 0;
	    }
	}

	if (($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
	{
	    $key =~ s/__SUFFIX__.*//;
	}

	push @datasets, { 'label' => $key, 'y_data' => [ @dataset_y ], 'datagroup' => $datagroup };
    }
}

if ($is_defined_style == 0)
{
    print STDERR "ERROR: An undefined style was specified\n";
    exit 1;
}

if (@datasets == 0)
{
    if ($inputs{'quiet'} == 0)
    {
	print STDERR "ERROR: No data files were specified.\n";
    }
    exit 1;
}

if ($inputs{'debug'} == 3)
{
    print "datasets hash =\n";
    print Dumper \@datasets;
}


# end of process the input files #######################################################


# produce a table if specified #########################################################

sub print_table
{
    my $tbl_data = shift;
    my $tbl_filename = shift;
    my $tbl_type = shift;
    my $precision = shift;

    # need a really long string from which to print sub-strings -- it is really long so that hopefully it is always big enough
    my $table_line = "-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
    my $col_width = 0;
    my $col_width_r = 0;
    my $table_width = 0;
    my $col_width_padding = 6;
    my $table_width_padding = 4;
    my $num_columns = 2;
    my $combined_average_string = "Combined Average";
    my $combined_median_string = "Combined Median";

    my $tbl_fh;

    if (! open($tbl_fh, ">$tbl_filename.$tbl_type"))
    {
	print STDERR "ERROR: Could not open $tbl_filename.$tbl_type to write table\n";
	exit 1;
    }

    # if combined average data has been included fix the precision and analyze the label length
    if (exists $tbl_data->{'combined_average'})
    {
	$tbl_data->{'combined_average'} = sprintf("%.*f", $precision, $tbl_data->{'combined_average'});
	$col_width = max($col_width, length $combined_average_string);
    }

    # if combined median data has been included fix the precision and analyze the label length
    if (exists $tbl_data->{'combined_median'})
    {
	$tbl_data->{'combined_median'} = sprintf("%.*f", $precision, $tbl_data->{'combined_median'});
	$col_width = max($col_width, length $combined_median_string);
    }

    foreach my $key ("average", "median")
    {
	# fix the precision of supplied data and check the date to see if the columns should be widened
	for (my $i=0; $i<@{$tbl_data->{'row_data'}{$key}}; $i++)
	{
	    $tbl_data->{'row_data'}{$key}[$i] = sprintf("%.*f", $precision, $tbl_data->{'row_data'}{$key}[$i]);
	    $col_width = max($col_width, length $tbl_data->{'row_data'}{$key}[$i]);
	}
    }

    # check the label lengths of the titles to see if the columns should be widened
    for (my $i=0; $i<@{$tbl_data->{'row_titles'}}; $i++)
    {
	$col_width = max($col_width, length $tbl_data->{'row_titles'}[$i]);
    }

    # compute the column and table widths if producing a txt table
    if ($tbl_type eq "txt")
    {
	$col_width = $col_width + $col_width_padding;
	$col_width_r = $col_width;
	my $interior_table_width = $col_width + 2 * $col_width_r;
	$table_width = $interior_table_width + $table_width_padding;

	# if the table title is wider than the table, fix it
	if ((length $tbl_data->{'title'}) > $interior_table_width)
	{
	    $interior_table_width = (length $tbl_data->{'title'}) + $col_width_padding;
	    $col_width = floor($interior_table_width / 2);
	    $col_width_r = ceil($interior_table_width / 2);
	    $table_width = $interior_table_width + $table_width_padding;
	}
    }

    # print the "header" of the table
    if ($tbl_type eq "txt")
    {
	printf { $tbl_fh } ("%s\n", substr($table_line, 0, $table_width));
	my $tmp_col_width_r = ceil((($col_width_r * 3) - length($tbl_data->{'title'})) / 2);
	my $tmp_col_width_l = floor((($col_width * 3) - length($tbl_data->{'title'})) / 2);
	printf { $tbl_fh } ("| %*s%*s%*s |\n", $tmp_col_width_l, "", length($tbl_data->{'title'}), $tbl_data->{'title'}, $tmp_col_width_r, "");
	printf { $tbl_fh } ("%s\n", substr($table_line, 0, $table_width));
	printf { $tbl_fh } ("| %*s%*s%*s |\n", -$col_width, "Data Sets", $col_width_r, "Data Set Average", $col_width_r, "Data Set Median");
	printf { $tbl_fh } ("%s\n", substr($table_line, 0, $table_width));
    }
    elsif ($tbl_type eq "csv")
    {
	printf { $tbl_fh } ("%s\n", $tbl_data->{'title'});
	printf { $tbl_fh } ("%s,%s,%s\n", "Data Sets", "Data Set Average", "Data Set Median");
    }
    elsif ($tbl_type eq "tapwiki")
    {
	print { $tbl_fh } ("||Data Sets||Data Set Average||Data Set Median||\n");
    }
    elsif ($tbl_type eq "html")
    {
	print { $tbl_fh } ("<style type='text/css'>\n");
	print { $tbl_fh } (".chart { border: 2px solid black; border-collapse: collapse; font-family: monospace; }\n");
	print { $tbl_fh } (".chart TH { padding-left: 6px; padding-right: 6px; padding-top: 2px; padding-bottom: 2px; border: 1px solid silver; }\n");
	print { $tbl_fh } (".chart TD { padding-left: 6px; padding-right: 6px; padding-top: 2px; padding-bottom: 2px; border: 1px solid silver; }\n");
	print { $tbl_fh } (".chart TR.header { border-bottom: 2px solid black; }\n");
	print { $tbl_fh } (".chart TR.footer { border-top: 2px solid black; }\n");
	print { $tbl_fh } ("</style>\n");
	printf { $tbl_fh } ("<table class='chart'>\n");
	printf { $tbl_fh } ("<tr class='header'><th colspan='3'>%s</td></tr>\n", $tbl_data->{'title'});
	printf { $tbl_fh } ("<tr class='header'><th align='left'>%s</th><th align='right'>%s</th><th align='right'>%s</th></tr>\n", "Data Sets", "Data Set Average", "Data Set Median");
    }

    # print the "body" of the table
    for ($counter=0; $counter<@{$tbl_data->{'row_titles'}}; $counter++)
    {
	if ($tbl_type eq "txt")
	{
	    printf { $tbl_fh } ("| %*s%*s%*s |\n", -$col_width, $tbl_data->{'row_titles'}[$counter], $col_width_r, $tbl_data->{'row_data'}{'average'}[$counter], $col_width_r, $tbl_data->{'row_data'}{'median'}[$counter]);
	}
	elsif ($tbl_type eq "csv")
	{
	    printf { $tbl_fh } ("%s,%s,%s\n", $tbl_data->{'row_titles'}[$counter], $tbl_data->{'row_data'}{'average'}[$counter], $tbl_data->{'row_data'}{'median'}[$counter]);
	}
	elsif ($tbl_type eq "tapwiki")
	{
	    printf { $tbl_fh } ("|%s|%s|%s|\n", $tbl_data->{'row_titles'}[$counter], $tbl_data->{'row_data'}{'average'}[$counter], $tbl_data->{'row_data'}{'median'}[$counter]);
	}
	elsif ($tbl_type eq "html")
	{
	    printf { $tbl_fh } ("<tr><td align='left'>%s</td><td align='right'>%s</td><td align='right'>%s</td></tr>\n", $tbl_data->{'row_titles'}[$counter], $tbl_data->{'row_data'}{'average'}[$counter], $tbl_data->{'row_data'}{'median'}[$counter]);
	}
    }

    # if combined average data is included print the combined average footer
    if (exists $tbl_data->{'combined_average'})
    {
	if ($tbl_type eq "txt")
	{
	    printf { $tbl_fh } ("%s\n", substr($table_line, 0, $table_width));
	    printf { $tbl_fh } ("| %*s%*s%*s |\n", -$col_width, $combined_average_string, $col_width_r, $tbl_data->{'combined_average'}, $col_width_r, "");
	}
	elsif ($tbl_type eq "csv")
	{
	    printf { $tbl_fh } ("%s,%s,%s\n", $combined_average_string, $tbl_data->{'combined_average'}, "");
	}
	elsif ($tbl_type eq "tapwiki")
	{
	    printf { $tbl_fh } ("|%s|%s|%s|\n", $combined_average_string, $tbl_data->{'combined_average'}, " ");
	}
	elsif ($tbl_type eq "html")
	{
	    printf { $tbl_fh } ("<tr class='footer'><th align='left'>%s</th><td align='right'>%s</td><td align='right'>%s</td></tr>\n", $combined_average_string, $tbl_data->{'combined_average'}, "");
	}
    }

    # if combined median data is included print the combined median footer
    if (exists $tbl_data->{'combined_median'})
    {
	if ($tbl_type eq "txt")
	{
	    printf { $tbl_fh } ("%s\n", substr($table_line, 0, $table_width));
	    printf { $tbl_fh } ("| %*s%*s%*s |\n", -$col_width, $combined_median_string, $col_width_r, "", $col_width_r, $tbl_data->{'combined_median'});
	}
	elsif ($tbl_type eq "csv")
	{
	    printf { $tbl_fh } ("%s,%s,%s\n", $combined_median_string, "", $tbl_data->{'combined_median'});
	}
	elsif ($tbl_type eq "tapwiki")
	{
	    printf { $tbl_fh } ("|%s|%s|%s|\n", $combined_median_string, " ", $tbl_data->{'combined_median'});
	}
	elsif ($tbl_type eq "html")
	{
	    printf { $tbl_fh } ("<tr class='footer'><th align='left'>%s</th><td align='right'>%s</td><td align='right'>%s</td></tr>\n", $combined_median_string, "", $tbl_data->{'combined_median'});
	}
    }

    # print the footer if the table type requires one
    if ($tbl_type eq "txt")
    {
	printf { $tbl_fh } ("%s\n", substr($table_line, 0, $table_width));
    }
    elsif ($tbl_type eq "html")
    {
	print { $tbl_fh } ("</table>\n");
    }

    close $tbl_fh;
}

if ($inputs{'table'})
{
    # verify that a valid table type has been specified
    if (($inputs{'table'} =~ /txt/) ||
	($inputs{'table'} =~ /csv/) ||
	($inputs{'table'} =~ /tapwiki/) ||
	($inputs{'table'} =~ /html/))
    {
	my %table_data = ();

	my $table_filename = $inputs{'outfile'};
	$table_data{'title'} = $inputs{'outfile'};
	$table_filename =~ s/ /_/g;
	$table_filename =~ s|/|_|g;

	if (($inputs{'style'} eq "compare") ||
	    ($inputs{'style'} eq "barcompare") ||
	    ($inputs{'style'} eq "bar") ||
	    ($inputs{'style'} eq "groupedbar") ||
	    ($inputs{'style'} eq "stackedbar") ||
	    ($inputs{'style'} eq "stackedbarcompare") ||
	    ($inputs{'style'} eq "groupedstackedbar") ||
	    ($inputs{'style'} eq "groupedstackedbarcompare") ||
	    ($inputs{'style'} eq "scalability"))
	{
	    print STDERR "ERROR: Table output is not yet available for the specified graph style [$inputs{'style'}].\n";
	}

	if (($inputs{'style'} eq "lines") ||
	    ($inputs{'style'} eq "linespoints") ||
	    ($inputs{'style'} eq "stackedlines") ||
	    ($inputs{'style'} eq "stackedlinespoints"))
	{
	    # initialize the arrays
	    $table_data{'row_titles'} = ();
	    $table_data{'row_data'}{'average'} = ();
	    $table_data{'row_data'}{'median'} = ();

	    my $range_limited_min = 0;
	    my $range_limited_max = 0;
	    my $range_max;
	    my $range_min;

	    if (string_is_set($inputs{'x-range'})) {
		@fields = split(":", $inputs{'x-range'});
		if ($fields[0] !~ /\*/) {
		    $range_min = $fields[0];
		    $range_limited_min = 1
		}
		if ($fields[1] !~ /\*/) {
		    $range_max = $fields[1];
		    $range_limited_max = 1;
		}
	    }

	    my %stacked_average_hash;

	    # calculate the averages/medians and populate the data structure for each dataset
	    for ($counter=0; $counter<@datasets; $counter++)
	    {
		my @median_array;
		my $sum;
		my $sum_elements = 0;
		for (my $element=0; $element<@{$datasets[$counter]->{'y_data'}}; $element++) {
		    if (exists $datasets[$counter]->{'inserted_x_values'}{$datasets[$counter]->{'x_data'}[$element]})
		    {
			next;
		    }

		    if ($range_limited_min && ($datasets[$counter]->{'x_data'}[$element] < $range_min))
		    {
			next;
		    }

		    if ($range_limited_max && ($datasets[$counter]->{'x_data'}[$element] > $range_max))
		    {
			next;
		    }

		    $sum += $datasets[$counter]->{'y_data'}[$element];
		    $sum_elements++;
		    push @median_array, $datasets[$counter]->{'y_data'}[$element];

		    if (! exists $stacked_average_hash{$datasets[$counter]->{'x_data'}[$element]})
		    {
			$stacked_average_hash{$datasets[$counter]->{'x_data'}[$element]} = $datasets[$counter]->{'y_data'}[$element];
		    }
		    else
		    {
			$stacked_average_hash{$datasets[$counter]->{'x_data'}[$element]} += $datasets[$counter]->{'y_data'}[$element];
		    }
		}

		push @{$table_data{'row_titles'}}, $datasets[$counter]->{'title'};
		if ($sum_elements)
		{
		    push @{$table_data{'row_data'}{'average'}}, ( $sum / $sum_elements );
		}
		else
		{
		    push @{$table_data{'row_data'}{'average'}}, 0;
		}

		if (@median_array)
		{
		    @median_array = sort { $a <=> $b } @median_array;
		    push @{$table_data{'row_data'}{'median'}}, $median_array[POSIX::ceil(@median_array/2)-1];
		}
		else
		{
		    push @{$table_data{'row_data'}{'median'}}, 0;
		}
	    }

	    # build summation data for these graph styles
	    if (($inputs{'style'} eq "stackedlines") ||
		($inputs{'style'} eq "stackedlinespoints"))
	    {
		my @combined_median_array;
		$table_data{'combined_average'} = 0;
		foreach my $field (keys %stacked_average_hash)
		{
		    $table_data{'combined_average'} += $stacked_average_hash{$field};
		    push @combined_median_array, $stacked_average_hash{$field};
		}
		$table_data{'combined_average'} /= keys(%stacked_average_hash);

		@combined_median_array = sort { $a <=> $b } @combined_median_array;
		$table_data{'combined_median'} = $combined_median_array[POSIX::ceil(@combined_median_array/2)-1];
	    }

	    @fields = split(":", $inputs{'table'});

	    foreach my $field (@fields) {
		# print the table
		print_table(\%table_data, $inputs{'outdir'} . "/" . $table_filename, $field, 2);
	    }
	}
    }
    else
    {
	print STDERR "ERROR: You must specify a valid table output type (csv, txt, or html) and not '$inputs{'table'}'\n";
    }
}

# end of produce a table ###############################################################


# do the actual graphing ###############################################################

use perlchartdir;

# define properties for the layout of the graph
my %graph_properties = ( 'width' => $inputs{'x-pixels'},
			 'height' => 504,
			 'plot-area' => { 'start_x' => 65,
					  'start_y' => 35,
					  'height' => 390 },
			 'legend' => { 'start_x' => 30,
				       'font-size' => $inputs{'legend-font-size'},
				       'width-reservation' => 65 } );
$graph_properties{'legend'}{'width-reservation'} = $graph_properties{'plot-area'}{'start_x'} + 25;
$graph_properties{'plot-area'}{'width'} = $graph_properties{'width'} - $graph_properties{'legend'}{'width-reservation'};
$graph_properties{'legend'}{'start_y'} = $graph_properties{'height'} - 40;
$graph_properties{'legend'}{'width'} = $graph_properties{'width'} - 2 * $graph_properties{'legend'}{'start_x'};
$graph_properties{'legend'}{'height'} = 30;


# create an XYChart object and define the plot area
my $chart = new XYChart($graph_properties{'width'}, $graph_properties{'height'}, 0xffffff, 0x0, 0);
# set up the plot area with transparent vertical lines (the default) if we are doing a bar related chart


# define the legend/key 
if ((($inputs{'legend-position'} eq "default") || ($inputs{'legend-position'} eq "right")) && (!($inputs{'y2-range'} eq "") || !($inputs{'y2_label'} eq "")))
{
    $graph_properties{'legend'}{'start_x'} += 40;
    $graph_properties{'legend'}{'width'} -= 40;
}


# shrink the plot area if room is needed for angled labels
if (! $inputs{'x-label-angle'} eq "")
{
    $graph_properties{'plot-area'}{'height'} -= 20;
}


if ($inputs{'style'} =~ /bar/)
{
    $chart->setPlotArea($graph_properties{'plot-area'}{'start_x'},
			$graph_properties{'plot-area'}{'start_y'},
			$graph_properties{'plot-area'}{'width'},
			$graph_properties{'plot-area'}{'height'},
			0xffffff,
			-1,
			-1,
			0xc0c0c0);
}
else
{
    $chart->setPlotArea($graph_properties{'plot-area'}{'start_x'},
			$graph_properties{'plot-area'}{'start_y'},
			$graph_properties{'plot-area'}{'width'},
			$graph_properties{'plot-area'}{'height'},
			0xffffff,
			-1,
			-1,
			0xc0c0c0,
			-1);
}
$chart->setClipping(0);


# set the title and its attributes
$chart->addTitle($inputs{'chart_title'}, $inputs{'font'}, $inputs{'title-font-size'}, 0xffffff)->setBackground(0x00006D, -1, 0);


# create the legend
$chart->addLegend($graph_properties{'legend'}{'start_x'},
		  $graph_properties{'legend'}{'start_y'},
		  0,
		  $inputs{'font'},
		  $graph_properties{'legend'}{'font-size'})->setBackground($perlchartdir::Transparent, 0xffffff);
my $legend = $chart->getLegend();
#$legend->setHeight($graph_properties{'legend'}{'height'});
$legend->setBackground($perlchartdir::Transparent, $perlchartdir::Transparent);

# debug code to draw a box around the legend (should be commented out for normal use)
#$legend->setBackground(0xCCCCCC);

my $extra_legend_entries = 0;
my $legend_entry;
foreach $legend_entry ("vert-zone", "horz-zone", "vert-line", "horz-line")
{
    if ($inputs{$legend_entry})
    {
	for (my $i=0; $i<@{$inputs{$legend_entry}}; $i++)
	{
	    # count the occurences of ':' to see if various objects include legend entries
	    my $count = (($inputs{$legend_entry}[$i] =~ tr/://) + 1);

	    if ($legend_entry =~ /zone/)
	    {
		if ($count == 4)
		{
		    $extra_legend_entries++;
		}
	    }
	    else
	    {
		if ($count == 3)
		{
		    $extra_legend_entries++;
		}
	    }
	}
    }
}

# configure the legend columns
if ((@datasets + $extra_legend_entries) < 5)
{
    $legend->setCols(scalar(@datasets) + $extra_legend_entries);
}
else
{
    $legend->setCols(5);
}

$legend->setWidth($graph_properties{'legend'}{'width'});
$legend->setKeySpacing(10, 7);
$legend->setKeySize(15);


# Y Axis settings
$chart->yAxis()->setLabelStyle($inputs{'font'}, $inputs{'axis-font-size'});
$chart->yAxis()->setTitle($inputs{'y_label'}, $inputs{'font'}, $inputs{'axis-label-font-size'});      #Add a title to the y axis
if (string_is_set($inputs{'y-range'}) || string_is_set($inputs{'y-scale'}))
{
    if (string_is_set($inputs{'y-range'}))
    {
        $inputs{'y-range'} =~ s/\*/$perlchartdir::NoValue/g;
        @fields = split(":", $inputs{'y-range'});

        if (string_is_set($inputs{'y-scale'}) && ($inputs{'y-scale'} =~ /log/))
        {
            $chart->yAxis->setLogScale($fields[0], $fields[1], $inputs{'y-tics'});
        }
        else
        {
            $chart->yAxis->setLinearScale($fields[0], $fields[1], $inputs{'y-tics'});
        }
    }
    elsif (string_is_set($inputs{'y-scale'}) && ($inputs{'y-scale'} =~ /log/))
    {
        $chart->yAxis->setLogScale3();
    }
    else
    {
        $chart->yAxis->setLinearScale3();
    }
}

# Y 2 Axis settings
if (string_is_set($inputs{'y2_label'}))
{
    $chart->yAxis2()->setLabelStyle($inputs{'font'}, $inputs{'axis-font-size'});
    $chart->yAxis2()->setTitle($inputs{'y2_label'}, $inputs{'font'}, $inputs{'axis-label-font-size'});      #Add a title to the y2 axis
}
if (string_is_set($inputs{'y2-range'}) || string_is_set($inputs{'y2-scale'}))
{
    if (string_is_set($inputs{'y2-range'}))
    {
        $inputs{'y2-range'} =~ s/\*/$perlchartdir::NoValue/g;
        @fields = split(":", $inputs{'y2-range'});

        if (string_is_set($inputs{'y2-scale'}) && ($inputs{'y2-scale'} =~ /log/))
        {
            $chart->yAxis2->setLogScale($fields[0], $fields[1]);
        }
        else
        {
            $chart->yAxis2->setLinearScale($fields[0], $fields[1]);
        }
    }
    elsif (string_is_set($inputs{'y2-scale'}) && ($inputs{'y2-scale'} =~ /log/))
    {
        $chart->yAxis2->setLogScale3();
    }
    else
    {
        $chart->yAxis2->setLinearScale3();
    }
}


# X Axis settings
$chart->xAxis()->setLabelStyle($inputs{'font'}, $inputs{'axis-font-size'});
$chart->xAxis()->setTitle($inputs{'x_label'}, $inputs{'font'}, $inputs{'axis-label-font-size'});      #Add a title to the x axis
if ((($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare")) && (! $inputs{'y2_label'} eq ""))
{
    $chart->xAxis()->setTitle($inputs{'x_label'} . " -- pairs are ( " . $inputs{'y_label'} . " / " . $inputs{'y2_label'} . " )");
}
$chart->xAxis()->setMinTickInc(2);
if (string_is_set($inputs{'x-range'}) || string_is_set($inputs{'x-scale'}))
{
    if (string_is_set($inputs{'x-range'}))
    {
    	$inputs{'x-range'} =~ s/\*/$perlchartdir::NoValue/g;
    	@fields = split(":", $inputs{'x-range'});

        if (string_is_set($inputs{'x-scale'}) && ($inputs{'x-scale'} =~ /log/))
        {
            $chart->xAxis->setLogScale($fields[0], $fields[1], $inputs{'x-tics'});
        }
        else
        {
            $chart->xAxis->setLinearScale($fields[0], $fields[1], $inputs{'x-tics'});
        }
    }
    elsif (string_is_set($inputs{'x-scale'}) && ($inputs{'x-scale'} =~ /log/))
    {
        $chart->xAxis->setLogScale3();
    }
    else
    {
        $chart->xAxis->setLinearScale3();
    }
}



# define a set of colors
# The colors for a - aw were obtained using a color wheel.  The following URLs link to the combinations used to generate the two halfs of the range
# a - p = http://colorschemedesigner.com/previous/colorscheme2/index-en.html?tetrad;50;0;60;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;0
# q - af = http://colorschemedesigner.com/previous/colorscheme2/index-en.html?tetrad;50;0;169;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;0
# ag - aw = http://colorschemedesigner.com/previous/colorscheme2/index-en.html?tetrad;50;0;4;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;-1;-1;1;-0.7;0.25;1;0.5;1;0
# ax - bq = http://colorschemedesigner.com/#2Q62aAoVMIHb6
my $colors = [ ["black", 0x00000000],
	       ["red", 0x00FF0000],
	       ["green", 0x00009900],
	       ["blue", 0x000000FF],
	       ["magenta", 0x00FF00FF],
	       ["tangerine", 0x00E69900],
	       ["maroon", 0x00AC3839],
	       ["cyan", 0x0000FFFF],
	       ["pink", 0x00FFCACD],
	       ["hunter", 0x00007D00],
	       ["aqua", 0x0000CACD],
	       ["purple", 0x00AA44AA],
	       ["yellow", 0x00FFFF00],
	       ["muave", 0x00C0C0FF],
	       ["orange", 0x00FF8000],
	       ["lime", 0x0000FF00],
	       ["midyellow", 0x00C0C000],
	       ["lightgreen", 0x00C0FFC0],
	       ["dodgerblue", 0x001E90FF],
	       ["lighslategrey", 0x00778899],
	       ["navajowhite", 0x00FFDEAD],
	       ["violetred", 0x00CD3278],
	       ["darkgrey", 0x00808080],
	       ["chocolate", 0x00D2691E],
	       ["grey", 0x00AAAAAA],
	       ["a", 0x00FF9900],
	       ["b", 0x000033CC],
	       ["c", 0x00400099],
	       ["d", 0x00FFE500],
	       ["e", 0x00B36B00],
	       ["f", 0x0000248F],
	       ["g", 0x002D006B],
	       ["h", 0x00B3A000],
	       ["i", 0x00FFE6BF],
	       ["j", 0x00BFCFFF],
	       ["k", 0x00DABFFF],
	       ["l", 0x00FFF9BF],
	       ["m", 0x00FFCC80],
	       ["n", 0x00809FFF],
	       ["o", 0x00B580FF],
	       ["p", 0x00FFF280],
	       ["q", 0x0025F200],
	       ["r", 0x00ED004B],
	       ["s", 0x00FF6D00],
	       ["t", 0x00008CA1],
	       ["u", 0x001AAA00],
	       ["v", 0x00A60035],
	       ["w", 0x00B34C00],
	       ["x", 0x00006270],
	       ["y", 0x00C9FFBF],
	       ["z", 0x00FFBFD4],
	       ["aa", 0x00FFDBBF],
	       ["ab", 0x00BFF7FF],
	       ["ac", 0x0093FF80],
	       ["ad", 0x00FF80A8],
	       ["ae", 0x00FFB680],
	       ["af", 0x0080EEFF],
	       ["ag", 0x00FF0E00],
	       ["ah", 0x0000C41B],
	       ["ai", 0x0000F9BA],
	       ["aj", 0x000059BA],
	       ["ak", 0x00FF8700],
	       ["al", 0x00B30A00],
	       ["am", 0x00008913],
	       ["an", 0x00003E82],
	       ["ao", 0x00B35F00],
	       ["ap", 0x00FFC3BF],
	       ["aq", 0x00BFFFC8],
	       ["ar", 0x00BFDEFF],
	       ["as", 0x00FFE1BF],
	       ["at", 0x00FF8780],
	       ["au", 0x0080FF91],
	       ["av", 0x0080BCFF],
	       ["aw", 0x00FFC380],
	       ["ax", 0x0000F610],
	       ["ay", 0x000F7EF0],
	       ["az", 0x00D8FE00],
	       ["ba", 0x00FF0700],
	       ["bb", 0x00399E3F],
	       ["bc", 0x003E6B9B],
	       ["bd", 0x0093A33A],
	       ["be", 0x00A43D3B],
	       ["bf", 0x00007B08],
	       ["bg", 0x00023C78],
	       ["bh", 0x006C7F00],
	       ["bi", 0x00800300],
	       ["bj", 0x0015F824],
	       ["bk", 0x002389F3],
	       ["bl", 0x00DBFE16],
	       ["bm", 0x00FF1C16],
	       ["bn", 0x0027F834],
	       ["bo", 0x003391F3],
	       ["bp", 0x00DEFE28],
	       ["bq", 0x00DEFE28]];
# check if there are enough colors for all the datasets
if (@datasets > @{$colors}) {
    # seed the random number generator with a known value to get repeatable results
    srand(1);

    # create as many new colors as it takes to have 1 per dataset
    for (my $i=@{$colors}; $i<@datasets; $i++) {
	# choose the new color at random and make sure we generate an integer value
	$colors->[$i] = [$i, int(rand(0xFFFFFF))];
    }
}
my %colors_by_name;

my $lines = [ ["solid", 0xFF00FF00], ["dash", $perlchartdir::DashLine], ["dot", $perlchartdir::DotLine], ["dotdash", $perlchartdir::DotDashLine], ["altdash", $perlchartdir::AltDashLine] ];

for ($counter=0; $counter<@$colors; $counter++)
{
    $colors_by_name{$colors->[$counter][0]} = $colors->[$counter][1];
}
if ($inputs{'debug'} == 4)
{
    print "colors_by_name hash=\n";
    print Dumper \%colors_by_name;
}

my @dataset_colors;
@fields = split(":", $inputs{'graphtype'});
my $groups = $fields[0] + $fields[1];
$counter3 = 0;
for ($counter=1; $counter<@$colors; $counter++)
{
    if ($groups == 0)
    {
        $dataset_colors[$counter-1] = $colors->[$counter][1];
    }
    else
    {
        for ($counter2=0; $counter2<$groups; $counter2++)
        {
            $dataset_colors[$counter3] = $chart->dashLineColor($colors->[$counter][1], $lines->[$counter2][1]);
            $counter3++;
        }
    }
}
if ($inputs{'debug'} == 5)
{
    print "dataset_colors hash =\n";
    print Dumper \@dataset_colors;
}

if (($inputs{'style'} eq "lines") || ($inputs{'style'} eq "linespoints") || ($inputs{'style'} eq "stackedlines") || ($inputs{'style'} eq "stackedlinespoints") || ($inputs{'style'} eq "groupedbar"))
{
    for (my $counter=0; $counter<@datasets; $counter++) {
	# check if datapoint compression is required for the current dataset
	# there needs to be at least double the datapoints for compression to work
	if (@{$datasets[$counter]->{'x_data'}} > (2 * $inputs{'datapoint-compression-threshold'} * $graph_properties{'plot-area'}{'width'}))
	{
	    my $compression_ratio = floor(@{$datasets[$counter]->{'x_data'}} / ($inputs{'datapoint-compression-threshold'} * $graph_properties{'plot-area'}{'width'}));

	    print STDERR "Compressing data points for '" . $datasets[$counter]->{'title'} . "' " .
		"in '" . $datasets[$counter]->{'filename'} . "' " .
		"using compression ratio " . $compression_ratio . ":1 " .
		"from " . @{$datasets[$counter]->{'x_data'}} . " to " . floor(@{$datasets[$counter]->{'x_data'}} / $compression_ratio) . "\n";

	    my @new_x_array;
	    my @new_y_array;

	    my $new_x_datapoint = 0;;
	    my $new_y_datapoint = 0;

	    my $x = 0;
	    for (my $i=0; $i<@{$datasets[$counter]->{'x_data'}}; $i++)
	    {
		$new_x_datapoint += $datasets[$counter]->{'x_data'}[$i];
		$new_y_datapoint += $datasets[$counter]->{'y_data'}[$i];

		$x++;

		if (($x == $compression_ratio) || ($i == (@{$datasets[$counter]->{'x_data'}} - 1)))
		{
		    push @new_x_array, ($new_x_datapoint / $x);
		    push @new_y_array, ($new_y_datapoint / $x);

		    $x = 0;
		    $new_x_datapoint = 0;
		    $new_y_datapoint = 0;
		}
	    }

	    @{$datasets[$counter]->{'x_data'}} = ();
	    @{$datasets[$counter]->{'y_data'}} = ();

	    push @{$datasets[$counter]->{'x_data'}}, @new_x_array;
	    push @{$datasets[$counter]->{'y_data'}}, @new_y_array;

	    @new_x_array = ();
	    @new_y_array = ();
	}
    }
}

# add the data series to the chart, each as an individual layer
# this is needed so that each can have independent x axis values in order to create a true X,Y pairing
my @layers;
my @trend_layers;

if (($inputs{'style'} eq "compare") || ($inputs{'style'} eq "barcompare") || ($inputs{'style'} eq "bar"))
{
    # hide the dumb x axis labels
    $chart->xAxis->setLabels([""]);

    if (($inputs{'style'} eq "compare") || ($inputs{'style'} eq "barcompare"))
    {
	my $baseline_value;
	my $adjusted_value;

	# find the baseline value
	for ($counter=0; $counter<@datasets; $counter++)
	{
	    if ($datasets[$counter]->{'is_baseline'} == 1)
	    {
		if ($inputs{'style'} eq "compare")
		{
		    $chart->yAxis->addMark(0, 0x0);
		    $legend->addKey("Baseline = " . $datasets[$counter]->{'title'}, 0x0);
		}

		$baseline_value = $datasets[$counter]->{'y_data'}[0];
		$datasets[$counter]->{'y_label'} = "100%";
		last;
	    }
	}

	# calculate the percentage differences for each data point vs. the baseline
	for ($counter=0; $counter<@datasets; $counter++)
	{
	    if ($datasets[$counter]->{'is_baseline'} == 0)
	    {
		if ($datasets[$counter]->{'y_data'}[0] > $baseline_value)
		{
		    $adjusted_value = $datasets[$counter]->{'y_data'}[0] - $baseline_value;
		    $adjusted_value = $adjusted_value / $baseline_value;
		}
		else
		{
		    if ($datasets[$counter]->{'y_data'}[0] < $baseline_value)
		    {
			$adjusted_value = $baseline_value - $datasets[$counter]->{'y_data'}[0];
			$adjusted_value = -($adjusted_value / $baseline_value);
		    }
		    else
		    {
			$adjusted_value = 0;
		    }
		}

		# the difference here between compare and barcompare is that for compare we feed in the new
		# data into the y_data whereas for barcompare the numbers are stored in a new array
		if ($inputs{'style'} eq "compare")
		{
		    $datasets[$counter]->{'y_data'}[0] = $adjusted_value * 100;
		}
		else
		{
		    if ($inputs{'style'} eq "barcompare")
		    {
			$datasets[$counter]->{'y_label'} = $adjusted_value * 100;
			if ($datasets[$counter]->{'y_label'} > 0)
			{
			    $datasets[$counter]->{'y_label'} += 100;
			}
			if ($datasets[$counter]->{'y_label'} < 0)
			{
			    $datasets[$counter]->{'y_label'} = 100 + $datasets[$counter]->{'y_label'};
			}
			# format it as a one decimal percent (the regex removes everything after the first number
			# after the decimal and replaces it with a % sign)
			$datasets[$counter]->{'y_label'} =~ s/(\.[0-9]).*/\1%/g;
		    }
		}
	    }
	}
    }

    for ($counter=0; $counter<@datasets; $counter++)
    {
	# we only add the baseline file to the plot if we are doing a barcompare
        if (($inputs{'style'} eq "barcompare") || ($datasets[$counter]->{'is_baseline'} == 0))
        {
            $layers[$counter] = $chart->addBarLayer(multiply_y($datasets[$counter]->{'y_data'}), $dataset_colors[$counter], $datasets[$counter]->{'title'});

	    if (($inputs{'style'} eq "barcompare") && ($inputs{'suppress-bar-labels'} == 0))
	    {
		$layers[$counter]->addCustomAggregateLabel(0, $datasets[$counter]->{'y_label'}, $inputs{'font'}, $inputs{'chart-label-font-size'}, $perlchartdir::TextColor, $inputs{'bar-label-angle'});
	    }

            $layers[$counter]->setBorderColor(0xFF000000);
            $layers[$counter]->setXData($datasets[$counter]->{'x_data'});
            if (@datasets < 10)
            {
                $layers[$counter]->setBarWidth(40);
            }
            #$layers[$counter]->setAggregateLabelStyle($inputs{'font'}, $inputs{'chart-label-font-size'}, 0x0);
        }
    }
}

if ($inputs{'style'} eq "groupedbar")
{
    # in the stacked bar format the labels are the x_data and the values are the y_data

    $layers[0] = $chart->addBarLayer2($perlchartdir::Stack);
    $layers[0]->setBarGap(0.2, 0);

    my @groupedbar_labels;

    my $x;
    my $z;

    # determine the unique set of group labels
    for ($counter=0; $counter<@datasets; $counter++)
    {
	for ($x=0; $x<@{$datasets[$counter]->{'x_data'}}; $x++)
	{
	    my $unique = 0;

	    for ($z=0; $z<@groupedbar_labels; $z++)
	    {
		if ($groupedbar_labels[$z] eq $datasets[$counter]->{'x_data'}[$x])
		{
		    $unique = 1;
		}
	    }

	    if ($unique == 0)
	    {
		push @groupedbar_labels, $datasets[$counter]->{'x_data'}[$x];
	    }
	}
    }

    $chart->xAxis()->setLabels([ @groupedbar_labels ])->setFontAngle($inputs{'x-label-angle'});

    # use the unique set of group labels to fill in the holes in the data sets
    # (the chart director api only accepts linear lists of values so holes cause the data to shift into incorrect positions)
    for ($counter=0; $counter<@datasets; $counter++)
    {
	my @new_x_data = @groupedbar_labels;

	my @new_y_data;

	for ($x=0; $x<@new_x_data; $x++)
	{
	    push @new_y_data, 0;
	}

	for ($x=0; $x<@{$datasets[$counter]->{'x_data'}}; $x++)
	{
	    for ($z=0; $z<@new_x_data; $z++)
	    {
		if ($new_x_data[$z] eq $datasets[$counter]->{'x_data'}[$x])
		{
		    $new_y_data[$z] = $datasets[$counter]->{'y_data'}[$x];
		}
	    }
	}

	$datasets[$counter]->{'x_data'} = [ @new_x_data ];
	$datasets[$counter]->{'y_data'} = [ @new_y_data ];
    }

    for ($counter=0; $counter<@datasets; $counter++)
    {
	$layers[0]->addDataGroup($datasets[$counter]->{'title'});
	$layers[0]->addDataSet(multiply_y($datasets[$counter]->{'y_data'}), $dataset_colors[$counter], $datasets[$counter]->{'title'});
    }
}

if (($inputs{'style'} eq "stackedbar") || ($inputs{'style'} eq "stackedbarcompare") || ($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
{
    $layers[0] = $chart->addBarLayer2($perlchartdir::Stack);
    if (@stackedbar_labels < 10)
    {
        $layers[0]->setBarWidth(40);
    }

    my $total_bar_groups = 0;

    my $groupedstackedbarcompare_labels;
    my @baseline_value;
    my @baseline_index;

    if (($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
    {
	foreach $key (keys %stackedbar_labels_count)
	{
	    $total_bar_groups = max($total_bar_groups, $stackedbar_labels_count{$key})
	}

	for ($counter=1; $counter<$total_bar_groups+1;$counter++)
	{
	    $baseline_index[$counter] = -1;

	    # this is part one of handling an auto determined baseline
	    # first and last can be handled without examining an data
	    if ($inputs{'baseline'} =~ /auto:/)
	    {
		if ($inputs{'baseline'} =~ /first/)
		{
		    $baseline_index[$counter] = 0;
		}
		else
		{
		    if ($inputs{'baseline'} =~ /last/)
		    {
			$baseline_index[$counter] = @stackedbar_labels - 1;
		    }
		}
	    }

	    # initialize the array to zero and find the baseline if not doing an auto
	    for ($counter2=0; $counter2<@stackedbar_labels; $counter2++)
	    {
		$groupedstackedbarcompare_labels->[$counter][$counter2] = 0;

		if (($baseline_index[$counter] == -1) && ($stackedbar_labels[$counter2] eq $inputs{'baseline'}))
		{
		    $baseline_index[$counter] = $counter2;
		}
	    }

	    # find the cumulative sums for each bar
	    for ($counter2=0; $counter2<@datasets;$counter2++)
	    {
		if ($datasets[$counter2]->{'datagroup'} == $counter)
		{
		    for ($counter3=0; $counter3<@{$datasets[$counter2]->{'y_data'}}; $counter3++)
		    {
			$groupedstackedbarcompare_labels->[$counter][$counter3] += $datasets[$counter2]->{'y_data'}[$counter3];
		    }
		}
	    }

	    # this is part two of handling an auto determined baseline
	    # high and low must be found by scanning the cumulative sums previously calculated
	    if ($inputs{'baseline'} =~ /auto:/)
	    {
		my $max;
		my $min;

		if ($inputs{'baseline'} =~ /high/)
		{
		    $max = $groupedstackedbarcompare_labels->[$counter][0];
		    $baseline_index[$counter] = 0;
		    for ($counter2=1; $counter2<@{$groupedstackedbarcompare_labels->[$counter]}; $counter2++)
		    {
			if ($groupedstackedbarcompare_labels->[$counter][$counter2] > $max)
			{
			    $max = $groupedstackedbarcompare_labels->[$counter][$counter2];
			    $baseline_index[$counter] = $counter2;
			}
		    }
		}
		else
		{
		    if ($inputs{'baseline'} =~ /low/)
		    {
			$max = $groupedstackedbarcompare_labels->[$counter][0];
			$baseline_index[$counter] = 0;
			for ($counter2=1; $counter2<@{$groupedstackedbarcompare_labels->[$counter]}; $counter2++)
			{
			    if ($groupedstackedbarcompare_labels->[$counter][$counter2] < $max)
			    {
				$max = $groupedstackedbarcompare_labels->[$counter][$counter2];
				$baseline_index[$counter] = $counter2;
			    }
			}
		    }
		}
	    }

	    # get the baseline value from the determined baseline index
	    $baseline_value[$counter] = $groupedstackedbarcompare_labels->[$counter][$baseline_index[$counter]];

	    for ($counter2=0; $counter2<@{$groupedstackedbarcompare_labels->[$counter]}; $counter2++)
	    {
		if ($groupedstackedbarcompare_labels->[$counter][$counter2] == $baseline_value[$counter])
		{
		    # the current value is the baseline value so mark it as 100%
		    $groupedstackedbarcompare_labels->[$counter][$counter2] = "100%";
		}
		else
		{
		    # determine the percentage difference versus the baseline value and then do a regex to format it as
		    # a one decimal percent (the regex removes everything after the first number after the decimal and replaces
		    # it with a % sign)
		    $groupedstackedbarcompare_labels->[$counter][$counter2] = $groupedstackedbarcompare_labels->[$counter][$counter2] / $baseline_value[$counter] * 100;
		    $groupedstackedbarcompare_labels->[$counter][$counter2] =~ s/(\.[0-9]).*/\1/g;
		    $groupedstackedbarcompare_labels->[$counter][$counter2] .= "%";
		}
	    }

	    if ($inputs{'style'} eq "scalability")
	    {
		for ($counter2=0; $counter2<@datasets;$counter2++)
		{
		    if ($datasets[$counter2]->{'datagroup'} == $counter)
		    {
			for ($counter3=0; $counter3<@{$groupedstackedbarcompare_labels->[$counter]}; $counter3++)
			{
			    if ($groupedstackedbarcompare_labels->[$counter][$counter3] != "0%")
			    {
				$datasets[$counter2]->{'y_data'}[$counter3] = $groupedstackedbarcompare_labels->[$counter][$counter3];
				$datasets[$counter2]->{'y_data'}[$counter3] =~ s/%//;
			    }
			}
		    }
		}
	    }
	}
    }

    if (($inputs{'style'} eq "groupedstackedbar") || ($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability"))
    {
	my %tmp_color_hash;
	my %key_label_hash;

	$counter = 0;
	foreach $key (@families_keys)
	{
	    $key =~ s/__SUFFIX__.*//;
	    if (! exists $tmp_color_hash{$key})
	    {
		$tmp_color_hash{$key} = $counter;
		$key_label_hash{$key} = 0;
		$counter++;
	    }
	}

	my %added_datagroups;

	for ($counter=1; $counter<$total_bar_groups+1;$counter++)
	{
	    my $axis_change = "";

	    if (! $inputs{'group'} eq "")
	    {
		$inputs{'group'} =~ m/([0-9]+):(.*)/;
		if ($1 == $counter)
		{
		    $axis_change = $2;
		}
	    }

	    for ($counter2=0; $counter2<@datasets; $counter2++)
	    {
		if ($counter == $datasets[$counter2]->{'datagroup'})
		{
		    if (! exists($added_datagroups{$counter}))
		    {
			$layers[0]->addDataGroup($counter);
			$added_datagroups{$counter} = 1;
		    }

		    my $dataset_label = "";
		    if ($key_label_hash{$datasets[$counter2]->{'label'}} == 0)
		    {
			$dataset_label = $datasets[$counter2]->{'label'};
			$key_label_hash{$datasets[$counter2]->{'label'}} = 1;
		    }

		    my $dataset = $layers[0]->addDataSet(multiply_y($datasets[$counter2]->{'y_data'}), $dataset_colors[$tmp_color_hash{$datasets[$counter2]->{'label'}}], $dataset_label);

		    if ($axis_change =~ /x1y2/)
		    {
			$dataset->setUseYAxis2();
		    }
		}
	    }
	}

	my %tmp_hash;
	my @tmp_array;

	for ($counter=0; $counter<@stackedbar_labels; $counter++)
	{
	    $stackedbar_labels[$counter] =~ s/__SUFFIX__.*//;
	    if (! exists $tmp_hash{$stackedbar_labels[$counter]})
	    {
		push @tmp_array, $stackedbar_labels[$counter];
	    }
	    $tmp_hash{$stackedbar_labels[$counter]} = 1;
	}
	@stackedbar_labels = @tmp_array;
    }
    else
    {
	$layers[0]->addDataGroup("group");

	for ($counter=0; $counter<@datasets; $counter++)
	{
	    $layers[0]->addDataSet(multiply_y($datasets[$counter]->{'y_data'}), $dataset_colors[$counter], $datasets[$counter]->{'label'});
	}
    }

    $chart->xAxis()->setLabels([ @stackedbar_labels ])->setFontAngle($inputs{'x-label-angle'});

    if ((($inputs{'style'} eq "groupedstackedbarcompare") || ($inputs{'style'} eq "scalability")) && ($inputs{'suppress-bar-labels'} == 0))
    {
	for ($counter=1; $counter<$total_bar_groups+1;$counter++)
	{
	    for ($counter2=0; $counter2<@{$groupedstackedbarcompare_labels->[$counter]}; $counter2++)
	    {
		$layers[0]->addCustomGroupLabel($counter - 1, $counter2, $groupedstackedbarcompare_labels->[$counter][$counter2], $inputs{'font'}, $inputs{'chart-label-font-size'}, $perlchartdir::TextColor, $inputs{'bar-label-angle'});
	    }
	}
    }

    if ($inputs{'style'} eq "stackedbarcompare")
    {
	my @stackedbarcompare_labels;
	my $baseline_value;
	my $baseline_index = -1;

	# this is part one of handling an auto determined baseline
	# first and last can be handled without examining an data
	if ($inputs{'baseline'} =~ /auto:/)
	{
	    if ($inputs{'baseline'} =~ /first/)
	    {
		$baseline_index = 0;
	    }
	    else
	    {
		if ($inputs{'baseline'} =~ /last/)
		{
		    $baseline_index = @stackedbar_labels - 1;
		}
	    }
	}

	# initialize the array to zero and find the baseline if not doing an auto
	for ($counter=0; $counter<@stackedbar_labels; $counter++)
	{
	    $stackedbarcompare_labels[$counter] = 0;

	    if (($baseline_index == -1) && ($stackedbar_labels[$counter] eq $inputs{'baseline'}))
	    {
		$baseline_index = $counter;
	    }
	}

	# find the cumulative sums for each bar
	for ($counter=0; $counter<@datasets;$counter++)
	{
	    for ($counter2=0; $counter2<@{$datasets[$counter]->{'y_data'}}; $counter2++)
	    {
		$stackedbarcompare_labels[$counter2] += $datasets[$counter]->{'y_data'}[$counter2];
	    }
	}

	# this is part two of handling an auto determined baseline
	# high and low must be found by scanning the cumulative sums previously calculated
	if ($inputs{'baseline'} =~ /auto:/)
	{
	    my $max;
	    my $min;

	    if ($inputs{'baseline'} =~ /high/)
	    {
		$max = $stackedbarcompare_labels[0];
		$baseline_index = 0;
		for ($counter=1; $counter<@stackedbarcompare_labels; $counter++)
		{
		    if ($stackedbarcompare_labels[$counter] > $max)
		    {
			$max = $stackedbarcompare_labels[$counter];
			$baseline_index = $counter;
		    }
		}
	    }
	    else
	    {
		if ($inputs{'baseline'} =~ /low/)
		{
		    $max = $stackedbarcompare_labels[0];
		    $baseline_index = 0;
		    for ($counter=1; $counter<@stackedbarcompare_labels; $counter++)
		    {
			if ($stackedbarcompare_labels[$counter] < $max)
			{
			    $max = $stackedbarcompare_labels[$counter];
			    $baseline_index = $counter;
			}
		    }
		}
	    }
	}

	# get the baseline value from the determined baseline index
	$baseline_value = $stackedbarcompare_labels[$baseline_index];

	for ($counter=0; $counter<@stackedbarcompare_labels; $counter++)
	{
	    if ($stackedbarcompare_labels[$counter] == $baseline_value)
	    {
		# the current value is the baseline value so mark it as 100%
		$stackedbarcompare_labels[$counter] = "100%";
	    }
	    else
	    {
		# determine the percentage difference versus the baseline value and then do a regex to format it as
		# a one decimal percent (the regex removes everything after the first number after the decimal and replaces
		# it with a % sign)
		$stackedbarcompare_labels[$counter] = $stackedbarcompare_labels[$counter] / $baseline_value * 100;
		$stackedbarcompare_labels[$counter] =~ s/(\.[0-9]).*/\1/g;
		$stackedbarcompare_labels[$counter] .= "%";
	    }

	    if ($inputs{'suppress-bar-labels'} == 0)
	    {
		$layers[0]->addCustomAggregateLabel($counter, $stackedbarcompare_labels[$counter], $inputs{'font'}, $inputs{'chart-label-font-size'}, $perlchartdir::TextColor, $inputs{'bar-label-angle'});
	    }
	}	
    }
}

if (($inputs{'style'} eq "stackedlines") || ($inputs{'style'} eq "stackedlinespoints"))
{
    $layers[0] = $chart->addAreaLayer2($perlchartdir::Stack);
    $layers[0]->setLineWidth(1);
    # setting the border to be transparent can cause issues with very high data point density
    # so instead make the border and the line the same color when adding the dataset in the loop below
    # this may need to be looked at for other graph types as well
    #$layers[0]->setBorderColor(0xFF000000);

    for ($counter=0; $counter<@datasets; $counter++)
    {
	if ($counter == 0)
	{
	    $layers[0]->setXData(multiply_x($datasets[$counter]->{'x_data'}));
	}

	$layers[0]->addDataSet(multiply_y($datasets[$counter]->{'y_data'}), -1, $datasets[$counter]->{'title'})->setDataColor($dataset_colors[$counter], $dataset_colors[$counter]);;
    }
}

if (($inputs{'style'} eq "lines") || ($inputs{'style'} eq "linespoints"))
{
    for ($counter=0; $counter<@datasets; $counter++)
    {
	if (($datasets[$counter]->{'trend'} eq "yes") && string_is_set($inputs{'x-range'}))
	{
	    $inputs{'x-range'} =~ s/\*/$perlchartdir::NoValue/g;
	    @fields = split(":", $inputs{'x-range'});

	    # prune data that doesn't fit on the graph
	    my $i=0;
	    while ($i < @{$datasets[$counter]->{'x_data'}})
	    {
		if (($datasets[$counter]->{'x_data'}[$i] < $fields[0]) ||
		    ($datasets[$counter]->{'x_data'}[$i] > $fields[1]))
		{
		    splice(@{$datasets[$counter]->{'x_data'}}, $i, 1);
		    splice(@{$datasets[$counter]->{'y_data'}}, $i, 1);
		}
		else
		{
		    $i++;
		}
	    }
	}

	my $tmp_dataset_color = $dataset_colors[$counter];

	if ($datasets[$counter]->{'trend'} eq "yes")
	{
	    # for now the color is a calculated (divide by 2) value from the dataset color that is too be used
	    # this is so it is deterministic but sufficiently different that the trend line will still be visible
	    # when the dataset has a low variance and is tightly grouped -- if the trend line is the same color
	    # as the dataset it will not be visible
	    $trend_layers[$counter] = $chart->addTrendLayer2(multiply_x($datasets[$counter]->{'x_data'}), multiply_y($datasets[$counter]->{'y_data'}), ($tmp_dataset_color / 2), "", 0);

	    my $slope = $trend_layers[$counter]->getSlope();
	    if (sprintf("%.2f", abs($slope)) eq "0.00")
	    {
		# the number is small, print in scientific notation with 2 decimal places
		$slope = sprintf("%.2e", $slope);
	    }
	    else
	    {
		# the number is moderatly sized, round off at 2 decimal places
		$slope = sprintf("%.2f", $slope);
	    }

	    $trend_layers[$counter]->getDataSet(0)->setDataName($datasets[$counter]->{'title'} . " Trend (slope = " . $slope . ")");
	    $trend_layers[$counter]->setLineWidth(2);

	    if ($datasets[$counter]->{'plot-axis'} =~ /x1y2/)
	    {
		$trend_layers[$counter]->setUseYAxis2(1);
	    }
	}

        if ($datasets[$counter]->{'plot-axis'} =~ /x1y2/)
        {
	    if ($groups == 0)
	    {
		$tmp_dataset_color = $chart->dashLineColor($tmp_dataset_color, $perlchartdir::DashLine);
	    }
        }

        if ($inputs{'smooth'} =~ /spline/)
        {
            $layers[$counter] = $chart->addSplineLayer(multiply_y($datasets[$counter]->{'y_data'}), $tmp_dataset_color, $datasets[$counter]->{'title'});
        }
        else
        {
            $layers[$counter] = $chart->addLineLayer(multiply_y($datasets[$counter]->{'y_data'}), $tmp_dataset_color, $datasets[$counter]->{'title'});
        }

        $layers[$counter]->setLineWidth(2);
        $layers[$counter]->setXData(multiply_x($datasets[$counter]->{'x_data'}));
        $layers[$counter]->setBorderColor(0xFF000000);
	if ($inputs{'style'} eq "linespoints")
	{
	    $layers[$counter]->getDataSet(0)->setDataSymbol($perlchartdir::SquareShape, 7);
	}
	if ($inputs{'style'} eq "lines")
	{
	    $layers[$counter]->getDataSet(0)->setDataSymbol($perlchartdir::SquareShape, 0);
	}

        if ($datasets[$counter]->{'plot-axis'} =~ /x1y2/)
        {
            $layers[$counter]->setUseYAxis2(1);
	}
    }
}

# if there is a vertical line then add it, the specification should be of the form X:color:label
if ($inputs{'vert-line'})
{
    for (my $i=0; $i<@{$inputs{'vert-line'}}; $i++)
    {
	@fields = split(":", $inputs{'vert-line'}[$i]);
	my $mark = $chart->xAxis->addMark($fields[0] * $inputs{'multiply-x-by'}, $colors_by_name{$fields[1]});
	$mark->setLineWidth(2);
	if ($fields[2]) {
	    $legend->addKey($fields[2], $colors_by_name{$fields[1]});
	}
    }
}


# if there is a vertical zone then add it, the specification should be of the form X1:X2:color:label
if ($inputs{'vert-zone'})
{
    for (my $i=0; $i<@{$inputs{'vert-zone'}}; $i++)
    {
	@fields = split(":", $inputs{'vert-zone'}[$i]);
	$chart->xAxis->addZone($fields[0] * $inputs{'multiply-x-by'}, $fields[1] * $inputs{'multiply-x-by'}, $colors_by_name{$fields[2]});
	if ($fields[3]) {
	    $legend->addKey($fields[3], $colors_by_name{$fields[2]});
	}
    }
}


# if there is a horizontal line then add it, the specification should be of the form Y:color:label
if ($inputs{'horz-line'})
{
    for (my $i=0; $i<@{$inputs{'horz-line'}}; $i++)
    {
	@fields = split(":", $inputs{'horz-line'}[$i]);
	my $mark = $chart->yAxis->addMark($fields[0] * $inputs{'multiply-y-by'}, $colors_by_name{$fields[1]});
	$mark->setLineWidth(2);
	if ($fields[2]) {
	    $legend->addKey($fields[2], $colors_by_name{$fields[1]});
	}
    }
}


# if there is a horizontal zone then add it, the specification should be of the form Y1:Y2:color:label
if ($inputs{'horz-zone'})
{
    for (my $i=0; $i<@{$inputs{'horz-zone'}}; $i++)
    {
	@fields = split(":", $inputs{'horz-zone'}[$i]);
	$chart->yAxis->addZone($fields[0] * $inputs{'multiply-y-by'}, $fields[1] * $inputs{'multiply-y-by'}, $colors_by_name{$fields[2]});
	if ($fields[3]) {
	    $legend->addKey($fields[3], $colors_by_name{$fields[2]});
	}
    }
}

# if there are adhoc legend entries then add them
if ($inputs{'legend-entry'})
{
    # set the legend priority high, so added entries will fall after dataset entries
    my $legend_priority = 1000000;

    for (my $i=0; $i<@{$inputs{'legend-entry'}}; $i++)
    {
	$legend->addKey2($legend_priority++, $inputs{'legend-entry'}[$i], $perlchartdir::Transparent, 1);
    }
}

# update the height of the chart to make sure it encompasses the entire legend
# must render the legend first
$chart->layoutLegend();
$graph_properties{'legend'}{'actual_height'} = $legend->getHeight();
if ($graph_properties{'legend'}{'actual_height'} > $graph_properties{'legend'}{'height'}) {
    $chart->setSize($graph_properties{'width'}, $graph_properties{'height'} + ($graph_properties{'legend'}{'actual_height'} - $graph_properties{'legend'}{'height'}));
}

#output the chart
$inputs{'outfile'} =~ s/ /_/g;
$inputs{'outfile'} =~ s|/|_|g;
if (($inputs{'image_type'} =~  /jpeg/) || ($inputs{'image_type'} =~ /jpg/))
{
    $chart->makeChart("$inputs{'outdir'}/$inputs{'outfile'}.jpg");
}
else
{
    $chart->makeChart("$inputs{'outdir'}/$inputs{'outfile'}.png");
}

# end of the actual graphing ###########################################################


# demo mode ############################################################################

use IO::File;
use POSIX qw(tmpnam);

# get a temporary file and create it
# return the filename so it can be accessed
sub get_tmp_file
{
    my $filename;
    my $fh;

    # loop until the creation of the file succeeds
    do
    {
	$filename = tmpnam();
    }
    until $fh = IO::File->new($filename, O_WRONLY | O_CREAT);

    return $filename;
}

# 'pretty print' and execute the demo command
sub process_command
{
    my $command = shift(@_);

    my $buffer = "";

    for (my $i=0; $i<@{$command}; $i++)
    {
	if (${$command}[$i] =~ /\s/)
	{
	    $buffer .= "'${$command}[$i]' ";
	}
	else
	{
	    $buffer .= "${$command}[$i] ";
	}
    }
    print "Demo command invocation: $buffer\n";

    system(@{$command});
    ${$command}[2] =~ s/ /_/g;
    print "Demo output file: ${$command}[2].png\n";
}

# display the contents of a buffer which represents one of the temporary plot files
sub print_plotfile
{
    my $file_number = shift(@_);
    my $filename = shift(@_);
    my $buffer = shift(@_);

    print "Plot File $file_number ($filename):\n";
    print "--------------------------------------------\n";
    print "$buffer";
    print "--------------------------------------------\n\n";
}

# the main demo mode control block
sub demo_mode
{
    my $style = shift(@_);
    my $debug = shift(@_);

    my $x;
    my $y;
    my $i;
    my $buffer;
    my @command;

    for ($i = 0; $i < @saved_argv; $i++) {
	if ($saved_argv[$i] =~ /demo/) {
	    splice(@saved_argv, $i, 1);
	    last;
	}
    }

    if (($style eq "lines") || ($style eq "linespoints") || ($style eq "stackedlines") || ($style eq "stackedlinespoints"))
    {
	my $num_plotfiles = 3;
	my @plotfile_names;

	for ($i=1; $i<=$num_plotfiles; $i++)
	{
	    $plotfile_names[$i-1] = get_tmp_file();

	    if (open(FH, ">$plotfile_names[$i-1]"))
	    {
		$buffer = "#LABEL:data series $i\n";

		for ($x=1; $x<100; $x+=10)
		{
		    # random function that generates an 'interesting' data series
		    $y = (cos($x + $x/($x + 5)) / $i) + 1;

		    $buffer .= sprintf("%d %.2f\n", $x, $y);
		}

		print FH "$buffer";
		close FH;

		print_plotfile($i, $plotfile_names[$i-1], $buffer);
	    }
	    else
	    {
		print STDERR "ERROR: Failed to open temporary file '" . $plotfile_names[$i-1] . "' for writing.\n";
	    }
	}

	# construct an array with the arguments and options to generate the demo chart
	push @command, "$ENV{'_'}";
	push @command, "-t";
	# array element 2 should be the title so the process_command function can print it
	push @command, "chart.pl demo -- $style";
	push @command, @saved_argv;
	push @command, "-s";
	push @command, "$style";
	push @command, "-x";
	push @command, "X-Axis Label";
	push @command, "-y";
	push @command, "Y-Axis Label";
	# pass through debug args if specified
	push @command, "--debug" if $debug;
	push @command, "$debug" if $debug;
	push @command, @plotfile_names;

	process_command(\@command);

	# delete the temporary plot files
	for ($i=0; $i<$num_plotfiles; $i++)
	{
	    unlink($plotfile_names[$i]);
	}
    }
    elsif (($style eq "bar") || ($style eq "barcompare") || ($style eq "compare"))
    {
	my $num_plotfiles = 5;
	my @plotfile_names;

	for ($i=1; $i<=$num_plotfiles; $i++)
	{
	    $plotfile_names[$i-1] = get_tmp_file();

	    if (open(FH, ">$plotfile_names[$i-1]"))
	    {
		$buffer = "#LABEL:data series $i\n";

		# random function that generates an 'interesting' data series
		$y = 5 - sin($i^2 / ($i + (1 / $i)));

		$buffer .= sprintf("%.2f\n", $y);

		print FH "$buffer";
		close FH;

		print_plotfile($i, $plotfile_names[$i-1], $buffer);
	    }
	    else
	    {
		print STDERR "ERROR: Failed to open temporary file '" . $plotfile_names[$i-1] . "' for writing.\n";
	    }
	}

	# construct an array with the arguments and options to generate the demo chart
	push @command, "$ENV{'_'}";
	push @command, "-t";
	# array element 2 should be the title so the process_command function can print it
	push @command, "chart.pl demo -- $style";
	push @command, @saved_argv;
	push @command, "-s";
	push @command, "$style";
	push @command, "-x";
	push @command, "X-Axis Label";
	push @command, "-y";
	push @command, "Y-Axis Label";
	# pass through debug args if specified
	push @command, "--debug" if $debug;
	push @command, "$debug" if $debug;

	if (($style eq "compare") || ($style eq "barcompare"))
	{
	    push @command, "--baseline";
	}

	push @command, @plotfile_names;

	process_command(\@command);

	# delete the temporary plot files
	for ($i=0; $i<$num_plotfiles; $i++)
	{
	    unlink($plotfile_names[$i]);
	}
    }
    elsif (($style eq "stackedbar") || ($style eq "stackedbarcompare"))
    {
	my $num_plotfiles = 5;
	my @plotfile_names;
	my $num_elements = 5;

	for ($i=1; $i<=$num_plotfiles; $i++)
	{
	    $plotfile_names[$i-1] = get_tmp_file();

	    if (open(FH, ">$plotfile_names[$i-1]"))
	    {
		$buffer = "#LABEL:bar $i\n";

		for ($x=1; $x<=$num_elements; $x++)
		{
		    # random function that generates an 'interesting' data series
		    $y = abs(($i * $x) / sin($i * $x));

		    $buffer .= sprintf("element %d,%.2f\n", $x, $y);
		}

		print FH "$buffer";
		close FH;

		print_plotfile($i, $plotfile_names[$i-1], $buffer);
	    }
	    else
	    {
		print STDERR "ERROR: Failed to open temporary file '" . $plotfile_names[$i-1] . "' for writing.\n";
	    }
	}

	# construct an array with the arguments and options to generate the demo chart
	push @command, "$ENV{'_'}";
	push @command, "-t";
	# array element 2 should be the title so the process_command function can print it
	push @command, "chart.pl demo -- $style";
	push @command, @saved_argv;
	push @command, "-s";
	push @command, "$style";
	push @command, "-x";
	push @command, "X-Axis Label";
	push @command, "-y";
	push @command, "Y-Axis Label";
	# pass through debug args if specified
	push @command, "--debug" if $debug;
	push @command, "$debug" if $debug;

	if ($style eq "stackedbarcompare")
	{
	    push @command, "--baseline";
	    push @command, "auto:first";
	}

	push @command, @plotfile_names;

	process_command(\@command);

	# delete the temporary plot files
	for ($i=0; $i<$num_plotfiles; $i++)
	{
	    unlink($plotfile_names[$i]);
	}
    }
    elsif ($style eq "groupedbar")
    {
	my $num_plotfiles = 5;
	my @plotfile_names;
	my $num_elements = 5;

	for ($i=1; $i<=$num_plotfiles; $i++)
	{
	    $plotfile_names[$i-1] = get_tmp_file();

	    if (open(FH, ">$plotfile_names[$i-1]"))
	    {
		$buffer = "#LABEL:dataset $i\n";

		for ($x=1; $x<=$num_elements; $x++)
		{
		    # random function that generates an 'interesting' data series
		    $y = abs(sin($x)) / abs(cos($i));

		    if ((($i == 2) && ($x == 2)) || (($i == 4) && ($x == 4)))
		    {
			# skip data point to create a 'hole'
		    }
		    else
		    {
			$buffer .= sprintf("%d %.2f\n", $x, $y);
		    }
		}

		print FH "$buffer";
		close FH;

		print_plotfile($i, $plotfile_names[$i-1], $buffer);
	    }
	    else
	    {
		print STDERR "ERROR: Failed to open temporary file '" . $plotfile_names[$i-1] . "' for writing.\n";
	    }
	}

	# construct an array with the arguments and options to generate the demo chart
	push @command, "$ENV{'_'}";
	push @command, "-t";
	# array element 2 should be the title so the process_command function can print it
	push @command, "chart.pl demo -- $style";
	push @command, @saved_argv;
	push @command, "-s";
	push @command, "$style";
	push @command, "-x";
	push @command, "X-Axis Label";
	push @command, "-y";
	push @command, "Y-Axis Label";
	# pass through debug args if specified
	push @command, "--debug" if $debug;
	push @command, "$debug" if $debug;
	push @command, @plotfile_names;

	process_command(\@command);

	# delete the temporary plot files
	for ($i=0; $i<$num_plotfiles; $i++)
	{
	    unlink($plotfile_names[$i]);
	}
    }
    elsif (($style eq "groupedstackedbar") || ($style eq "groupedstackedbarcompare"))
    {
	my $num_plotfiles = 6;
	my @plotfile_names;
	my $num_elements = 5;

	for ($i=1; $i<=$num_plotfiles; $i++)
	{
	    $plotfile_names[$i-1] = get_tmp_file();

	    if (open(FH, ">$plotfile_names[$i-1]"))
	    {
		# in groupedstackedbarcompare each time a #LABEL is encountered it becomes a member of a new group
		if ($i > ($num_plotfiles / 2))
		{
		    $buffer = "#LABEL:dataset " . ($i - ($num_plotfiles / 2)) . "\n";
		}
		else
		{
		    $buffer = "#LABEL:dataset $i\n";
		}

		for ($x=1; $x<=$num_elements; $x++)
		{
		    # random function that generates an 'interesting' data series
		    $y = abs(sin($x)) / abs(cos($i));

		    if ((($i == 2) && ($x == 2)) || (($i == 4) && ($x == 4)))
		    {
			# skip data point to create a 'hole'
		    }
		    else
		    {
			$buffer .= sprintf("%d,%.2f\n", $x, $y);
		    }
		}

		print FH "$buffer";
		close FH;

		print_plotfile($i, $plotfile_names[$i-1], $buffer);
	    }
	    else
	    {
		print STDERR "ERROR: Failed to open temporary file '" . $plotfile_names[$i-1] . "' for writing.\n";
	    }
	}

	# construct an array with the arguments and options to generate the demo chart
	push @command, "$ENV{'_'}";
	push @command, "-t";
	# array element 2 should be the title so the process_command function can print it
	push @command, "chart.pl demo -- $style";
	push @command, @saved_argv;
	push @command, "-s";
	push @command, "$style";
	push @command, "-x";
	push @command, "X-Axis Label";
	push @command, "-y";
	push @command, "Y-Axis Label";

	if ($style eq "groupedstackedbarcompare")
	{
	    push @command, "--baseline";
	    push @command, "auto:first";
	}

	# pass through debug args if specified
	push @command, "--debug" if $debug;
	push @command, "$debug" if $debug;
	push @command, @plotfile_names;

	process_command(\@command);

	# delete the temporary plot files
	for ($i=0; $i<$num_plotfiles; $i++)
	{
	    unlink($plotfile_names[$i]);
	}
    }
    elsif ($style eq "scalability")
    {
	my $num_plotfiles = 10;
	my @plotfile_names;

	my $config = 1;

	for ($i=1; $i<=$num_plotfiles; $i++)
	{
	    $plotfile_names[$i-1] = get_tmp_file();

	    if (open(FH, ">$plotfile_names[$i-1]"))
	    {
		if (($i == 1) || ($i == ($num_plotfiles / 2 + 1)))
		{
		    $x = 1;
		}

		$buffer = "#LABEL:dataset $x\n";


		if ($i > ($num_plotfiles / 2))
		{
		    $config = 2;

		    # random function that generates an 'interesting' data series
		    $y = ($x * $x) + (2 * $x) - .5;
		}
		else
		{
		    # random function that generates an 'interesting' data series
		    $y = ($x * $x) - (2 * ($x - 1));
		}

		$buffer .= sprintf("config %d,%.2f\n", $config, $y);

		print FH "$buffer";
		close FH;

		print_plotfile($i, $plotfile_names[$i-1], $buffer);

		$x++;
	    }
	    else
	    {
		print STDERR "ERROR: Failed to open temporary file '" . $plotfile_names[$i-1] . "' for writing.\n";
	    }
	}

	# construct an array with the arguments and options to generate the demo chart
	push @command, "$ENV{'_'}";
	push @command, "-t";
	# array element 2 should be the title so the process_command function can print it
	push @command, "chart.pl demo -- $style";
	push @command, @saved_argv;
	push @command, "-s";
	push @command, "$style";
	push @command, "-x";
	push @command, "X-Axis Label";
	push @command, "-y";
	push @command, "Y-Axis Label";
	push @command, "--baseline";
	push @command, "auto:first";
	# pass through debug args if specified
	push @command, "--debug" if $debug;
	push @command, "$debug" if $debug;
	push @command, @plotfile_names;

	process_command(\@command);

	# delete the temporary plot files
	for ($i=0; $i<$num_plotfiles; $i++)
	{
	    unlink($plotfile_names[$i]);
	}
    }
    else
    {
	print STDERR "ERROR: Style '$style' not yet supported by demo mode.\n";
    }

    exit;
}

# end of demo mode ######################################################################


# pod usage stuff #######################################################################

=head1 NAME

chart.pl

=head1 SYNOPSIS

chart.pl [OPTIONS...] [PLOTFILES...]

=head1 DESCRIPTION

chart.pl reads data from plotfiles of various formats and generates
several different styles of charts.  Use the demo mode to get a sample
of the various supported styles.

=head1 OPTIONS

=over 8

=item B< -t, --title=TEXT>

Set the chart title and output filename (spaces are converted to
underscores -- we do not like spaces in filenames).  This option is
required.

=item B<-s, --style=TEXT>

Set the style of the graph. Possible values are:

lines linespoints(default) stackedlines stackedlinespoints compare bar
barcompare stackedbar groupedbar stackedbarcompare groupedstackedbar
groupedstackedbarcompare scalability

=item B<--graphtype=A:B>

Set the graphtype in the form C<A:B>.  This is a weird option.  A+B
should equal the number of datasets that should be grouped together
when doing multi Y axis graphs.  The number of datasets to group
together represent the number of consecutive plotfiles on the command
line that should have the same color but different line styles (solid,
dashed, etc.).  See B<--plot-axis> for additional details.

=item B<-x, --x-label=TEXT>

Set the label on the X axis.

=item B<-y, --y-label=TEXT>

Set the label on the Y axis.

=item B<--y2-label=TEXT>

Set the label on the second Y axis.

=item B<--x-range=LOW:HIGH>

Set the range of the X axis in the form C<LOW:HIGH>.  A C<*> can be used
to allow the program to determine that value itself.

=item B<--y-range=LOW:HIGH>

Set the range of the Y axis in the form C<LOW:HIGH>.  See B<--x-range>
for details.

=item B<--y2-range=TEXT>

Set the range of the second Y axis.  See B<--x-range> for details.

=item B<--x-scale=TEXT>

Set the X axis scale.  May be C<linear> (default) or C<log>.

=item B<--y-scale=TEXT>

Set the Y axis scale.  See B<--x-range> for details.

=item B<--y2-scale=TEXT>

Set the second Y axis scale.  See B<--x-scale> for details.

=item B<--x-label-angle=INTEGER>

Set the angle of the text for the labels on the X axis.  Default is 0.

=item B<--x-tics=INTEGER>

Set the major tick for log scale on the X axis.

=item B<--y-tics=INTEGER>

Set the major tick for log-scale on the Y axis.

=item B<--multiply-y-by=FLOAT>

Multiply (scale) the y-axis values by the specified amount.  This can
be used to change the units of measurement for the y-axis values.

=item B<--multiply-x-by=FLOAT>

Multiply (scale) the x-axis values by the specified amount.  This can
be used to change the units of measurement for the x-axis values.

=item B<--baseline=TEXT>

Specify the plotfile to use as the baseline for comparative chart
styles.  For stackedbarcompare the input is either C<auto:first> or
C<auto:last>.

=item B<--group=TEXT>

Specify an axis for a group in C<groupedstackedbar> or
C<groupedstackedbarcompare>.  This takes a value such as
C<GROUP_NUMBER:AXIS>.  The GROUP_NUMBER can be determined for a dataset
by running with debug mode equal to 3.  The axis is either C<x1y1> or
C<x1y2>.

=item B<--plot-axis=TEXT>

This is another weird option.  Use this option with individual
plotfiles to specify which Y axis that plot file should be charted on.
As an example:

C<chart.pl E<lt>other optionsE<gt> --plot-axis=x1y1 foo.plot --plot-axis=x1y2 bar.plot --plot-axis=x1y1 zorg.plot>

Once the plot axis has been changed with B<--plot-axis> the value
specified will be used for all future plot files until another
B<--plot-axis> option is used.  This option is most often used with a
line graph and the B<--graphtype> option in order to alternate related
plot files from one axis to the next (throughput for config a on x1y1,
cpu for config a on x1y2, etc.).  As an example:

C<chart.pl E<lt>other optionsE<gt> --graphtype=1:1 --plot-axis=x1y1 config-a.throughput.plot --plot-axis=x1y2 config-a.cpu.plot --plot-axis config-b.throughput.plot --plot-axis=x1y2 config-b.cpu.plot>

See B<--graphtype> for more details.

=item B<--trend=E<lt>yes|noE<gt>>

Specify that a trend line should be plotted for a line or linespoints
graph.  The trend line that is plotted is the result of the entire
data series.  If there are sections of the data series that you want
ignored use the B<--x-range> option to trim them off.

This parameter works much like B<--plot-axis> in that once it has been
activated it must be deactivated otherwise all subsequent data series
will have a trend line plotted for them.  As an example:

C<chart.pl E<lt>other optionsE<gt> --trend=yes foo.plot --trend=no bar.plot --trend=yes zorg.plot>

The slope of the trend line (the modification of the Y axis per X axis
increment) will be included in the legend.

=item B<--demo>

Use this option along with B<-s,--style> to generate a sample chart
and the input used to generate that chart.  Useful for learning about
the chart styles or for regression testing the program.

=item B<--omit-empty-plotfiles>

Set this option to omit plotfiles that either have no plot data or all
plot files are the same (some processing applications that write
plotfiles simply write zeros when data is not found).  This avoids
useless legen entries and data series that skew the scale of an axis.

=item B<--suppress-bar-labels>

Set this option to suppress labels at the tops of bars.  This is
useful for large datasets where the labels become unreadable because
the bars are so close together.  See also
B<--bar-label-angle>.

=item B<--bar-label-angle=INTEGER>

Set this option to modify the angle at which labels on top of bars are
oriented.  This is useful for large datasets where the labels become
unreadable because the bars are so close together.  See also
B<--suppress-bar-labels>.

=item B<--x-pixels=TEXT>

Set the number of X pixels to use.  This can be used to increase the
width of the generated image and is useful for extremely large
datasets.

=item B<-q, --quiet>

Activate quite mode.  This will disable informational messages and is
useful when running from batch processing where the textual output of
this program is not important.

=item B<--vert-zone=TEXT>

Set a vertical zone in the form C<X1:X2:COLOR[:LABEL]>.  This will
create a box shaded with COLOR from X1 to X2 that has a label of LABEL
in the legend.  This option can be used multiple times to specify
multiple zones.  The LABEL is optional.

=item B<--vert-line=TEXT>

Set a vertical line in the form C<X:COLOR[:LABEL]>.  This will create a
line at X that is colored COLOR and has a label of LABEL in the
legend.  This option can be used multiple times to specify multiple
lines.  The LABEL is optional.

=item B<--horz-zone=TEXT>

Set a horizontal zone of the form C<Y1:Y2:COLOR[:LABEL]>.  See
B<--vert-zone> for details.

=item B<--horz-line=TEXT>

Set a vertical line in the form C<Y:COLOR[:LABEL]>.  See B<--vert-line>
for details.

=item B<--legend-entry=TEXT>

Add an entry to the legend.  This is useful for adding textual notes
to the chart.  This option can be used multiple times to specify
multiple entries.

=item B<-o, --outdir=TEXT>

Set the directory where the chart file will be output.

=item B<-O, --outfile=TEXT>

Set the name of the chart file (without filename extension). The default is
the title of the chart (given by the B<--title> option).

=item B<-i, --image=TEXT>

Set the image output type (jpeg, jpg, or png (default)).

=item B<--table=TEXT>

Create an additional output file in the form of a text file in one of
four user specified formats (txt, csv, tapwiki, or html).  The default
is to not produce this file.  Multiple tables can be produced by
separating the types by a colon, such as B<--table=txt:csv:tapwiki:html>.

=item B<-m, --smooth=TEXT>

Enable smoothing.  Can be none (default) or spline.

=item B<-f, --font=TEXT>

Set the font.  Changing this option could potentially cause the chart
to render improperly.

=item B<--font-size=INT>

Set the font size.  Default is 8.

=item B<--legend-font-size=INT>

Set the font size of the legend text.  Default is the same as
B<--font-size>.

=item B<--title-font-size=INT>

Set the font size of the title.  Default is B<--font-size> + 2.

=item B<--axis-font-size=INT>

Set the font size of the axis tick labels.  Default is B<--font-size>.

=item B<--axis-label-font-size=INT>

Set the font size of the axis labels.  Default is B<--font-size> + 1.

=item B<--chart-label-font-size=INT>

Set the font size of the labels placed on the chart itself.  Default
is B<--font-size>.

=item B<--no-stackedline-zero-insertion>

If this option is specified, stacked line datasets will not have a
zero y-axis values inserted if they are missing an x-axis datapoint
that is present in one of the other datasets.  By default, the values
are inserted to prevent datapoints from assuming to exist.  However,
there are situations where the user may desire this behavior.

=item B<-d, --debug=INT>

Turn on debug mode.  This option takes several values which output
different data from the program during execution.

 1 = Print the options hash.
 2 = Print the inputs hash (inputs are the options after being processed).
 3 = Print the datasets hash.
 4 = Print the colors by name hash.
 5 = Print the dataset colors hash.

=item B<-h, --help>

Print options and exit.

=item B<--man>

Print the complete man page and exit.

=back

=head1 AUTHOR

Karl Rister E<lt>kmr@us.ibm.comE<gt>

=head1 CREDITS

chart.pl is built upon the excellent (but non-free) ChartDirector
library from Advanced Software Engineering
(http://www.advosofteng.com).

=head1 BUGS

The C<groupedstackedbar> style is currently broken.

=head1 TODO

1.  Fix bugs

2.  Add missing styles to table output

=cut
