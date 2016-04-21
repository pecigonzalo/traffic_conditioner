#!/bin/sh

## Paths and definitions
tc=/sbin/tc
ext=eth2    # Change for your device!
ext_ingress=ifb0  # Use a unique ifb per rate limiter!
      # Set these as per your provider's settings, at 90% to start with
ext_up=800kbit    # Max theoretical: for this example, up is 1024kbit
ext_down=7100kbit # Max theoretical: for this example, down is 8192kbit
q=1514                  # HTB Quantum = 1500bytes IP + 14 bytes ethernet.
      # Higher bandwidths may require a higher htb quantum. MEASURE.
      # Some ADSL devices might require a stab setting.

quantum=300   # fq_codel quantum 300 gives a boost to interactive flows
      # At higher bandwidths (50Mbit+) don't bother


modprobe ifb
modprobe sch_fq_codel
modprobe act_mirred

# Clear old queuing disciplines (qdisc) on the interfaces
$tc qdisc del dev $ext root
$tc qdisc del dev $ext ingress
$tc qdisc del dev $ext_ingress root
$tc qdisc del dev $ext_ingress ingress

#########
# INGRESS
#########

# Create ingress on external interface
$tc qdisc add dev $ext handle ffff: ingress

# Forward all ingress traffic to the IFB device
$tc filter add dev $ext parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev $ext_ingress

# Create an EGRESS filter on the IFB device
$tc qdisc add dev $ext_ingress root handle 1: htb default 11

# Add root class HTB with rate limiting

$tc class add dev $ext_ingress parent 1: classid 1:1 htb rate $ext_down
$tc class add dev $ext_ingress parent 1:1 classid 1:11 htb rate $ext_down prio 0 quantum $q


# Add FQ_CODEL qdisc with ECN support (if you want ecn)
$tc qdisc add dev $ext_ingress parent 1:11 fq_codel quantum $quantum ecn

#########
# EGRESS
#########
# Add FQ_CODEL to EGRESS on external interface
$tc qdisc add dev $ext root handle 1: htb default 11

# Add root class HTB with rate limiting
$tc class add dev $ext parent 1: classid 1:1 htb rate $ext_up
$tc class add dev $ext parent 1:1 classid 1:11 htb rate $ext_up prio 0 quantum $q

# Note: You can apply a packet limit here and on ingress if you are memory constrained - e.g
# for low bandwidths and machines with < 64MB of ram, limit 1000 is good, otherwise no point

# Add FQ_CODEL qdisc without ECN support - on egress it's generally better to just drop the packet
# but feel free to enable it if you want.

$tc qdisc add dev $ext parent 1:11 fq_codel quantum $quantum noecn