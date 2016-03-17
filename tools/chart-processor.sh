#!/bin/bash

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/chart-processor.sh
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# This script can be used to scan a result tree and process all of the chart.sh scripts that it finds.
# These scripts are generated mostly (it not always) by profiler post processors.
# An output file (default is summary.html) will be generated that will have a link to the resulting chart.html that
# each chart.sh will generate.  The output file file can be viewed in a browser to quickly navigate all of
# the charts that are produced from a given run.
# There are potentially 8 arguments that can be changed/set with key=value pairs.  The location of the chart.pl
# graphing script and the ChartDirector libraries account for two of these, these variables are defaulted to the
# hks.austin.ibm.com locations of these scripts but can be overridden.  Second, an adhoc script can be specified
# and its output will be prepended to the output file.  This is useful if the user has their own post processing
# utility for the result directory.  Adhoc is specified like:
#
# adhoc=/path/to/script
# or
# adhoc="/path/to/script arg1 arg2 ... argN"
#
# In the second example the arguments are optional, but quotes must be used if arguments are expected for the adhoc script.
# If the adhoc script is not found, it will look in the "built-in" addons directory for the specified adhoc script. The
# default location for this addons directory is the "chart-processor-addons" subdirectory of the directory where this
# script is located. Check that directory for a list of currently available "built-in" adhoc scripts. The location of
# the addons directory can be overridden with the "addon_dir" option.
#
# The jobs parameter can be used to control how many chart.sh scripts to run in parallel. By default, all chart.sh
# scripts will be launched simultaneously.
#
# The tags parameter can be used to group the listing of the chart.html files in the summary page. The tags parameter
# should be a space-seperated list of strings. Filenames that don't match any of the tags will be grouped at the top
# of the summary page. Next, each tag will appear as a heading in the summary page, with all files that match that tag
# grouped together under that heading. If no tags are specified, the summary page simply lists all chart.html files
# in alphabetical order.
#
# The link_files parameter can be used to add additional files beyond chart.html that will be included in the resulting
# summary.html.  This is useful if your jobs have other files that you would like quick access to from the summary.html
# page.  An example might be:
#
# link_files="summary.xml run.xml"
#
# The final parameter is skip, setting this variable to anything other than an empty string will cause the chart.sh scripts
# to not be run, this is useful if the adhoc script is being refined and the chart.sh scripts being run again would be
# redundant.

script_dir=`dirname $0`

# process arguments
for arg ; do export "${arg}" ; done

# script arguments with default values
chart=${chart:-"/hks/postprocessing/chart.pl"}
chart_lib=${chart_lib:-"/hks/postprocessing/chart-lib"}
adhoc=${adhoc:-""}
skip=${skip:-""}
addon_dir=${addon_dir:-"$script_dir/chart-processor-addons"}
out_file=${out_file:-"summary.html"}
target_dir=${target_dir:-"."}
tags=${tags:-""}
link_files=${link_files:-""}

pushd $target_dir >/dev/null
if [ $? -ne 0 ]; then
    echo "$target_dir is not a valid directory"
    exit 1
fi

# execute the chart.sh scripts if skip is not specified
if [ -z "$skip" ]; then

    # Determine how many chart.sh scripts to run in parallel. Default is
    # equal to the number of processors. If the user specifies "all" as
    # the jobs value, set it to the number of chart.sh scripts.
    jobs=${jobs:-$(grep ^processor /proc/cpuinfo | wc -l)}

    # call the multi-threaded perl script that processes the chart.sh scripts
    $script_dir/chart-processor.pl --threads=$jobs --dir=`pwd` --chart=$chart --chart-lib=$chart_lib
fi

# output header
echo -e "<html>\n<head>\n<title>Summary</title>\n</head>\n<body>\n<pre>\n" > $out_file

# execute the adhoc scripts if specified
#  awk allows the use of parameters (as long as they aren't comma separated) for the adhoc script(s)
if [ ! -z "$adhoc" ]; then
    echo "$adhoc" | awk -F, '{for (i=1; i<=NF; i++) print $i}' | while read pgm pgm_args; do
        if [ ! -x "$pgm" ]; then
	    pgm="$addon_dir/$pgm"
	    if [ ! -x "$pgm" ]; then
		echo "adhoc script [$pgm] not found or not executable"
		exit 1
	    fi
        fi
	echo -n "executing adhoc $pgm"
	stderr_file="/tmp/$$.tmp"
	output=`/usr/bin/time -f "%e seconds" --output=/dev/stdout sh -c "nice -n 15 $pgm $pgm_args chart=$chart chart_lib=$chart_lib >> $out_file" 2> $stderr_file`
	echo " [$output]"
	if [ -s $stderr_file ]; then
	    echo "STDERR output from $pgm:"
	    cat $stderr_file
	    echo
	fi
	rm $stderr_file 2> /dev/null
    done
fi

# Create list of chart files.

chart_files=`find . -name chart.html | sort`
summary_files=`find . -name summary.html | grep -v "\./summary.html" | sort`

if [ -n "$link_files" ]; then
    link_find_params=""
    for link in $link_files; do
	if [ -z "$link_find_params" ]; then
	    link_find_params="-name $link"
	else
	    link_find_params="$link_find_params -o -name $link"
	fi
    done
    link_files=`find . $link_find_params | sort`

    non_tagged="$chart_files $link_files"
else
    non_tagged="$chart_files"
fi

non_tagged_summaries="$summary_files"
for tag in $tags; do
    non_tagged=`echo -e "$non_tagged" | grep -v $tag`
    non_tagged_summaries=`echo -e "$non_tagged_summaries" | grep -v $tag`
done

counter=1
for i in $non_tagged_summaries; do
    echo -e "$counter : <a href='$i'>$i</a>\n" >> $out_file
    (( counter += 1 ))
done

for i in $non_tagged; do
    echo -e "$counter : <a href='$i'>$i</a>\n" >> $out_file
    (( counter += 1 ))
done

for tag in $tags; do
    l_files=`echo -e "$link_files" | grep $tag`
    s_files=`echo -e "$summary_files" | grep $tag`
    files=`echo -e "$chart_files" | grep $tag`
    if [ -n "$l_files" -o -n "$s_files" -o -n "$files" ]; then
	echo "$tag:" >> $out_file

	for i in $l_files; do
	    echo -e "$counter : <a href='$i'>$i</a>\n" >> $out_file
	    (( counter += 1 ))
	done

	for i in $s_files; do
	    echo -e "$counter : <a href='$i'>$i</a>\n" >> $out_file
   	    (( counter += 1 ))
	done

	for i in $files; do
	    echo -e "$counter : <a href='$i'>$i</a>\n" >> $out_file
	    (( counter += 1 ))
	done
    fi
done

# output footer
echo -e "</pre>\n</body>\n</html>\n" >> $out_file

popd >/dev/null
