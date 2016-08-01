#!/usr/bin/python

#
# LPCPU (Linux Performance Customer Profiler Utility): ./rtst.py
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#


import signal
import os
import sys
import threading
import thread
import subprocess
import re
import time
import pprint
from collections import deque
import BaseHTTPServer
import SocketServer
import socket
import json
import getopt
import zlib
import mimetypes

exit_event = threading.Event()

cpu_data = deque()
vm_data = deque()
mem_data = deque()
net_data = deque()

def shutdown(msg, evt):
    print "%s: Stopping..." % (msg)
    httpd.shutdown()
    evt.set()
    return

def sigint_handler(signum, frame):
    sigint_thread = threading.Thread(target = shutdown, args = ('\nSIGINT received', exit_event))
    sigint_thread.start()
    sigint_thread.join()
    return

def get_data(deck, data_type, timestamp):
    data = ""
    count = 0
    data_dump = []

    # Does the sar contain "guest nice"?  assume no
    cpu_gnice = 0

    for item in deck:
        if item['time'] > timestamp:
            if data_type == 'mem':
                data_dump.append([ item['time'], item['kbbuffers'], item['kbcached'], item['kbmemused'] - item['kbbuffers'] - item['kbcached'], item['kbmemfree'] ])
            elif data_type == 'cpu':
                cpu_dump = [ item['time'], item['%sys'], item['%irq'], item['%soft'], item['%guest'], item['%usr'], item['%nice'], item['%steal'], item['%iowait'], item['%idle'] ]

                if '%gnice' in item:
                    cpu_gnice = 1
                    cpu_dump.insert(5, item['%gnice'])

                data_dump.append(cpu_dump)
            elif data_type == 'io_bw':
                data_dump.append([ item['time'], item['pgpgin/s'], item['pgpgout/s'] ])
            elif data_type == 'net':
                interface_dump = [ item['time'] ]

                for interface in selected_interfaces:
                    interface_dump.append( item[interface]['rxkB/s'] )
                    interface_dump.append( item[interface]['txkB/s'] )

                data_dump.append( interface_dump )

    if data_type == 'mem':
        data += json.dumps( { "data_series_names": [ "time", "Buffer Cache", "Page Cache", "Other", "Free" ], "x_axis_series": "time", "data": data_dump } )
    elif data_type == 'cpu':
        cpu_fields = [ "time", "% System", "% IRQ", "% Soft IRQ", "% Guest", "% Userspace", "% Nice", "% Steal", "% IO Wait", "% Idle" ]

        if cpu_gnice:
            cpu_fields.insert(5, "% Guest Nice")

        data += json.dumps( { "data_series_names": cpu_fields, "x_axis_series": "time", "data": data_dump } )
    elif data_type == 'io_bw':
        data += json.dumps( { "data_series_names": [ "time", "Read IO", "Write IO" ], "x_axis_series": "time", "data": data_dump } )
    elif data_type == 'net':
        series_dump = [ "time" ]

        for interface in selected_interfaces:
            series_dump.append( interface + " Receive" )
            series_dump.append( interface + " Transmit" )

        data += json.dumps({ "data_series_names" : series_dump, "x_axis_series": "time", "data": data_dump })

    data += "\n"

    return data

def sar_executor(name, sar_process, interfaces_list, history_length):
    mode = ""
    sample = dict()
    while not exit_event.is_set():
        sar_process.stdout.flush()
        sar_output = sar_process.stdout.readline()
        sar_output = sar_output.rstrip('\n')
        is_header = 0
        if len(sar_output):
            if re.search('CPU.*%usr', sar_output, re.L):
#                print "#########################################################################"
#                pprint.pprint(sample)

                if 'cpu' in sample:
#                    print "found cpu sample"
                    cpu_data.append(sample['cpu'])
                    if len(cpu_data) > history_length:
                        cpu_data.popleft()
#                        print "trimming cpu_data"

                if 'vm' in sample:
#                    print "found vm sample"
                    vm_data.append(sample['vm'])
                    if len(vm_data) > history_length:
                        vm_data.popleft()
#                        print "trimming vm_data"

                if 'mem' in sample:
#                    print "found mem sample"
                    mem_data.append(sample['mem'])
                    if len(mem_data) > history_length:
                        mem_data.popleft()
#                        print "trimming mem_data"

                if 'net' in sample:
#                    print "found net sample"
                    net_data.append(sample['net'])
                    if len(net_data) > history_length:
                        net_data.popleft()
#                        print "trimming net_data"

                is_header = 1
                sample = dict()
                sample['time'] = int(time.time() * 1000)
                mode = "cpu"
            elif re.search('pgpgin.*pgpgout', sar_output, re.L):
                is_header = 1
                mode = "vm"
            elif re.search('kbmemfree', sar_output, re.L):
                is_header = 1
                mode = "mem"
            elif re.search('IFACE', sar_output, re.L):
                is_header = 1
                mode = "net"
                # pre-populate the time in the net sample since it will (potentially) cover processing of multiple sar output lines (different interfaces)
                sample['net'] = { 'time': sample['time'] }
            elif re.search('Linux', sar_output, re.L):
                mode = "none"

            if is_header:
                header = sar_output.split()
                # remove the time sample since we ignore it
                header.pop(0)
