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

echo "Disabling fatal error reporting on port $port..."

echo "Command:" $(setpci -s $port COMMAND)

# clear SERR bit in command register
setpci -s $port COMMAND=0000:0100

echo "Command:" $(setpci -s $port COMMAND)
 
echo "Device control:" $(setpci -s $port CAP_EXP+8.w)

# clear fatal error reporting enable bit in device control register
setpci -s $port CAP_EXP+8.w=0000:0004

echo "Device control:" $(setpci -s $port CAP_EXP+8.w)
