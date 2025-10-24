#!/usr/bin/env zsh

# Configuration
api_key="100acresranch100acresranch100acr"
api_url_get_profiles="http://192.168.12.121/api/v1/autotune/presets"
presets_file="vnishpresets"

# Check if the file exists; create it if not
if [[ ! -f "$presets_file" ]]; then
    echo "INFO: File $presets_file does not exist. Creating it..."
    touch "$presets_file"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to create file $presets_file. Check permissions."
        exit 1
    fi
fi

# Fetch presets from API
echo "INFO: Fetching presets from API..."
curl -L -s -X 'GET' \
    "$api_url_get_profiles" \
    -H 'accept: application/json' \
    -H "x-api-key: $api_key" -o "$presets_file.tmp"

# Check if the temporary file was created
if [[ ! -f "$presets_file.tmp" ]]; then
    echo "ERROR: Failed to fetch presets. Temporary file $presets_file.tmp not created."
    exit 1
fi

# Validate JSON response
echo "INFO: Validating JSON response..."
if ! jq empty "$presets_file.tmp" 2>/dev/null; then
    echo "ERROR: Invalid JSON response. Aborting."
    rm -f "$presets_file.tmp"
    exit 1
fi

# Save the valid presets to the file
echo "INFO: Saving presets to $presets_file..."
mv "$presets_file.tmp" "$presets_file"
if [[ $? -ne 0 ]]; then
    echo "ERROR: Unable to save presets to $presets_file. Check permissions."
    exit 1
fi

# Display the saved presets
echo "INFO: Saved presets content:"
cat "$presets_file"
