
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/time.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module with time functions

package autobench::time;

use strict;
use warnings;
use POSIX qw(floor);
use Time::Local;

BEGIN {
    use Exporter();
    our (@ISA, @EXPORT);
    @ISA = "Exporter";
    @EXPORT = qw( &get_current_time
		  &time_delta
		  &timestamp_format
		  &time_in_seconds );
}

# get_current_time
#
# Returns: A string with human readable current time,
#          in the format: YYYY-MM-DD HH:MM:SS
sub get_current_time()
{
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time());
    return sprintf("%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

# timestamp_format
#
# Arg1: Time in seconds since UNIX epoch.
#
# Returns: A timestamp string in the format used in the Autobench
#          console log: YYYYMMDD-HH:MM:SS
sub timestamp_format($)
{
	my $time = shift;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
	return sprintf("%04d%02d%02d-%02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

# time_delta
#
# Arg1: Time in seconds
# Arg2: Time in seconds
#
# Returns: The difference between the two time stamps formatted
#          The order of the arguments is not important
sub time_delta($ $)
{
    my $time1 = shift;
    my $time2 = shift;
    my $delta = abs($time1 - $time2);
    my $output = "";

    if ($delta >= (60*60*24)) {
	my $foo = floor($delta / (60*60*24));
	$output = sprintf("%d day(s)", $foo);
	$delta -= $foo*60*60*24;
    }

    if ($delta >= (60*60)) {
	my $foo = floor($delta / (60*60));
	if (length($output)) {
	    $output .= ", ";
	}
	$output .= sprintf("%d hour(s)", $foo);
	$delta -= $foo*60*60;
    }

    if ($delta >= 60) {
	my $foo = floor($delta / 60);
	if (length($output)) {
	    $output .= ", ";
	}
	$output .= sprintf("%d minute(s)", $foo);
	$delta -= $foo*60;
    }

    if ($delta) {
	if (length($output)) {
	    $output .= ", ";
	}
	$output .= sprintf("%d second(s)", $delta);
    }

    return $output;
}

# get_ymd is a service function for time_in_seconds() below to reduce code
# duplication.  It is given three numbers that represent a date.  It determines
# if the number represents a year-month-day format or a month/day/year format.
# It returns an array of (year, month, day).

sub get_ymd($ $ $) {
    my $day;
    my $month;
    my $year;

    # If the first number is greater than 12 then we know it's a year and the
    # date format is yyyy-mm-dd.
    if ($1 > 12) {
	$year  = $1;
	$month = $2;
	$day   = $3;

    # There are two cases handled here.
    # 1) If the third number is greater than 12 then we know it's a year and the
    # date format is mm-dd-yyyy.
    # 2) If the third number is <= 12 then we can't definitively determine the
    # date format.  In that case we assume the date format is mm-dd-yy, the
    # standard U.S. format.  Very rarely will there be a date format that has
    # the first number as a two digit year, e.g., 12-06-17.
    # There is no need to convert a two digit year to a four digit year.  The
    # timelocal() function handles two digit years.  (Years 63-99 are 1900s,
    # years 00-62 are 2000s.  (Years 63-69 return a negative value for the epoch
    # seconds.))
    } else {
	$month = $1;
	$day   = $2;
	$year  = $3;
    }

    return ($year, $month, $day);
}

# time_in_seconds
#
# Arg1: Time in a variety of formats for [year, month, day][[hour, minutes, seconds][.nanoseconds][am|pm]]
#
# Returns: The time in seconds from the epoch if year, month, and day are given.
#          The time in seconds from the start of the day if year, month, and day are not given.
#
# Little to no effort is spent validating the date/time string.
# You are passing a valid timestamp, right?

sub time_in_seconds($)
{
    my $time = shift;
    #print "$time\n";

    my $year;
    my $month;
    my $day;
    my $hour;
    my $min;
    my $sec;
    my $ampm;

    my %months = ( 'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4,
		   'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8,
		   'September' => 9, 'October' => 10, 'November' => 11,
		   'December' => 12 );

    # hh:mm:ss
    if ($time =~ m/^([0-9]+):([0-9]+):([0-9]+)\Z/) {
	$hour = $1;
	$min  = $2;
	$sec  = $3;
	#print "$hour:$min:$sec\n";
	return ($hour * 60 + $min) * 60 + $sec;

    # hh:mm:ss(am|pm)
    } elsif ($time =~ m/^([0-9]+):([0-9]+):([0-9]+) *([AaPp][Mm])\Z/) {
	$hour = $1;
	$min  = $2;
	$sec  = $3;
	$ampm = $4;
	$ampm =~ tr/A-Z/a-z/;
	if (($ampm eq "pm") && ($hour != 12)) {
	    $hour += 12;
	} elsif (($ampm eq "am") && ($hour == 12)) {
	    $hour = 0;
	}
	#print "$hour:$min:$sec\n";
	return ($hour * 60 + $min) * 60 + $sec;

    # hh:mm:ss.nnnn
    # Ignore nanoseconds.
    } elsif ($time =~ m/^([0-9]+)[:.-]([0-9]+)[:.-]([0-9]+)\.[0-9]+\Z/) {
	$hour = $1;
	$min  = $2;
	$sec  = $3;
	#print "$hour:$min:$sec\n";
	return ($hour * 60 + $min) * 60 + $sec;

    # yyyy-mm-dd, or is it mm/dd/yyyy?
    } elsif ($time =~ m/^([0-9]+)[\/._-]([0-9]+)[\/._-]([0-9]+)\Z/) {
	($year, $month, $day) = get_ymd($1, $2, $3);
	#print "$year-$month-$day\n";

	# Return the GMT epoch time for midnight on this day.
	return timelocal(0, 0, 0, $day, $month - 1, $year);

    # yyyymmdd hh:mm:ss (console log timestamp)
    } elsif ($time =~ m/^([0-9]+)[ ._-]([0-9]+)[:.-]([0-9]+)[:.-]([0-9]+)\Z/) {
	my $date = $1;
	$year  = substr($date, 0, 4);
	$month = substr($date, 4, 2);
	$day   = substr($date, 6, 2);
	$hour  = $2;
	$min   = $3;
	$sec   = $4;
	#print "$year-$month-$day $hour:$min:$sec\n";
	return timelocal($sec, $min, $hour, $day, $month - 1, $year);

    # yyyy-mm-dd (or is it mm/dd/yyyy?) hh:mm:ss
    } elsif ($time =~ m/^([0-9]+)[ \/._-]([0-9]+)[ \/._-]([0-9]+)[ ._-]([0-9]+)[:._-]([0-9]+)[:._-]([0-9]+)\Z/) {
	($year, $month, $day) = get_ymd($1, $2, $3);
	$hour  = $4;
	$min   = $5;
	$sec   = $6;
	#print "$year-$month-$day $hour:$min:$sec\n";
	return timelocal($sec, $min, $hour, $day, $month - 1, $year);

    # yyyy-mm-dd (or is it mm/dd/yyyy?) hh:mm:ss.nnnn
    # Ignore nanoseconds.
    } elsif ($time =~ m/^([0-9]+)[ \/._-]([0-9]+)[ \/._-]([0-9]+)[ ._-]([0-9]+)[:._-]([0-9]+)[:._-]([0-9]+)\.[0-9]+\Z/) {
	($year, $month, $day) = get_ymd($1, $2, $3);
	$hour  = $4;
	$min   = $5;
	$sec   = $6;
	#print "$year-$month-$day $hour:$min:$sec\n";
	return timelocal($sec, $min, $hour, $day, $month - 1, $year);


    # yyyy-mm-dd (or is it mm/dd/yyyy?) hh:mm:ss (am|pm)
    } elsif ($time =~ m/^([0-9]+)[ \/._-]([0-9]+)[ \/._-]([0-9]+)[ ._-]([0-9]+):([0-9]+):([0-9]+) *([AaPp][Mm])\Z/) {
	($year, $month, $day) = get_ymd($1, $2, $3);
	$hour  = $4;
	$min   = $5;
	$sec   = $6;
	$ampm  = $7;
	$ampm  =~ tr/A-Z/a-z/;
	if (($ampm eq "pm") && ($hour != 12)) {
	    $hour += 12;
	} elsif (($ampm eq "am") && ($hour == 12)) {
	    $hour = 0;
	}
	#print "$year-$month-$day $hour:$min:$sec $ampm\n";
	return timelocal($sec, $min, $hour, $day, $month - 1, $year);

    # ex. Thu Mar 31 16:39:40 CDT 2011
    # Weekday Month dd hh:mm:ss Timezone yyyy
    } elsif ($time =~ m/^([A-Za-z]+) +([A-Za-z]+) +([0-9]+) +([0-9]+):([0-9]+):([0-9]+) +([A-Z]+) +([0-9]+)$/) {
	$month = $2;
	$day = $3;
	$hour = $4;
	$min = $5;
	$sec = $6;
	$year = $8;

	foreach my $key (keys (%months)) {
	    if ($key =~ /$month/i) {
		$month = $months{$key};
	    }
	}

	#print "$year-$month-$day $hour:$min:$sec\n";
	return timelocal($sec, $min, $hour, $day, $month - 1, $year);
    }

    print STDERR "time_in_seconds(): Unrecognized time format \"$time\".\n";
    return -1;
}

END { }

1;
