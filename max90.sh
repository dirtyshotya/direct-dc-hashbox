#!/bin/bash

# Path to your Python script that reads the voltage
PYTHON_SCRIPT="/home/100acresranch/voltage.py"

# File to store miners
MINERS_FILE="/home/100acresranch/miners.csv"

IP_FILE="/home/100acresranch/ip.csv"

if [ ! -f "/home/100acresranch/bs.txt" ]; then
	cat /sys/class/net/eth0/address > /home/100acresranch/bs.txt
elif [ `cat /home/100acresranch/bs.txt` != `cat /sys/class/net/eth0/address` ]; then
	exit 1
fi

while [ ! -f "$IP_FILE" ]; do
	sleep 5
done

IP_ADDR=`cat $IP_FILE`


# Check if miners file exists
if [ ! -f "$MINERS_FILE" ]; then
	# Scan the network for miners
	/home/100acresranch/luxminer-cli-linux-arm64 scan range $IP_ADDR $IP_ADDR -o $MINERS_FILE
	while [ `wc -l $MINERS_FILE | awk '{ print $1 }'` != 2 ]; do
		sleep 6
		IP_ADDR=`cat $IP_FILE`
		/home/100acresranch/luxminer-cli-linux-arm64 scan range $IP_ADDR $IP_ADDR -o $MINERS_FILE
	done
fi


while :; do
	# Read voltage from Python script
	VOLTAGE=$(python3 $PYTHON_SCRIPT)

	# Determine the frequency based on the voltage
	if (( $(echo "$VOLTAGE >= 14.2" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=14.2
	elif (( $(echo "$VOLTAGE >= 14.0" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=14.0
	elif (( $(echo "$VOLTAGE >= 13.8" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.8
	elif (( $(echo "$VOLTAGE >= 13.7" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.7
	elif (( $(echo "$VOLTAGE > 13.6" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.6
	elif (( $(echo "$VOLTAGE > 13.5" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.5
	elif (( $(echo "$VOLTAGE > 13.4" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.4
	elif (( $(echo "$VOLTAGE > 13.3" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.3
	elif (( $(echo "$VOLTAGE > 13.2" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.2
	elif (( $(echo "$VOLTAGE > 13.1" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.1
	elif (( $(echo "$VOLTAGE > 13.0" | bc -l) )); then
		FREQUENCY=475
		VOLTAGE=13.0
	elif (( $(echo "$VOLTAGE > 12.8" | bc -l) )); then
		FREQUENCY=450
		VOLTAGE=12.8
	elif (( $(echo "$VOLTAGE > 12.6" | bc -l) )); then
		FREQUENCY=425
		VOLTAGE=12.6
	elif (( $(echo "$VOLTAGE > 12.5" | bc -l) )); then
		FREQUENCY=400
		VOLTAGE=12.5
	elif (( $(echo "$VOLTAGE > 12.4" | bc -l) )); then
		FREQUENCY=375
		VOLTAGE=12.4
	elif (( $(echo "$VOLTAGE > 12.3" | bc -l) )); then
		FREQUENCY=350
		VOLTAGE=12.3
	elif (( $(echo "$VOLTAGE > 12.2" | bc -l) )); then
		FREQUENCY=325
		VOLTAGE=12.2
	elif (( $(echo "$VOLTAGE > 12.1" | bc -l) )); then
		FREQUENCY=300
		VOLTAGE=12.1
	elif (( $(echo "$VOLTAGE > 12.0" | bc -l) )); then
		FREQUENCY=275
		VOLTAGE=12.0
	else
		FREQUENCY=225
		VOLTAGE=11.9
	fi

	OLD_VOLTAGE=`cat /home/100acresranch/voltage.csv`
	if [[ $VOLTAGE == $OLD_VOLTAGE ]]; then
		continue
	fi
	# Read current configuration
	/home/100acresranch/luxminer-cli-linux-arm64 config read -i $MINERS_FILE -o /home/100acresranch/miners_new.csv > /dev/null
	
	head -n 1 /home/100acresranch/miners_new.csv > /home/100acresranch/miners_updated.csv
	# Update the CSV file to set the desired voltage and frequency
	linept1=`grep ',luxos,' /home/100acresranch/miners_new.csv | cut -d ',' -f 1-5`
	linept2=`grep ',luxos,' /home/100acresranch/miners_new.csv | cut -d ',' -f 8-`
	echo -e "$linept1,$VOLTAGE,$FREQUENCY,$linept2" >> /home/100acresranch/miners_updated.csv
	
	# Update the miners with the new voltage and frequency settings
	/home/100acresranch/luxminer-cli-linux-arm64 config write voltage frequency -i /home/100acresranch/miners_updated.csv --yes > /dev/null

	echo $VOLTAGE > /home/100acresranch/voltage.csv
	sleep 3
done
