#!/usr/bin/env zsh

# Configuration
api_key="100acresranch100acresranch100acr"
voltage_file="/home/100acresranch/house/voltage.csv"
profiles_json="/home/100acresranch/house/house21profiles.json"
ip_file="/home/100acresranch/ip.csv"

# Target voltage
target_voltage=13.8

# Initialize old_profile with a value that won't match any real profile value
old_profile=-1

# Main loop
while true; do
    # Load the IP address from ip.csv
    if [[ -f "$ip_file" ]]; then
        ip_address=$(awk -F, '{print $1}' "$ip_file" | tail -n 1)
    else
        echo "ERROR: IP file $ip_file not found. Retrying..."
        sleep 10
        continue
    fi

    echo "INFO: Target IP address: $ip_address"

    # Construct API URLs dynamically
    api_url_get_profiles="http://${ip_address}/api/v1/autotune/presets"
    api_url_set_profile="http://${ip_address}/api/v1/settings"

    # Load the current voltage
    if [[ -f "$voltage_file" ]]; then
        voltage=$(awk -F, '{print $NF}' "$voltage_file" | tail -n 1)
    else
        echo "ERROR: Voltage file $voltage_file not found. Retrying..."
        sleep 10
        continue
    fi

    echo "INFO: Current voltage: $voltage"

    # Fetch presets
    echo "INFO: Fetching profiles from API..."
    curl -L -s -X 'GET' \
        "$api_url_get_profiles" \
        -H 'accept: application/json' \
        -H "x-api-key: $api_key" > "$profiles_json"

    # Parse and sort profiles by name assuming the names are numeric
    profiles_sorted=($(jq -r '[.[] | select(.name | test("^[0-9]+"))] | sort_by(.name | tonumber) | .[].name' "$profiles_json"))

    if [[ -z "${profiles_sorted[*]}" ]]; then
        echo "ERROR: No valid profiles found. Retrying..."
        sleep 10
        continue
    fi

    # Select profile based on voltage
    if (( $(echo "$voltage < $target_voltage" | bc -l) )); then
        current_profile="${profiles_sorted[1]}"  # Choose the lowest profile
        echo "INFO: Voltage is below $target_voltage. Selecting lowest profile: $current_profile"
    else
        current_profile="${profiles_sorted[-1]}"  # Choose the highest profile
        echo "INFO: Voltage is above $target_voltage. Selecting highest profile: $current_profile"
    fi

    # Apply the profile if it has changed
    if [[ "$old_profile" != "$current_profile" && -n "$current_profile" ]]; then
        echo "INFO: Changing profile to $current_profile."
        response=$(curl -L -s -X 'POST' \
            "$api_url_set_profile" \
            -H 'accept: application/json' \
            -H "x-api-key: $api_key" \
            -H 'Content-Type: application/json' \
            -d "$(jq -n --arg preset "$current_profile" '{"miner": {"overclock": {"modded_psu": false, "preset": $preset}}}')")

        echo "DEBUG: API response: $response"
        old_profile="$current_profile"
    else
        echo "INFO: Profile remains at $current_profile; no change required."
    fi

    sleep 10  # Short delay before the next iteration
done
