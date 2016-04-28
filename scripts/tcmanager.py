#!/usr/bin/env python
# coding: utf-8
# requ dateutil

import json
from datetime import datetime
from dateutil.relativedelta import relativedelta
import urllib
import subprocess
import ConfigParser

# Load config
config = ConfigParser.ConfigParser()
config.read("tcmanager/config.ini")

LOCATIONS_SERVER = config.get('Main', 'LocationServer')
HOSTNAME = config.get('Main', 'Hostname')
INTERFACE = config.get('Main', 'Interface')
IFBINTERFACE = config.get('Main', 'IFBInterface')
LOWERLIMIT = config.get('Main', 'LowerLimit')

# Get server info

json_server = json.load(urllib.urlopen("https://%s/servers/%s" % (LOCATIONS_SERVER, HOSTNAME)))
json_data_report = json.load(urllib.urlopen("https://%s/data/report/%s" % (LOCATIONS_SERVER, HOSTNAME)))

reset_day = json_server['limit_reset_day']
data_limit = json_data_report['data_limit']

if json_server['limit_type'] == 'rx':
    data_consumed = json_data_report['rx_total']
elif json_server['limit_type'] == 'tx':
    data_consumed = json_data_report['tx_total']
elif json_server['limit_type'] == 'higher':
    if json_data_report['tx_total'] > json_data_report['rx_total']:
        data_consumed = json_data_report['tx_total']
    else:
        data_consumed = json_data_report['rx_total']
else:
    data_consumed = json_data_report['rx_total'] + json_data_report['tx_total']


data_left = data_limit - data_consumed

# Calculate full reset date

current_date = datetime.today()
print "Current date: %s" % current_date

reset_date = datetime(
    current_date.year,
    current_date.month,
    reset_day)

if reset_date < current_date:
    reset_date = reset_date + relativedelta(months=1)
print "Reset Date: %s" % reset_date

days_left = (reset_date - current_date).days

print "Days Left: %s" % days_left

time_left = days_left * 24 * 60 * 60
time_left_kbps = data_left / time_left

if time_left_kbps < LOWERLIMIT:
    time_left_kbps = LOWERLIMIT

limit_in = "./setup_limit.sh -d %s -v %s -i %s" % (INTERFACE, IFBINTERFACE, time_left_kbps)

limit_out = "./setup_limit.sh -d %s -v %s -o %s" % (INTERFACE, IFBINTERFACE, time_left_kbps)

limit_all = "./setup_limit.sh -d %s -v %s -i %s -o %s" % (INTERFACE, IFBINTERFACE, time_left_kbps, time_left_kbps)

if json_server['limit_type'] == 'rx':
    command = limit_in
elif json_server['limit_type'] == 'tx':
    command = limit_out
else:
    command = limit_all



print "Limit to: %s Kbps" % time_left_kbps
process = subprocess.Popen(command, shell=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT)
output = process.stdout.readlines()
print "Command output: "
for l in output:
        print '  ' + l[:-1]