#                print "header=[%s]\n" % ",".join(header)
                continue
                           
            fields = sar_output.split()
            # remove the time sample since we ignore it
            fields.pop(0)
            field_offset = 0
            if mode == 'cpu' or mode == 'net':
                field_offset = 1

            if mode == 'cpu' or mode == 'vm' or mode == 'mem':
                sample[mode] = { 'time': sample['time'] }
                for index in range(field_offset, len(header)):
#                    print "header=[%s] value=[%f]\n" % (header[index], float(fields[index]))
                    sample[mode].update({ header[index]: float(fields[index]) })
            elif mode == 'net':
                if fields[0] in interfaces_list:
                    sample[mode].update({ fields[0]: dict() })
                    for index in range(field_offset, len(header)):
#                        print "interface=[%s] header=[%s] value=[%f]\n" % (fields[0], header[index], float(fields[index]))
                        sample[mode][fields[0]].update({ header[index]: float(fields[index]) })

#            print fields

    sar_process.terminate()
    return

def web_server_executor(name, httpd):
    httpd.serve_forever()
    return

def run_sar(interval, interfaces_list, history_length):
    # set the environment variable LC_TIME="POSIX" to force sar to print in 24-hr format rather than 12-hr with AM/PM designation
    sar_process = subprocess.Popen(["sar", "-n", "DEV", "-u", "ALL", "-B", "-r", str(interval)], stdout=subprocess.PIPE, env=dict(os.environ, LC_TIME="POSIX") )

    sar_thread = threading.Thread(target = sar_executor, args = ("SAR thread", sar_process, interfaces_list, history_length))
    sar_thread.start()
    return

def run_web_server(httpd):
    web_server_thread = threading.Thread(target = web_server_executor, args = ("Web Server", httpd))
    web_server_thread.start()
    return

def get_network_interfaces():
    interface_list = []

    with open('/proc/net/dev', 'r') as proc_net_dev:
        interface_data =  proc_net_dev.readlines()
    proc_net_dev.close()

    for line in interface_data:
        fields = line.split()
        if fields[0].endswith(':'):
            interface = fields[0].rstrip(':')
            interface_list.append(interface)
        elif ':' in fields[0]:
            fields = fields[0].split(':')
            interface_list.append(fields[0])
    return interface_list

##########################################################################################

class MyHTTPRequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'RTST/%d' % (time.time())
    sys_version = 'LPCPU/%d' % (time.time())

    def http_reply(self, compress, code, content_type, response):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        if compress:
            if re.search('deflate', self.headers['Accept-Encoding'], re.L):
                response = zlib.compress(response)
                self.send_header('Content-Encoding', 'deflate')
        self.send_header('Content-Length', len(response))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.request.sendall(response)
#        if compress:
#            pprint.pprint(response)
        return

    def do_GET(self):
#        print "do_GET called"

#        pprint.pprint(self.headers.headers)

        code = 200
        mime_type = "text/text"
        response = ""

        compress = 0
        if 'accept-encoding' in self.headers:
            if re.search('deflate', self.headers['Accept-Encoding'], re.L):
                compress = 1
#                print "accept-encoding: %s\n" % self.headers['accept-encoding']

        if len(self.path) > 1:
            request_path = working_dir_pathname + "/tools/rtst" + self.path
        else:
            request_path = working_dir_pathname + "/tools/rtst/index.html"

        try:
            fd = open(request_path, 'r')
            response = fd.read()
            (mimetype, encoding) = mimetypes.guess_type(request_path)
            if mimetype != "None":
                mime_type = mimetype
        except:
            response = "ERROR: Could not read %s\n" % (request_path)
            code = 404

        if request_path == working_dir_pathname + "/tools/rtst/index.html":
            response = response.replace('%SERVER_NAME%', server_name)
            response = response.replace('%SERVER_PORT%', str(server_port))
            response = response.replace('%CLIENT_UPDATE_INTERVAL%', str(client_update_interval))
            response = response.replace('%CLIENT_HISTORY_LENGTH%', str(client_history_length))

        self.http_reply(compress, code, mime_type, response)

        return

    def do_POST(self):
#        print "do_POST called"

#        pprint.pprint(self.headers.headers)

        length = int(self.headers['Content-Length'])
        content = self.rfile.read(length)

        compress = 0
        if 'accept-encoding' in self.headers:
            if re.search('deflate', self.headers['accept-encoding'], re.L):
                compress = 1
