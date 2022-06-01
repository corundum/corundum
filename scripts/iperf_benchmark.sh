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

max_iperf_count=1
repeats=1
iperf_p=4
ip=
netdev=
ifaddr=
netns=
base_port=9000
mtu=
base_logdir=./logs/

while getopts i:n:P:c:p:r:-: option; do
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
                logdir)
                    base_logdir="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                logdir=*)
                    base_logdir=${OPTARG#*=}
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        i) netdev=${OPTARG};;
        n) max_iperf_count=${OPTARG};;
        P) iperf_p=${OPTARG};;
        c) ip=${OPTARG};;
        p) base_port=${OPTARG};;
        r) repeats=${OPTARG};;
    esac
done
shift $((OPTIND -1))

if [ -z "$netdev" ]; then
    netdev=$(ip route get $ip | grep -oP "dev\s+\K\w+")
    echo "Using local device '$netdev'"
fi

numa_cmd=
netns_cmd=

iperf_args=

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

# run measurement

function run_meas()
{
    test_type=$1
    iperf_count=$2
    rep=$3

    logdir="$base_logdir/n$iperf_count/$test_type/$rep/"
    mkdir -p $logdir

    # start clients
    case "$test_type" in
        tx)
            for i in $(seq 1 $iperf_count); do
                port=$(($base_port+i))
                logfile="$logdir/iperf-client-tx-$i.log"
                echo Starting iperf3 TX instance $i on port $port
                echo -n > "$logfile"
                $netns_cmd $numa_cmd iperf3 -p $port -P $iperf_p -c $ip -f k -t 12 --logfile "$logfile" $iperf_args &
            done
            ;;
        rx)
            for i in $(seq 1 $iperf_count); do
                port=$(($base_port+i))
                logfile="$logdir/iperf-client-rx-$i.log"
                echo Starting iperf3 RX instance $i on port $port
                echo -n > "$logfile"
                $netns_cmd $numa_cmd iperf3 -p $port -P $iperf_p -c $ip -f k -t 12 --logfile "$logfile" -R $iperf_args &
            done
            ;;
        txrx)
            for i in $(seq 1 $iperf_count); do
                port=$(($base_port+i))
                logfile="$logdir/iperf-client-tx-$i.log"
                echo Starting iperf3 TX instance $i on port $port
                echo -n > "$logfile"
                $netns_cmd $numa_cmd iperf3 -p $port -P $iperf_p -c $ip -f k -t 12 --logfile "$logfile" $iperf_args &
                port=$(($base_port+$iperf_count+i))
                logfile="$logdir/iperf-client-rx-$i.log"
                echo Starting iperf3 RX instance $i on port $port
                echo -n > "$logfile"
                $netns_cmd $numa_cmd iperf3 -p $port -P $iperf_p -c $ip -f k -t 12 --logfile "$logfile" -R $iperf_args &
            done
            ;;
    esac

    sleep 1

    # capture performance counters
    $netns_cmd cat /proc/net/dev > $logdir/proc_net_dev.log
    cat /proc/stat > $logdir/proc_stat.log
    start_time=$(date +%s.%N)
    for i in $(seq 1 10); do
        sleep 1
        $netns_cmd cat /proc/net/dev >> $logdir/proc_net_dev.log
        cat /proc/stat >> $logdir/proc_stat.log
        echo -n .
    done
    end_time=$(date +%s.%N)
    elapsed=$(echo "scale=4; $end_time - $start_time" | bc)

    wait
    echo

    # aggregate
    lcl_txkbps=0
    lcl_txretr=0
    lcl_rxkbps=0
    rmt_txkbps=0
    rmt_txretr=0
    rmt_rxkbps=0
    shopt -s nullglob
    for file in $logdir/iperf-client-tx-*.log; do
        sender=$(cat $file | tr -s ' ' | grep "\[SUM\]" | grep sender)
        receiver=$(cat $file | tr -s ' ' | grep "\[SUM\]" | grep receiver)

        lcl_txkbps=$(($lcl_txkbps + $(echo "$sender" | cut -d ' ' -f 6)))
        lcl_txretr=$(($lcl_txretr + $(echo "$sender" | cut -d ' ' -f 8)))
        rmt_rxkbps=$(($rmt_rxkbps + $(echo "$receiver" | cut -d ' ' -f 6)))
    done
    shopt -s nullglob
    for file in $logdir/iperf-client-rx-*.log; do
        sender=$(cat $file | tr -s ' ' | grep "\[SUM\]" | grep sender)
        receiver=$(cat $file | tr -s ' ' | grep "\[SUM\]" | grep receiver)

        rmt_txkbps=$(($rmt_txkbps + $(echo "$sender" | cut -d ' ' -f 6)))
        rmt_txretr=$(($rmt_txretr + $(echo "$sender" | cut -d ' ' -f 8)))
        lcl_rxkbps=$(($lcl_rxkbps + $(echo "$receiver" | cut -d ' ' -f 6)))
    done

    if_stat=$(grep "$netdev:" "$logdir/proc_net_dev.log" | tr -s ' ' | cut -d ' ' -f 2- | sed -n '1p;$p' | awk 'NR==1{for(i=1;i<=NF;i++){col[i]=$i};next}{for(i=1;i<=NF;i++){printf "%s ",$i-col[i];col[i]=$i};print ""}')
    intr_stat=$(grep "intr" "$logdir/proc_stat.log" | tr -s ' ' | cut -d ' ' -f 2- | sed -n '1p;$p' | awk 'NR==1{for(i=1;i<=NF;i++){col[i]=$i};next}{for(i=1;i<=NF;i++){printf "%s ",$i-col[i];col[i]=$i};print ""}')
    cpu_stat=$(grep "cpu\s" "$logdir/proc_stat.log" | tr -s ' ' | cut -d ' ' -f 2- | sed -n '1p;$p' | awk 'NR==1{for(i=1;i<=NF;i++){col[i]=$i};next}{for(i=1;i<=NF;i++){printf "%s ",$i-col[i];col[i]=$i};print ""}')

    if_rx_b=$(echo $if_stat | cut -d ' ' -f 1)
    if_rx_pkt=$(echo $if_stat | cut -d ' ' -f 2)
    if_rx_err=$(echo $if_stat | cut -d ' ' -f 3)
    if_rx_drop=$(echo $if_stat | cut -d ' ' -f 4)
    if_rx_fifo=$(echo $if_stat | cut -d ' ' -f 5)
    if_rx_frame=$(echo $if_stat | cut -d ' ' -f 6)
    if_tx_b=$(echo $if_stat | cut -d ' ' -f 9)
    if_tx_pkt=$(echo $if_stat | cut -d ' ' -f 10)
    if_tx_err=$(echo $if_stat | cut -d ' ' -f 11)
    if_tx_drop=$(echo $if_stat | cut -d ' ' -f 12)
    if_tx_fifo=$(echo $if_stat | cut -d ' ' -f 13)

    intr=$(echo $intr_stat | cut -d ' ' -f 1)

    cpu_idle=$(echo $cpu_stat | cut -d ' ' -f 4)
    cpu_total=$(echo $cpu_stat | tr " " "\n" | grep . | paste -sd+ - | bc)
    cpu_pct=$(echo "scale=4; ($cpu_total-$cpu_idle) * 100 / $cpu_total" | bc)

    echo $iperf_count, $rep, $elapsed, $if_rx_b, $if_rx_pkt, $if_rx_err, $if_rx_drop, $if_rx_fifo, $if_rx_frame, $if_tx_b, $if_tx_pkt, $if_tx_err, $if_tx_drop, $if_tx_fifo, $lcl_txkbps, $lcl_txretr, $lcl_rxkbps, $rmt_txkbps, $rmt_txretr, $rmt_rxkbps, $intr, $cpu_pct | tee -a "$base_logdir/$test_type.csv"
}

