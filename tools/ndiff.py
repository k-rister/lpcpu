#!/usr/bin/python

#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/ndiff.py
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


# This script compares the numbers present at identical locations in two
# given files, and produces a file which contains the same contents as the
# original file(s), except with the numbers replaced by the difference of
# the numbers in the original files.  It attempts to preserve whitespace
# in a way such that vertical alignment is preserved.
#
# Arguments:  <before-file> <after-file>

import sys;
import re;

whitespace = re.compile('\s*')
blackspace = re.compile('\S*')
number = re.compile('^\d*$')

B=sys.argv[1]
A=sys.argv[2]
fileB = open(B,'r') # after
fileA = open(A,'r') # before

for lineB in fileB:
	lineA = fileA.readline()

	segmentwhiteBend = 0
	segmentblackBend = 0
	segmentwhiteAend = 0
	segmentblackAend = 0
	whiteB = ''
	blackB = ''
	whiteA = ''
	blackA = ''

	while (segmentblackAend != len(lineA)):
		segmentwhiteB = whitespace.search(lineB,segmentblackBend)
		if (segmentwhiteB):
			whiteB = segmentwhiteB.group()
			segmentwhiteBend = segmentwhiteB.end()

		segmentwhiteA = whitespace.search(lineA,segmentblackAend)
		if (segmentwhiteA):
			whiteA = segmentwhiteA.group()
			segmentwhiteAend = segmentwhiteA.end()

		segmentblackB = blackspace.search(lineB,segmentwhiteBend)
		if (segmentblackB):
			blackB = segmentblackB.group()
			segmentblackBend = segmentblackB.end()

		segmentblackA = blackspace.search(lineA,segmentwhiteAend)
		if (segmentblackA):
			blackA = segmentblackA.group()
			segmentblackAend = segmentblackA.end()

		numberB = number.search(blackB)
		if (numberB and len(numberB.group()) > 0):
			numberA = number.search(blackA)
			if (numberA and len(numberA.group()) > 0):
				blackA = str(int(numberA.group()) - int(numberB.group()))
				newWhite = len(numberA.group()) - len(blackA)
				while newWhite > 0:
					blackA = ' ' + blackA
					newWhite = newWhite - 1

		sys.stdout.write(whiteA)
		sys.stdout.write(blackA)

