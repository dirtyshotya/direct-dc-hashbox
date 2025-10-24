#!/bin/bash

# Path to your Python script that reads the voltage
PYTHON_SCRIPT="/home/100acresranch/voltage.py"

# Path to your Python script that handles form submissions
FORM_HANDLER_SCRIPT="/home/100acresranch/form_handler.py"

# Files to store miner and IP information
MINERS_FILE="/home/100acresranch/miners.csv"
IP_FILE="/home/100acresranch/ip.csv"
VOLTAGE_FILE="/home/100acresranch/voltage.csv"
BS_FILE="/home/100acresranch/bs.txt"

# Check if the unique identifier file exists
if [ ! -f "$BS_FILE" ]; then
    cat /sys/class/net/eth0/address > "$BS_FILE"
elif [ "$(cat $BS_FILE)" != "$(cat /sys/class/net/eth0/address)" ]; then
    exit 1
fi

# Wait until the IP file is available
while [ ! -f "$IP_FILE" ]; do
    sleep 5
done

# Read the IP address from the IP file
IP_ADDR=$(cat $IP_FILE)

# Check if miners file exists, if not, scan for miners
if [ ! -f "$MINERS_FILE" ]; then
    /home/100acresranch/luxminer-cli-linux-arm64 scan range $IP_ADDR $IP_ADDR -o $MINERS_FILE
    while [ "$(wc -l < $MINERS_FILE)" -ne 2 ]; do
        sleep 6
        IP_ADDR=$(cat $IP_FILE)
        /home/100acresranch/luxminer-cli-linux-arm64 scan range $IP_ADDR $IP_ADDR -o $MINERS_FILE
    done
fi

# Infinite loop to read voltage and adjust settings accordingly
while :; do
    # Read voltage from Python script
    VOLTAGE=$(python3 $PYTHON_SCRIPT)
    
    # Error handling if voltage reading fails
    if [ $? -ne 0 ]; then
        echo "Error reading voltage. Retrying..."
        sleep 5
        continue
    fi

    # Determine the frequency based on the voltage to maintain 13.6V - 13.8V
    if (( $(echo "$VOLTAGE > 13.8" | bc -l) )); then
        # Voltage too high, reduce frequency
        if (( $(echo "$VOLTAGE <= 14.0" | bc -l) )); then
            FREQUENCY=675
        else
            FREQUENCY=650
        fi
    elif (( $(echo "$VOLTAGE < 13.6" | bc -l) )); then
        # Voltage too low, increase frequency
        if (( $(echo "$VOLTAGE >= 13.4" | bc -l) )); then
            FREQUENCY=625
        else
            FREQUENCY=600
        fi
    else
        # Voltage is within the desired range, set to optimal frequency
        FREQUENCY=675
        VOLTAGE=13.7
    fi

    OLD_VOLTAGE=$(cat $VOLTAGE_FILE)
    if [[ $VOLTAGE == $OLD_VOLTAGE ]]; then
        continue
    fi

    # Read current configuration
    /home/100acresranch/luxminer-cli-linux-arm64 config read -i $MINERS_FILE -o /home/100acresranch/miners_new.csv > /dev/null
    
    head -n 1 /home/100acresranch/miners_new.csv > /home/100acresranch/miners_updated.csv

    # Update the CSV file to set the desired voltage and frequency
    linept1=$(grep ',luxos,' /home/100acresranch/miners_new.csv | cut -d ',' -f 1-5)
    linept2=$(grep ',luxos,' /home/100acresranch/miners_new.csv | cut -d ',' -f 8-)
    echo -e "$linept1,$VOLTAGE,$FREQUENCY,$linept2" >> /home/100acresranch/miners_updated.csv

    # Update the miners with the new voltage and frequency settings
    /home/100acresranch/luxminer-cli-linux-arm64 config write voltage frequency -i /home/100acresranch/miners_updated.csv --yes > /dev/null

    echo $VOLTAGE > $VOLTAGE_FILE
    sleep 3
done
