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

netdev=
ifaddr=
netns=
base_logdir=./logs/

max_iperf_count=2
iperf_repeats=1
iperf_p=4
dest_ip=
iperf_base_port=9000
mtu=

utils_path=../utils/
mqnic_fw=$utils_path/mqnic-fw
mqnic_dump=$utils_path/mqnic-dump

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
        c) dest_ip=${OPTARG};;
        p) iperf_base_port=${OPTARG};;
        r) iperf_repeats=${OPTARG};;
    esac
done
shift $((OPTIND -1))

netns_cmd=

if [ ! -z "$netdev" ]; then
    if [ ! -z "$ifaddr" ]; then
        if [ -z "$netns" ]; then
            netns=$netdev
        fi
    fi
else
    echo "Interface name required" >&2
    exit -1
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

# run tests

nic_info=$($netns_cmd $mqnic_dump -d $netdev)

if [ $? -ne "0" ]; then
    echo "Failed to communicate with device" >2
    exit -1
fi

fpga_id=$(echo "$nic_info" | grep "FPGA ID" | sed -n 's/^.*: //p')
fpga_part=$(echo "$nic_info" | grep "FPGA part" | sed -n 's/^.*: //p')
fw_id=$(echo "$nic_info" | grep "FW ID" | sed -n 's/^.*: //p')
fw_ver=$(echo "$nic_info" | grep "FW version" | sed -n 's/^.*: //p')
board_id=$(echo "$nic_info" | grep "Board ID" | sed -n 's/^.*: //p')
board_ver=$(echo "$nic_info" | grep "Board version" | sed -n 's/^.*: //p')
build_date=$(echo "$nic_info" | grep "Build date" | sed -n 's/^.*: //p')
git_hash=$(echo "$nic_info" | grep "Git hash" | sed -n 's/^.*: //p')
release_info=$(echo "$nic_info" | grep "Release info" | sed -n 's/^.*: //p')

logname="$(date +%Y%m%dT%H%M%S)_${board_id}_fw${fw_ver}_${git_hash}"

logdir=$base_logdir/$logname

mkdir -p $logdir

echo "$nic_info" > $logdir/mqnic_dump.log

