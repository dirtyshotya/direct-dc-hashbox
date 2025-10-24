import json
import subprocess
import sys

def get_profiles(ip):
    command = f"echo '{{\"command\": \"profiles\"}}' | nc {ip} 4028 | jq"
    try:
        result = subprocess.run(command, capture_output=True, shell=True, text=True, timeout=10)  # Add timeout here
    except subprocess.TimeoutExpired:
        print("Error: Command timed out while fetching profiles")
        sys.exit(1)
    if result.returncode != 0:
        print("Error fetching profiles:", result.stderr)
        sys.exit(1)
    return json.loads(result.stdout)

def sort_profiles_by_voltage(profiles):
    return sorted(profiles, key=lambda x: x['Voltage'])

def find_closest_lower_voltage_profile(current_voltage, profiles):
    eligible_profiles = [profile for profile in profiles if profile['Voltage'] < current_voltage]
    eligible_profiles_sorted = sorted(eligible_profiles, key=lambda x: x['Voltage'], reverse=True)
    return eligible_profiles_sorted[0] if eligible_profiles_sorted else None

def get_voltage():
    with open('/home/100acresranch/offset.csv', 'r') as file:
        line = file.readline()
        offset = float(line.strip())
    
    result = subprocess.run(["python3", "/home/100acresranch/voltage.py"], capture_output=True, text=True)
    if result.returncode != 0:
        print("Error executing voltage.py:", result.stderr)
        sys.exit(1)

    return float(result.stdout.strip()) - offset

def main():
    if len(sys.argv) < 2:
        print("Usage: python profile.py <IP_ADDRESS>")
        sys.exit(1)

    ip_address = sys.argv[1]
    profiles_data = get_profiles(ip_address)
    
    profiles = profiles_data["PROFILES"]

    current_voltage = get_voltage()
    
    closest_profile = find_closest_lower_voltage_profile(current_voltage, profiles)
    
    if closest_profile:
        print(f"{closest_profile['Profile Name']}")
    else:
        print("error")

if __name__ == "__main__":
    main()
