#!/bin/bash

# Copyright 2022, The Regents of the University of California.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
# IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of The Regents of the University of California.

iperf_count=8
netdev=
ifaddr=
netns=
base_port=9000
ptp4l=
mtu=

while getopts i:n:p:-: option; do
    case "${option}" in
        -)
            case "${OPTARG}" in
                ifaddr)
                    ifaddr="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                ifaddr=*)
                    ifaddr=${OPTARG#*=}
                    ;;
                netns)
                    netns="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                netns=*)
                    netns=${OPTARG#*=}
                    ;;
                mtu)
                    mtu="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                mtu=*)
                    mtu=${OPTARG#*=}
                    ;;
                ptp4l)
                    ptp4l=1
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        i) netdev=${OPTARG};;
        n) iperf_count=${OPTARG};;
        p) base_port=${OPTARG};;
    esac
done
shift $((OPTIND -1))

numa_cmd=
netns_cmd=

if [ ! -z "$netdev" ]; then
    if [ ! -z "$ifaddr" ]; then
        if [ -z "$netns" ]; then
            netns=$netdev
        fi
    fi

    if [ ! -x "$(command -v numactl)" ] ; then
        echo "numactl not found; cannot bind iperf to netdev NUMA node" >&2
    else
        numa_cmd="numactl -l -N netdev:$netdev"
    fi
else
    if [ ! -z "$ifaddr" ]; then
        echo "Interface address specified, but interface name not specified" >&2
        exit -1
    fi
fi

if [ ! -z "$netns" ]; then
    netns_cmd="ip netns exec $netns"
    if [ -f "/var/run/netns/$netns" ]; then
        echo "Network namespace '$netns' already exists"
    else
        echo "Creating network namespace '$netns'"
        ip netns add $netns
        echo "Adding interface '$netdev' to network namespace '$netns'"
        ip link set dev $netdev netns $netns
        $netns_cmd ip link set dev $netdev up
    fi
fi

if [ ! -z "$ifaddr" ]; then
    echo "Adding address '$ifaddr' to '$netdev'"
    $netns_cmd ip addr add $ifaddr dev $netdev
fi

if [ ! -z "$mtu" ]; then
    echo "Changing MTU to $mtu on '$netdev'"
    $netns_cmd ip link set mtu $mtu dev $netdev
fi

function cleanup()
{
    echo "Cleaning up..."

    # kill all subprocesses
    trap '' TERM
    pkill -P $$

    # clean up netns
    if [ ! -z "$netns" ]; then
        if [ -f "/var/run/netns/$netns" -a -z "$(ip netns pids $netns)" ]; then
            echo "Deleting network namespace '$netns'"
            ip netns del $netns
        fi
    fi
}

trap "exit" INT TERM
trap cleanup EXIT

# start servers

for i in $(seq 1 $iperf_count); do
    echo Starting iperf3 instance $i on port $(($base_port+i))
    $netns_cmd $numa_cmd iperf3 -p $(($base_port+i)) "$@" &
done

if [ ! -z $ptp4l ]; then
    $netns_cmd ptp4l -i $netdev -m --masterOnly=1 --tx_timestamp_timeout=10 --logSyncInterval=-3 &
fi

wait