#                print "accept-encoding: %s\n" % self.headers['accept-encoding']

        params = dict()

        # default to replying with cpu data in case no specific request type is made
        params['type'] = 'cpu'

        if length > 0:
            fields = content.split("&")
            for field in fields:
                key_value = field.split("=", 1)
                if len(key_value) == 2:
                    params[key_value[0]] = key_value[1]
                else:
                    self.http_reply(compress, 400, "text/html", "unhandled parameter [%s]\n" % field)
                    return

#        pprint.pprint(params)

        timestamp = 0
        if 'time' in params:
            if len(params['time']):
                timestamp = float(params['time'])
            else:
                self.http_reply(compress, 400, "text/html", "invalid timestamp specified\n")
                return

        response = "empty"
        if 'type' in params:
            if params['type'] == "cpu":
                response = get_data(cpu_data, params['type'], timestamp)
            elif params['type'] == "io_bw":
                response = get_data(vm_data, params['type'], timestamp)
            elif params['type'] == "mem":
                response = get_data(mem_data, params['type'], timestamp)
            elif params['type'] == "net":
                response = get_data(net_data, params['type'], timestamp)
            else:
                self.http_reply(compress, 400, "text/html", "unknown 'type=%s' specified\n" % params['type'])
                return

        self.http_reply(compress, 200, "application/json", response)

        return

    def log_message(self, format, *args):
        # no logging for now...
        return

##########################################################################################

def usage():
    print "\nRequired options for %s are:\n" % sys.argv[0]
    print "\t--server-interval=<int>\t\tHow often should the server collect samples"
    print "\t--client-interval=<int>\t\tHow often should the client request new data from the server"
    print "\t--server-history=<int>\t\tHow many samples should the server buffer for sample history"
    print "\t--client-history=<int>\t\tHow many samples should the client buffer for sample history by default (client can dynamically change this value)"
    print "\t--server-name=<string>\t\tWhat is the accessible hostname the client should use to access the server"
    print "\t--server-port=<int>\t\tWhat TCP port should the server listen on (must be open through any/all firewalls)"
    print "\t--selected-interfaces=<string>\tComma separated list of interfaces to monitor"
    print "\n\tAvailable interfaces for monitoring are: %s\n" % (" ".join(available_interfaces))
    return

monitor_interval = 0
client_update_interval = 0
history_length = 0
client_history_length = 0
server_name = ""
server_port = 0
selected_interfaces = []

available_interfaces = get_network_interfaces()

script_pathname = os.path.dirname(sys.argv[0])
working_dir_pathname = os.path.abspath(script_pathname)

try:
    opts, args = getopt.getopt(sys.argv[1:], "h", [ "help", "server-interval=", "client-interval=", "server-history=", "client-history=", "server-name=", "server-port=", "selected-interfaces=" ])
except getopt.GetoptError as err:
    print str(err)
    usage()
    sys.exit(2)

for o, a in opts:
    if o in ("-h", "--help"):
        usage()
        sys.exit()
    elif o == "--server-interval":
        monitor_interval = int(a)
    elif o == "--client-interval":
        client_update_interval = int(a)
    elif o == "--server-history":
        history_length = int(a)
    elif o == "--client-history":
        client_history_length = int(a)
    elif o == "--server-name":
        server_name = a
    elif o == "--server-port":
        server_port = int(a)
    elif o == "--selected-interfaces":
        fields = a.split(',')
        for field in fields:
            if field in available_interfaces:
                selected_interfaces.append(field)
            else:
                print "ERROR: Invalid interface '%s' specified.  Valid interfaces are: %s\n" % (field, " ".join(available_interfaces))
                sys.exit(2)
    else:
        assert False, "unhandled option"

if monitor_interval == 0:
    usage()
    sys.exit(3)
elif client_update_interval == 0:
    usage()
    sys.exit(4)
elif history_length == 0:
    usage()
    sys.exit(5)
elif client_history_length == 0:
    usage()
    sys.exit(6)
elif server_name == "":
    usage()
    sys.exit(7)
elif server_port == 0:
    usage()
    sys.exit(8)
elif len(selected_interfaces) == 0:
    usage()
    sys.exit(9)

print "Main Thread: Started..."

print "Monitoring %s" % ",".join(selected_interfaces)
print "Monitoring Interval: %d" % monitor_interval
print "Client Update Interval: %d" % client_update_interval
print "History Length: %d" % history_length
print "Client History Length: %d" % client_history_length
print "Server Name: %s" % server_name
print "Server Port: %d" % server_port

SocketServer.TCPServer.allow_reuse_address = True
httpd = BaseHTTPServer.HTTPServer(('', server_port), MyHTTPRequestHandler)

run_web_server(httpd)

signal.signal(signal.SIGINT, sigint_handler)

run_sar(monitor_interval, selected_interfaces, history_length)

print "To view the statistics, load http://%s:%d in your web browser" % (server_name, server_port)
print "To exit the server, use CTRL-C"

#print "Main Thread: Idling..."

while not exit_event.is_set():
    exit_event.wait(0.5)

print "Main Thread: Exiting..."
print "Goodbye!"
sys.exit()
