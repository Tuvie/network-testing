#!/bin/bash
#
# Script for injecting packets into RX path of the stack with pktgen
# "xmit_mode netif_receive".  With an invalid dst_mac this will only
# measure the ingress code path as packets gets dropped in ip_rcv().
#
basedir=`dirname $0`
source ${basedir}/functions.sh
root_check_run_with_sudo "$@"
source ${basedir}/parameters.sh

# Base Config
DELAY="0"        # Zero means max speed
COUNT="10000000" # Zero means indefinitely

# Using invalid DST_MAC will cause the packets to get dropped in
# ip_rcv() which is part of the test
[ -z "$DEST_IP" ] && DEST_IP="198.18.0.42"
[ -z "$DST_MAC" ] && DST_MAC="90:e2:ba:ff:ff:ff"
[ -z "$BURST" ] && BURST=32

# General cleanup everything since last run
pg_ctrl "reset"

# Threads are specified with parameter -t value in $THREADS
for ((thread = 0; thread < $THREADS; thread++)); do
    # The device name is extended with @name, using thread number to
    # make then unique, but any name will do.
    dev=${DEV}@${thread}

    # Add remove all other devices and add_device $dev to thread
    pg_thread $thread "rem_device_all"
    pg_thread $thread "add_device" $dev

    # Base config of dev
    pg_set $dev "flag QUEUE_MAP_CPU"
    pg_set $dev "count $COUNT"
    pg_set $dev "pkt_size $PKT_SIZE"
    pg_set $dev "delay $DELAY"
    pg_set $dev "flag NO_TIMESTAMP"

    # Destination
    pg_set $dev "dst_mac $DST_MAC"
    pg_set $dev "dst $DEST_IP"

    # Inject packet into RX path of stack
    pg_set $dev "xmit_mode netif_receive"

    # Burst allow us to avoid measuring SKB alloc/free overhead
    pg_set $dev "burst $BURST"
done

# start_run
echo "Running... ctrl^C to stop" >&2
pg_ctrl "start"
echo "Done" >&2

# Print results
for ((thread = 0; thread < $THREADS; thread++)); do
    dev=${DEV}@${thread}
    echo "Device: $dev"
    cat /proc/net/pktgen/$dev | grep -A2 "Result:"
done