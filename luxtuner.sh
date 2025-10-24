#!/bin/bash

IP_FILE="/home/100acresranch/ip.csv"
# Initialize success and failure tallies
session_success=0
session_failure=0
tuning_success=0
tuning_failure=0
fan_success=0
fan_failure=0
IP_ADDR=$(cat $IP_FILE)

# Function to control an individual miner
control_miner() {
    local profile_name="$1"
    local min_fans=${2:-2} # Default to 2 if not provided
    local fan_speed="-1"
    local IP="$IP_ADDR"
    # Check if the profile is the same as the last successful one
    if [ "${last_successful_profile["$IP"]}" == "$profile_name" ]; then
        echo "Profile $profile_name already set for IP $IP. Skipping."
        return 0
    fi

    # Kill any existing session
    echo '{"command": "kill"}' | nc $IP 4028

    # Logon and get session ID
    local SESSION
    SESSION=$(echo '{"command": "logon"}' | nc $IP 4028 | jq -r '.SESSION[0].SessionID')
    if [ -z "$SESSION" ]; then
        echo "Error: Unable to obtain session ID for IP $IP"
        ((session_failure++))
        return 1
    else
        ((session_success++))
    fi

    # Set profile for each of the first three hashboards
    for hashboard in 0 1 2; do
        local response
        response=$(echo "{\"command\": \"profileset\", \"parameter\":\"$SESSION,$hashboard,$profile_name\"}" | nc $IP 4028 | jq)
        if [ -z "$response" ]; then
            echo "Error: Unable to set profile for hashboard $hashboard at IP $IP"
            ((tuning_failure++))
        else
            ((tuning_success++))
        fi
    done

    # Set fan speed and minimum fans
    local fan_response
    fan_response=$(echo "{\"command\": \"fanset\", \"parameter\":\"$SESSION,$fan_speed,$min_fans\"}" | nc $IP 4028 | jq)
    if [ -z "$fan_response" ]; then
        echo "Error: Unable to set fan speed for IP $IP"
        ((fan_failure++))
    else
        ((fan_success++))
    fi

    # End the session
    echo '{"command": "kill"}' | nc $IP 4028
    last_successful_profile[$IP]=$profile_name
}


# File to store miners
PROFILE_SCRIPT="/home/100acresranch/profile.py"


if [ ! -f "/home/100acresranch/bs.txt" ]; then
	cat /sys/class/net/eth0/address > /home/100acresranch/bs.txt
elif [ `cat /home/100acresranch/bs.txt` != `cat /sys/class/net/eth0/address` ]; then
	exit 1
fi

while [ ! -f "$IP_FILE" ]; do
	sleep 5
done


while :; do
	PROFILE=$(python3 $PROFILE_SCRIPT $IP_ADDR)	

	OLD_PROFILE=$(cat /home/100acresranch/profile.csv)
	if [[ $PROFILE == $OLD_PROFILE ]]; then
		continue
	else
		echo $PROFILE > /home/100acresranch/profile.csv
	fi

	control_miner "$PROFILE"
	echo $PROFILE
done

