#!/bin/bash

dev=$1
en=$2

if [ -z "$dev" ]; then
    echo "Error: no device specified"
    exit 1
fi

if [ -z "$en" ]; then
    echo "Error: must specify operation"
    exit 1
fi

if [ ! -e "/sys/bus/pci/devices/$dev" ]; then
    dev="0000:$dev"
fi

if [ ! -e "/sys/bus/pci/devices/$dev" ]; then
    echo "Error: device $dev not found"
    exit 1
fi

echo "Device control:" $(setpci -s $dev CAP_EXP+8.w)

if (($en > 0)); then
    echo "Enabling ext tag on $dev..."
    setpci -s $dev CAP_EXP+8.w=0100:0100
else
    echo "Disabling ext tag on $dev..."
    setpci -s $dev CAP_EXP+8.w=0000:0100
fi

echo "Device control:" $(setpci -s $dev CAP_EXP+8.w)
