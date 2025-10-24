#!/bin/zsh
set -x
# Configuration paths
PYTHON_SCRIPT="/home/100acresranch/voltage.py"
MINERS_FILE="/home/100acresranch/miners.csv"
IP_FILE="/home/100acresranch/ip.csv"
VOLTAGE_FREQUENCY_FILE="/home/100acresranch/voltage_frequency_pairs.csv"
ASIC_FREQ_STEP=10  # Replace this with the actual value if it's defined elsewhere

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

    # Read the voltage-frequency pairs from the CSV file
    while IFS=, read -r voltage frequency; do
        if [[ $voltage == "Voltage" ]]; then
            continue
        fi
        if (( $(echo "$VOLTAGE >= $voltage" | bc -l) )); then
            closest_voltage=$voltage
            FREQUENCY=$frequency
            break
        fi
    done < "$VOLTAGE_FREQUENCY_FILE"

    # Assuming this involves writing the frequency to the miners' config and possibly logging
    echo "Setting frequency to $FREQUENCY based on voltage $VOLTAGE"

    OLD_VOLTAGE=$(cat /home/100acresranch/voltage.csv)
    if [[ $VOLTAGE == $OLD_VOLTAGE ]]; then
        sleep 3
        continue
    fi

    # Session Management
    current_session=$(echo '{"command": "session"}' | nc $MINER_IP 4028 | jq -r '.SESSION[0].SessionID')

    if [[ -z $current_session || $current_session == "null" ]]; then
        session_response=$(echo '{"command": "logon"}' | nc $MINER_IP 4028)
        session_id=$(echo "$session_response" | jq -r '.SESSION[0].SessionID')
        
        if [[ -z $session_id || $session_id == "null" ]]; then
            echo "Failed to log on and obtain a valid session ID"
            sleep 3
            continue
        fi
    else
        session_id=$current_session 
    fi

    # Debugging: Print the session ID
    echo "Session ID: $session_id"

    # Iterate over boards 0, 1, and 2
    for board_id in 0 1 2; do
        # Sanitize frequency value
        sanitized_frequency=$(echo "$FREQUENCY" | tr -d '\n\r\t')
        
        # Construct the frequencyset command using printf to avoid issues with special characters
        frequencyset_command=$(printf '{"command": "frequencyset", "parameter":"%s,%d,%s,*,%s"}' "$session_id" "$board_id" "$sanitized_frequency" "$ASIC_FREQ_STEP")
        
        # Debugging: Print the command before sending
        echo "Sending command to board $board_id: $frequencyset_command"

        # Send the command 
        response=$(echo $frequencyset_command | nc $MINER_IP 4028 | jq)
        echo "Response for board $board_id: $response"
        
        if [[ $(echo "$response" | jq -r '.STATUS[0].STATUS') == "E" ]]; then
            echo "Error sending frequencyset command to board $board_id: $(echo "$response" | jq -r '.STATUS[0].Msg')"
            continue
        fi
    done

    # Session Cleanup
    echo '{"command": "logoff", "parameter":"'"$session_id"'"}' | nc $MINER_IP 4028 > /dev/null 

    echo "$VOLTAGE" > /home/100acresranch/voltage.csv

    sleep 3 # Wait before next measurement
done
