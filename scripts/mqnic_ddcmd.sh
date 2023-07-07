#!/bin/sh

module=mqnic

#control=/sys/kernel/debug/dynamic_debug/control
control=/proc/dynamic_debug/control

if [ $# -eq 0 ]; then
	>&2 echo "Error: no argument provided"
	>&2 echo "usage: $0 [stmt]"
	>&2 echo "Disable all debug print statements: $0 =_"
	>&2 echo "Enable all debug print statements: $0 =p"
	>&2 echo "More verbose: $0 =pflmt"
	>&2 echo "Pattern match: $0 format \"some-string\" =p"
	>&2 echo "Current configuration:"
	grep "\[$module\]" $control >&2
	exit 1
fi

echo module $module "${@@Q}" > $control

