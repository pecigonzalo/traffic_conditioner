#!/bin/bash

_QUIET=0
_USE_DEBUG=0

PROGNAME=${0##*/}

info() {
  if [ ${_QUIET} -eq 0 ]; then
    echo "INFO: $@"
  fi
}

debug() {
  if [ ${_USE_DEBUG} -eq 1 ]; then
    echo "DEBUG: $@"
  fi
}

## Paths and definitions
tc=/sbin/tc

iface=enp3s0
iface_ingress=ifb0

raw_in_speed=1000 # Mbytes
raw_out_speed=1000 # Mbytes

in_limit=1000000 #kbytes
out_limit=1000000 #kbytes

# Default classes
out_prio=10mbit
out_bulk=10mbit

in_prio=10mbit
in_bulk=10mbit

# Parse command-line
while [[ -n $1 ]]; do
  case $1 in
    -d | --iface)
      shift; iface="$1"
      ;;
    -v | --viface)
      shift; iface_ingress="$1"
      ;;
    -i | --input-limit)
      shift; in_limit="$1"
      ;;
    -o | --output-limit)
      shift; out_limit="$1"
      ;;
    --stop)
      shift; stop=1
      ;;
    --debug)
      _USE_DEBUG=1
      ;;
  esac
  shift
done

# Calculate overhead
in_speed=$(echo "$raw_in_speed" |  awk '{ print $1 * 0.93 "mbps" }' )
in_speed_half=$(echo "$raw_in_speed" |  awk '{ print $1 * 0.5 "mbps" }' )
in_limit=$(echo "$in_limit" |  awk '{ print $1 "kbps" }' )

out_speed=$(echo "$raw_out_speed" |  awk '{ print $1 * 0.93 "mbps" }' )
out_speed_half=$(echo "$raw_out_speed" |  awk '{ print $1 * 0.5 "mbps" }' )
out_limit=$(echo "$out_limit" |  awk '{ print $1 "kbps" }' )

######################################

debug 'Load IFB, all other modules all loaded automatically'
modprobe ifb

info 'Cleanup old qdisc configs'
$tc qdisc del dev $iface root 2> /dev/null > /dev/null
$tc qdisc del dev $iface ingress 2> /dev/null > /dev/null
$tc qdisc del dev $iface_ingress root 2> /dev/null > /dev/null
$tc qdisc del dev $iface_ingress ingress 2> /dev/null > /dev/null

info 'Done'

# appending "stop" (without quotes) after the name of the script stops here.
if [ ! -z "$stop" ]
then
        info "Shaping removed."
        exit
fi

debug 'Bring virtual devs up'
ip link set dev $iface_ingress up

######################################

# #########
info 'Set OUTBOUND ( VPNServer -> WWW ) ( VPNServer -> VPNClients )'
# #########

debug 'Enable HTB qdisc'
$tc qdisc replace dev $iface root handle 1: htb default 20

$tc class add dev $iface parent 1: classid 1:1 htb rate $out_speed

$tc class add dev $iface parent 1:1 classid 1:10 htb rate $out_prio ceil $out_speed_half prio 1
$tc class add dev $iface parent 1:1 classid 1:20 htb rate $out_limit ceil $out_limit prio 2
$tc class add dev $iface parent 1:1 classid 1:30 htb rate $out_bulk ceil $out_limit prio 3

$tc qdisc add dev $iface parent 1:10 fq_codel limit 1000 ecn
$tc qdisc add dev $iface parent 1:20 fq_codel limit 1000 ecn
$tc qdisc add dev $iface parent 1:30 fq_codel limit 1000 ecn

debug "Set filters"
# TOS Minimum Delay (ssh, NOT scp) in 1:10:
$tc filter add dev $iface parent 1:0 protocol ip prio 10 u32 \
      match ip tos 0x10 0xff  classid 1:10

# ICMP (ip protocol 1) in the interactive class 1:10
$tc filter add dev $iface parent 1:0 protocol ip prio 11 u32 \
        match ip protocol 1 0xff classid 1:10

debug 'Prioritize small packets'
$tc filter add dev $iface parent 1: protocol ip prio 12 u32 \
   match ip protocol 6 0xff \
   match u8 0x05 0x0f at 0 \
   match u16 0x0000 0xffc0 at 2 \
   classid 1:10

info 'Done'

# #########
info 'Set INBOUND ( WWW -> VPNServer ) ( VPNClients -> VPNServer )'
# #########

debug 'Forward all ingress traffic on internet interface to the IFB device'
$tc qdisc add dev $iface ingress handle ffff:
$tc filter add dev $iface parent ffff: protocol all \
    u32 match u32 0 0 \
    action mirred egress redirect dev $iface_ingress

debug 'Enable HTB qdisc on ingress'
$tc qdisc replace dev $iface_ingress root handle 1: htb default 20

$tc class add dev $iface_ingress parent 1: classid 1:1 htb rate $in_speed

$tc class add dev $iface_ingress parent 1:1 classid 1:10 htb rate $in_prio ceil $in_speed_half prio 1
$tc class add dev $iface_ingress parent 1:1 classid 1:20 htb rate $in_limit ceil $in_limit prio 2
$tc class add dev $iface_ingress parent 1:1 classid 1:30 htb rate $in_bulk ceil $in_limit prio 3

$tc qdisc add dev $iface_ingress parent 1:10 fq_codel limit 1000 ecn
$tc qdisc add dev $iface_ingress parent 1:20 fq_codel limit 1000 ecn
$tc qdisc add dev $iface_ingress parent 1:30 fq_codel limit 1000 ecn

debug "Set filters"
# TOS Minimum Delay (ssh, NOT scp) in 1:10:
$tc filter add dev $iface_ingress parent 1:0 protocol ip prio 10 u32 \
      match ip tos 0x10 0xff  classid 1:10

# ICMP (ip protocol 1) in the interactive class 1:10
$tc filter add dev $iface_ingress parent 1:0 protocol ip prio 11 u32 \
        match ip protocol 1 0xff classid 1:10

debug 'Prioritize small packets'
$tc filter add dev $iface_ingress parent 1: protocol ip prio 12 u32 \
   match ip protocol 6 0xff \
   match u8 0x05 0x0f at 0 \
   match u16 0x0000 0xffc0 at 2 \
   classid 1:10

info 'Done'