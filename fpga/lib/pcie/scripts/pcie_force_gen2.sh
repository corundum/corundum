#!/bin/bash

dev=$1

if [ -z "$dev" ]; then
    echo "Error: no device specified"
    exit 1
fi

if [ ! -e "/sys/bus/pci/devices/$dev" ]; then
    dev="0000:$dev"
fi

if [ ! -e "/sys/bus/pci/devices/$dev" ]; then
    echo "Error: device $dev not found"
    exit 1
fi

port=$(basename $(dirname $(readlink "/sys/bus/pci/devices/$dev")))

if [[ $port != pci* ]]; then
    echo "Note: it may be necessary to run this on the corresponding upstream port"
    echo "Device $dev is connected to upstream port $port"
fi

echo "Configuring $dev..."

lc2=$(setpci -s $dev CAP_EXP+30.L)

echo "Original link control 2:" $lc2
echo "Original link target speed:" $(("0x$lc2" & 0xF))

lc2n=$(printf "%08x" $((("0x$lc2" & 0xFFFFFFF0) | 0x2)))

echo "New link control 2:" $lc2n

setpci -s $dev CAP_EXP+30.L=$lc2n

echo "Triggering link retraining..."

lc=$(setpci -s $dev CAP_EXP+10.L)

echo "Original link control:" $lc

lcn=$(printf "%08x" $(("0x$lc" | 0x20)))

echo "New link control:" $lcn

setpci -s $dev CAP_EXP+10.L=$lcn
