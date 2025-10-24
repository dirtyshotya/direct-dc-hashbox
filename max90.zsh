#!/bin/zsh
set -x
# Configuration paths
PYTHON_SCRIPT="/home/100acresranch/voltage.py"
MINERS_FILE="/home/100acresranch/miners.csv"
IP_FILE="/home/100acresranch/ip.csv"
MIN_FREQ_FILE="/home/100acresranch/minFreq90Th.csv"
MAX_FREQ_FILE="/home/100acresranch/maxHash90.csv"
CONFIG_STEP_FILE="/home/100acresranch/configStep80.csv"
FREQ_STEP_FILE="/home/100acresranch/freqStep80.csv"

# Voltage step constant
VOLTAGE_STEP_CONSTANT=0.1

# Read configuration values
MIN_FREQUENCY=$(< "$MIN_FREQ_FILE")
MAX_FREQUENCY=$(< "$MAX_FREQ_FILE")
FREQ_STEP=$(< "$CONFIG_STEP_FILE")
ASIC_FREQ_STEP=$(< "$FREQ_STEP_FILE")

echo "" > /home/100acresranch/voltage.csv

while true; do
    # Read the actual voltage from the Python script
    VOLTAGE=$(python3 "$PYTHON_SCRIPT")
    OFFSET=$(< "/home/100acresranch/offset.csv")
    VOLTAGE=$(echo "$VOLTAGE - $OFFSET" | bc -l)
    rounded_result=$(echo "scale=2; ($VOLTAGE / 0.1 + 0.5) / 1" | bc -l | cut -d '.' -f 1)
    rounded_result=$(echo "$rounded_result * 0.1" | bc -l)
    VOLTAGE=$rounded_result
    MINER_IP=$(< "$IP_FILE")

    # Calculate how many steps we can take given the current voltage, using the constant
    VOLTAGE_DIFFERENCE=$(echo "$VOLTAGE - 12.0" | bc -l)
    ALLOWED_STEPS=$(echo "scale=0; $VOLTAGE_DIFFERENCE / $VOLTAGE_STEP_CONSTANT" | bc)

    # Calculate the new frequency based on allowed steps without exceeding max frequency
    POTENTIAL_FREQUENCY=$(echo "$MIN_FREQUENCY + ($ALLOWED_STEPS * $FREQ_STEP)" | bc)

    # Ensure the calculated frequency does not exceed the max frequency
    if [ $POTENTIAL_FREQUENCY -gt $MAX_FREQUENCY ]; then
        FREQUENCY=$MAX_FREQUENCY
    elif [ $POTENTIAL_FREQUENCY -lt $MIN_FREQUENCY ]; then
        # Ensure frequency does not drop below minimum frequency
        FREQUENCY=$MIN_FREQUENCY
    else
        FREQUENCY=$POTENTIAL_FREQUENCY
    fi

    # Assuming this involves writing the frequency to the miners' config and possibly logging
    echo "Setting frequency to $FREQUENCY based on voltage $VOLTAGE"

    OLD_VOLTAGE=`cat /home/100acresranch/voltage.csv`
    if [[ $VOLTAGE == $OLD_VOLTAGE ]]; then
        continue
    fi

    # Session Management (Keep this part the same)
    current_session=$(echo '{"command": "session"}' | nc $MINER_IP 4028 | jq -r '.SESSION[0].SessionID')

    if [[ -z $current_session ]]; then
        session_id=$(echo '{"command": "logon"}' | nc $MINER_IP 4028 | jq -r '.SESSION[0].SessionID')
    else
        session_id=$current_session 
    fi

    # Iterate over boards 0, 1, and 2
    for board_id in 0 1 2; do
        # Construct the frequencyset command (chip_id omitted for all chips)
        frequencyset_command="{\"command\": \"frequencyset\", \"parameter\":\"${session_id},${board_id},${FREQUENCY},*,${ASIC_FREQ_STEP}\"}"

        # Send the command 
        echo $frequencyset_command | nc $MINER_IP 4028 | jq 
    done

    # Session Cleanup
    echo '{"command": "logoff", "parameter":"'"$session_id"'"}' | nc $MINER_IP 4028 > /dev/null 
    echo "$VOLTAGE" > /home/100acresranch/voltage.csv
    sleep 3 # Wait before next measurement
done

