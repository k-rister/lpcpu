
#
# LPCPU (Linux Performance Customer Profiler Utility): ./tools/jschart.pm/README.txt
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

Here are some performance tuning tips for hosting jschart charts:

1. Enable gzip compression on your web server

2. Enable connection keep-alive on your web server

3. Enable client side caching for your web server

Jschart has the potential to place an extreme load on the web server
and is sensitive to bandwidth and latency limitations between the
client and the server.  The tuning options above can reduce the impact
of those issues and improve the viewing experience.