mkdir -p $base_logdir

echo "n, rep, sec, if_rx_b, if_rx_pkt, if_rx_err, if_rx_drop, if_rx_fifo, if_rx_frame, if_tx_b, if_tx_pkt, if_tx_err, if_tx_drop, if_tx_fifo, lcl_txkbps, lcl_txretr, lcl_rxkbps, rmt_txkbps, rmt_txretr, rmt_rxkbps, intr, cpu" > "$base_logdir/tx.csv"
echo "n, rep, sec, if_rx_b, if_rx_pkt, if_rx_err, if_rx_drop, if_rx_fifo, if_rx_frame, if_tx_b, if_tx_pkt, if_tx_err, if_tx_drop, if_tx_fifo, lcl_txkbps, lcl_txretr, lcl_rxkbps, rmt_txkbps, rmt_txretr, rmt_rxkbps, intr, cpu" > "$base_logdir/rx.csv"
echo "n, rep, sec, if_rx_b, if_rx_pkt, if_rx_err, if_rx_drop, if_rx_fifo, if_rx_frame, if_tx_b, if_tx_pkt, if_tx_err, if_tx_drop, if_tx_fifo, lcl_txkbps, lcl_txretr, lcl_rxkbps, rmt_txkbps, rmt_txretr, rmt_rxkbps, intr, cpu" > "$base_logdir/txrx.csv"

for iperf_count in $(seq 1 $max_iperf_count); do
    for rep in $(seq 1 $repeats); do
        echo "Running TX test with $iperf_count processes ($rep/$repeats)"
        run_meas tx $iperf_count $rep

        echo "Running RX test with $iperf_count processes ($rep/$repeats)"
        run_meas rx $iperf_count $rep

        echo "Running TX+RX test with $iperf_count processes ($rep/$repeats)"
        run_meas txrx $iperf_count $rep
    done
done
