#!/usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/output-timestamp.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


use strict;
use warnings;

my @var;

# disable output buffering
$|++;

while (<stdin>) {
    @var = localtime(time);
    printf("[%04d-%02d-%02d %02d:%02d:%02d]: %s", $var[5]+1900, $var[4]+1, $var[3], $var[2], $var[1], $var[0], $_);
}
