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

if [ ! -e "/sys/bus/pci/devices/$port" ]; then
    echo "Error: device $port not found"
    exit 1
fi

echo "Removing $dev..."

echo 1 > "/sys/bus/pci/devices/$dev/remove"

echo "Performing hot reset of port $port..."

bc=$(setpci -s $port BRIDGE_CONTROL)

echo "Bridge control:" $bc

setpci -s $port BRIDGE_CONTROL=$(printf "%04x" $((0x$bc | 0x40)))
sleep 0.01
setpci -s $port BRIDGE_CONTROL=$bc
sleep 0.5

echo "Rescanning bus..."

if [ -e "/sys/bus/pci/devices/$port/dev_rescan" ]; then
    echo 1 > "/sys/bus/pci/devices/$port/dev_rescan"
else
    echo 1 > "/sys/bus/pci/devices/$port/rescan"
fi


