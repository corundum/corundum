#!/bin/bash

watch -n 30 "./collect_utilization.py --csv output.csv --log output.log > /dev/null ; cat output.csv | column -s, -t -H 1 -T 3 -c 210"

