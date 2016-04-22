#!/bin/bash

## Paths and definitions
tc=/sbin/tc

int=eth1
int_real_speed=1000
int_link_speed=$(echo "$int_real_speed * 0.95" | bc | xargs printf "%.0fmbit" )
int_link_speed_half=$(echo "$int_real_speed * 0.5" | bc | xargs printf "%.0fmbit" )
int_limit=1000kbit # Rated down

ext=eth2
ext_real_speed=1000
ext_link_speed=$(echo "$ext_real_speed * 0.95" | bc | xargs printf "%.0fmbit" )
ext_link_speed_half=$(echo "$ext_real_speed * 0.5" | bc | xargs printf "%.0fmbit" )
ext_limit=1000kbit    # Rated up


# #########
# # INGRESS
# #########

# Delete all qdiscs
$tc qdisc del dev $int root

# Enable HTB qdisc
$tc qdisc replace dev $int root handle 1: htb default 20

$tc class add dev $int parent 1: classid 1:1 htb rate $int_link_speed

$tc class add dev $int parent 1:1 classid 1:10 htb rate 1mbit ceil $int_link_speed_half prio 1
$tc class add dev $int parent 1:1 classid 1:20 htb rate $int_limit ceil $int_limit prio 2
$tc class add dev $int parent 1:1 classid 1:30 htb rate 1mbit ceil $int_link_speed prio 3

tc qdisc add dev $int parent 1:10 fq_codel
tc qdisc add dev $int parent 1:20 fq_codel
tc qdisc add dev $int parent 1:30 fq_codel

# #########
# # EGRESS
# #########

$tc qdisc del dev $ext root

$tc qdisc replace dev $ext root handle 1: htb default 20

$tc class add dev $ext parent 1: classid 1:1 htb rate $ext_link_speed

$tc class add dev $ext parent 1:1 classid 1:10 htb rate 1mbit ceil $ext_link_speed_half prio 1
$tc class add dev $ext parent 1:1 classid 1:20 htb rate $ext_limit ceil $int_limit prio 2
$tc class add dev $ext parent 1:1 classid 1:30 htb rate 1mbit ceil $ext_link_speed prio 3

tc qdisc add dev $ext parent 1:10 fq_codel
tc qdisc add dev $ext parent 1:20 fq_codel
tc qdisc add dev $ext parent 1:30 fq_codel
