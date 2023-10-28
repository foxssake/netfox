#!/bin/bash

# DEV="$(ifconfig | head -n 1 | cut -f1 -d':')"
DEV="lo"
delay=$1
jitter=$2

if [ $# -eq 0 ]; then
	echo "Usage: $0 <latency> [jitter]"
	exit 1
fi

if [ "$1" == "reset" ]; then
	tc qdisc del dev $DEV root
	exit $?
fi

tc qdisc del dev $DEV root
tc qdisc add dev $DEV root netem delay $delay $jitter