{

tests=()
declare -A test_desc
declare -A test_status
declare -A test_status_desc

link_ok=0

echo "Firmware information"
echo "FPGA ID: $fpga_id"
echo "FPGA part: $fpga_part"
echo "FW ID: $fw_id"
echo "FW version: $fw_ver"
echo "Board ID: $board_id"
echo "Board version: $board_ver"
echo "Build date: $build_date"
echo "Git hash: $git_hash"
echo "Release info: $release_info"

echo "PCIe information from lspci"
pci_id=$(basename $($netns_cmd readlink /sys/class/net/$netdev/device))
lspci -vvv -s $pci_id | tee $logdir/lspci.log 2>&1

echo "CPU information from lscpu"
lscpu | tee $logdir/lscpu.log 2>&1
cpu_model=$(cat /proc/cpuinfo | grep name | head -1 | cut -d: -f 2 | xargs)

echo "Link information from iproute2"
$netns_cmd ip link show dev $netdev | tee $logdir/iproute2_link.log 2>&1

echo "Network device information from ethtool"
$netns_cmd ethtool $netdev | tee $logdir/ethtool.log 2>&1

echo "Network device features from ethtool"
$netns_cmd ethtool -k $netdev | tee $logdir/ethtool_k.log 2>&1


tests+=("macaddr")
test_desc[macaddr]="Default MAC address"
test_status[macaddr]="PASS"
test_status_desc[macaddr]="OK"
echo "Current test: " ${test_desc[macaddr]}

mac=$($netns_cmd ip link show dev $netdev | grep link/ether | tr -s ' ' | cut -d' ' -f 3)

echo "Assigned MAC: $mac"

b=$(echo $mac | cut -d : -f 1)

if [ $((16#$b & 1)) -ne 0 ]; then
    echo "Invalid assigned MAC (broadcast bit set)"
    test_status[macaddr]="FAIL"
    test_status_desc[macaddr]="Invalid MAC"
fi

if [ $((16#$b & 2)) -ne 0 ]; then
    echo "Locally assigned MAC; persistent MAC addressing not working or EEPROM is blank"
    test_status[macaddr]="FAIL"
    test_status_desc[macaddr]="Local MAC"
fi

if [ "${test_status[macaddr]}" = "PASS" ]; then
    echo "MAC address OK"
fi


tests+=("mod_i2c")
test_desc[mod_i2c]="Module communication"
test_status[mod_i2c]="PASS"
test_status_desc[mod_i2c]="OK"
echo "Current test: ${test_desc[mod_i2c]}"

$netns_cmd ethtool -m $netdev | tee $logdir/ethtool_m.log 2>&1

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Failed to read module EEPROM"
    test_status[mod_i2c]="FAIL"
    test_status_desc[mod_i2c]="Failed to read EEPROM"
else
    echo "Successfully read module EEPROM"
fi


tests+=("ping")
test_desc[ping]="Ping"
test_status[ping]="PASS"
test_status_desc[ping]="OK"
echo "Current test: ${test_desc[ping]}"

$netns_cmd ping -c 4 -w 10 $dest_ip | tee $logdir/ping.log 2>&1

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Cannot communicate with test host"
    test_status[ping]="FAIL"
    test_status_desc[ping]="No response"
    link_ok=0
else
    echo "Communication with test host OK"
    link_ok=1
fi


if [ $link_ok -ne 0 ]; then
    echo "Link partner NIC MAC address from iproute2"
    $netns_cmd ip neigh show $dest_ip | tee $logdir/iproute2_neigh.log 2>&1
    remote_mac=$($netns_cmd ip neigh show $dest_ip | cut -d' ' -f 5)
fi


ptp4l_pid=0

if [ $link_ok -ne 0 ]; then
    echo "Start ptp4l"

    $netns_cmd ptp4l -i $netdev --slaveOnly=1 --tx_timestamp_timeout=10 -m > $logdir/ptp4l.log 2>&1 &
    ptp4l_pid=$!
fi


tests+=("ptp_sync1")
test_desc[ptp_sync1]="PTP sync at idle"
test_status[ptp_sync1]="PASS"
test_status_desc[ptp_sync1]="OK"
echo "Current test: ${test_desc[ptp_sync1]}"


if [ $link_ok -ne 0 ]; then

    echo "Wait for PTP to sync"
    tail -f $logdir/ptp4l.log &
    tail_pid=$!

    sleep 60

    kill $tail_pid

    ptp_status=$(cat $logdir/ptp4l.log | grep freq | grep rms | tail -1)

    echo $ptp_status

    ptp_offset_rms=$(echo "$ptp_status" | tr -s ' ' | cut -d ' ' -f 3)

    if [ ! -z "$ptp_offset_rms" ]; then
        echo "RMS offset: $ptp_offset_rms"

        if [ "$ptp_offset_rms" -lt 100 ]; then
            echo "PTP sync OK"
        else
            echo "PTP sync not sufficiently accurate"
            echo "Note: this may caused by other components in the network not properly supporting PTP"
            test_status[ptp_sync1]="FAIL"
            test_status_desc[ptp_sync1]="Inaccurate sync"
        fi
    else
        echo "PTP failed to sync"
        test_status[ptp_sync1]="FAIL"
        test_status_desc[ptp_sync1]="Did not sync"
    fi

else
    echo "Skipping test due to link issue"
    test_status[ptp_sync1]="SKIP"
    test_status_desc[ptp_sync1]="No link"
fi


tests+=("bandwidth")
test_desc[bandwidth]="Bandwidth"
test_status[bandwidth]="PASS"
test_status_desc[bandwidth]="OK"
echo "Current test: ${test_desc[bandwidth]}"


if [ $link_ok -ne 0 ]; then

    $netns_cmd ./iperf_benchmark.sh --logdir "$logdir/iperf" -c $dest_ip -P $iperf_p -n $max_iperf_count -r $iperf_repeats | tee $logdir/iperf_benchmark.log 2>&1

else
    echo "Skipping test due to link issue"
    test_status[bandwidth]="SKIP"
    test_status_desc[bandwidth]="No link"
fi


if [ $ptp4l_pid -ne 0 ]; then
    echo "Stop ptp4l"
    kill $ptp4l_pid
fi


tests+=("ptp_sync2")
test_desc[ptp_sync2]="PTP sync under load"
test_status[ptp_sync2]="PASS"
test_status_desc[ptp_sync2]="OK"
echo "Current test: ${test_desc[ptp_sync2]}"


if [ $link_ok -ne 0 ]; then

    ptp_status=$(cat $logdir/ptp4l.log | grep freq | grep rms | tail -1)

    echo $ptp_status

    ptp_offset_rms=$(echo "$ptp_status" | tr -s ' ' | cut -d ' ' -f 3)

    if [ ! -z "$ptp_offset_rms" ]; then
        echo "RMS offset: $ptp_offset_rms"

        if [ "$ptp_offset_rms" -lt 100 ]; then
            echo "PTP sync OK"
        else
            echo "PTP sync not sufficiently accurate"
            echo "Note: this may caused by other components in the network not properly supporting PTP"
            test_status[ptp_sync2]="FAIL"
            test_status_desc[ptp_sync2]="Inaccurate sync"
        fi
    else
        echo "PTP failed to sync"
        test_status[ptp_sync2]="FAIL"
        test_status_desc[ptp_sync2]="Did not sync"
    fi

else
    echo "Skipping test due to link issue"
    test_status[ptp_sync2]="SKIP"
    test_status_desc[ptp_sync2]="No link"
fi

echo

{

    echo "Test summary"
    echo
    echo "Date: $(date)"
    echo
    echo "Design information"
    echo
    echo "  FPGA ID: $fpga_id"
    echo "  FPGA part: $fpga_part"
    echo "  FW ID: $fw_id"
    echo "  FW version: $fw_ver"
    echo "  Board ID: $board_id"
    echo "  Board version: $board_ver"
    echo "  Build date: $build_date"
    echo "  Git hash: $git_hash"
    echo "  Release info: $release_info"
    echo
    echo "  PCI ID: $pci_id"
    echo "  MAC address: $mac"
    echo
    echo "Test setup"
    echo
    echo "  CPU: $cpu_model"
    echo "  Remote MAC address: $remote_mac"
    echo
    echo "Test results"
    echo

    overall="PASS"

    for test in "${tests[@]}"; do
        printf "  %-30s: %-4s (%s)\n" "${test_desc[$test]}" "${test_status[$test]}" "${test_status_desc[$test]}"

        if [ "${test_status[$test]}" = "FAIL" ]; then
            overall="FAIL"
        fi
    done

    echo
    echo "Overall result: $overall"
    echo

} | tee $logdir/summary.log 2>&1

echo "Done"

} | tee $logdir/test.log 2>&1
