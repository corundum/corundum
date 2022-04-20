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

echo "Bridge control:" $(setpci -s $port BRIDGE_CONTROL)

setpci -s $port BRIDGE_CONTROL=40:40
sleep 0.5
setpci -s $port BRIDGE_CONTROL=00:40
sleep 0.5

echo "Rescanning bus..."

if [ -e "/sys/bus/pci/devices/$port/dev_rescan" ]; then
    echo 1 > "/sys/bus/pci/devices/$port/dev_rescan"
else
    echo 1 > "/sys/bus/pci/devices/$port/rescan"
fi


