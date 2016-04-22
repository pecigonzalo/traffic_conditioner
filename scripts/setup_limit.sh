#!/bin/bash

## Paths and definitions
tc=/sbin/tc


iface=eth1
iface_ingress=ifb1

raw_in_speed=1000 # Mbit
raw_out_speed=1000 # Mbit

in_limit=2000 #kbit # Rated down
out_limit=1000 #kbit    # Rated up

# Default classes
out_prio=10mbit
out_bulk=1mbit

in_prio=10mbit
in_bulk=1mbit

# Calculate overhead
in_speed=$(echo "$raw_in_speed * 0.93" | bc | xargs printf "%.0fmbit" )
in_speed_half=$(echo "$raw_in_speed * 0.5" | bc | xargs printf "%.0fmbit" )
# Enable the next line to account or overhead
in_limit=$(echo "$in_limit * 0.93" | bc | xargs printf "%.0fkbit" )

out_speed=$(echo "$raw_out_speed * 0.93" | bc | xargs printf "%.0fmbit" )
out_speed_half=$(echo "$raw_out_speed * 0.5" | bc | xargs printf "%.0fmbit" )
# Enable the next line to account for overhead
out_limit=$(echo "$out_limit * 0.93" | bc | xargs printf "%.0fkbit" )

######################################

echo '# Load IFB, all other modules all loaded automatically'
modprobe ifb

echo '# Cleanup old qdisc configs'
$tc qdisc del dev $iface root 2> /dev/null > /dev/null
$tc qdisc del dev $iface ingress 2> /dev/null > /dev/null
$tc qdisc del dev $iface_ingress root 2> /dev/null > /dev/null
$tc qdisc del dev $iface_ingress ingress 2> /dev/null > /dev/null

# appending "stop" (without quotes) after the name of the script stops here.
if [ "$1" = "stop" ]
then
        echo "Shaping removed."
        exit
fi

echo '# Bring virtual devs up'
ip link set dev $iface_ingress up

######################################

# #########
echo '# OUTBOUND ( VPNServer -> WWW ) ( VPNServer -> VPNClients )'
# #########

echo '# Enable HTB qdisc'
$tc qdisc replace dev $iface root handle 1: htb default 20

$tc class add dev $iface parent 1: classid 1:1 htb rate $out_speed

$tc class add dev $iface parent 1:1 classid 1:10 htb rate $out_prio ceil $out_speed_half prio 1
$tc class add dev $iface parent 1:1 classid 1:20 htb rate $out_limit ceil $out_limit prio 2
$tc class add dev $iface parent 1:1 classid 1:30 htb rate $out_bulk ceil $out_limit prio 3

$tc qdisc add dev $iface parent 1:10 fq_codel
$tc qdisc add dev $iface parent 1:20 fq_codel
$tc qdisc add dev $iface parent 1:30 fq_codel

echo "# Set filters"
# TOS Minimum Delay (ssh, NOT scp) in 1:10:
$tc filter add dev $iface parent 1:0 protocol ip prio 10 u32 \
      match ip tos 0x10 0xff  classid 1:10

# ICMP (ip protocol 1) in the interactive class 1:10
$tc filter add dev $iface parent 1:0 protocol ip prio 11 u32 \
        match ip protocol 1 0xff classid 1:10

echo '# Prioritize small packets'
$tc filter add dev $iface parent 1: protocol ip prio 12 u32 \
   match ip protocol 6 0xff \
   match u8 0x05 0x0f at 0 \
   match u16 0x0000 0xffc0 at 2 \
   classid 1:10

# rest is 'non-interactive' ie 'bulk' and ends up in 1:20
$tc filter add dev $iface parent 1: protocol ip prio 18 u32 \
   match ip dst 0.0.0.0/0 classid 1:20

# #########
echo '# INBOUND ( WWW -> VPNServer ) ( VPNClients -> VPNServer )'
# #########

echo '# Forward all ingress traffic on internet interface to the IFB device'
$tc qdisc add dev $iface ingress handle ffff:
$tc filter add dev $iface parent ffff: protocol all \
    u32 match u32 0 0 \
    action mirred egress redirect dev $iface_ingress

echo '# Enable HTB qdisc on ingress'
$tc qdisc replace dev $iface_ingress root handle 1: htb default 20

$tc class add dev $iface_ingress parent 1: classid 1:1 htb rate $in_speed

$tc class add dev $iface_ingress parent 1:1 classid 1:10 htb rate $in_prio ceil $in_speed_half prio 1
$tc class add dev $iface_ingress parent 1:1 classid 1:20 htb rate $in_limit ceil $in_limit prio 2
$tc class add dev $iface_ingress parent 1:1 classid 1:30 htb rate $in_bulk ceil $in_limit prio 3

$tc qdisc add dev $iface_ingress parent 1:10 fq_codel
$tc qdisc add dev $iface_ingress parent 1:20 fq_codel
$tc qdisc add dev $iface_ingress parent 1:30 fq_codel

echo "# Set filters"
# TOS Minimum Delay (ssh, NOT scp) in 1:10:
$tc filter add dev $iface_ingress parent 1:0 protocol ip prio 10 u32 \
      match ip tos 0x10 0xff  classid 1:10

# ICMP (ip protocol 1) in the interactive class 1:10
$tc filter add dev $iface_ingress parent 1:0 protocol ip prio 11 u32 \
        match ip protocol 1 0xff classid 1:10

echo '# Prioritize small packets'
$tc filter add dev $iface_ingress parent 1: protocol ip prio 12 u32 \
   match ip protocol 6 0xff \
   match u8 0x05 0x0f at 0 \
   match u16 0x0000 0xffc0 at 2 \
   classid 1:10

# rest is 'non-interactive' ie 'bulk' and ends up in 1:20
$tc filter add dev $iface_ingress parent 1: protocol ip prio 18 u32 \
   match ip dst 0.0.0.0/0 classid 1:20