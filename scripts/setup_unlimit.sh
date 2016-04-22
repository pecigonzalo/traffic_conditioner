#!/bin/sh

## Paths and definitions
tc=/sbin/tc
ext=eth2    # Change for your device!
ext_ingress=ifb0  # Use a unique ifb per rate limiter!

# Clear old queuing disciplines (qdisc) on the interfaces
$tc qdisc del dev $ext root
$tc qdisc del dev $ext ingress
$tc qdisc del dev $ext_ingress root
$tc qdisc del dev $ext_ingress ingress

ext=eth1    # Change for your device!
ext_ingress=ifb0  # Use a unique ifb per rate limiter!

# Clear old queuing disciplines (qdisc) on the interfaces
$tc qdisc del dev $ext root
$tc qdisc del dev $ext ingress
$tc qdisc del dev $ext_ingress root
$tc qdisc del dev $ext_ingress ingress