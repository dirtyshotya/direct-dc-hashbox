#!/bin/bash

CONFIG_FILE="/home/100acresranch/settings.conf"
LOGFILE="/home/100acresranch/apply_settings.log"

# Read settings from the configuration file
declare -A settings
while IFS='=' read -r key value; do
    settings[$key]=$value
done < "$CONFIG_FILE"

# Log and apply settings
echo "$(date '+%Y-%m-%d %H:%M:%S') - Applying settings" >> $LOGFILE
for i in {1..20}; do
    voltage_key="voltage_$i"
    frequency_key="frequency_$i"
    voltage=${settings[$voltage_key]}
    frequency=${settings[$frequency_key]}
    echo "Voltage $i: $voltage, Frequency $i: $frequency" >> $LOGFILE
    /home/100acresranch/custom.sh $voltage $frequency
done
