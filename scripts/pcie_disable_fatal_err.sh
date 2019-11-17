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

cmd=$(setpci -s $port COMMAND)

echo "Command:" $cmd

# clear SERR bit in command register
setpci -s $port COMMAND=$(printf "%04x" $((0x$cmd & ~0x0100)))

ctrl=$(setpci -s $port CAP_EXP+8.w)
 
echo "Device control:" $ctrl

# clear fatal error reporting enable bit in device control register
setpci -s $port CAP_EXP+8.w=$(printf "%04x" $((0x$ctrl & ~0x0004)))

