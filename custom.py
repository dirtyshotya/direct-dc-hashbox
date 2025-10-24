from flask import Flask, request, render_template_string, jsonify
from flask_cors import CORS
import subprocess
import logging
import csv

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# HTML form with 20 voltage-frequency pairs
html_form = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Settings</title>
</head>
<body>
    <form action="/api/update-settings" method="POST">
        {% for i in range(1, 21) %}
        <label for="voltage_{{i}}">Voltage {{14.2 - 0.1*(i-1)}}:</label>
        <input type="text" id="voltage_{{i}}" name="voltage_{{i}}" value="{{voltage_settings[i-1]}}" readonly>
        <label for="frequency_{{i}}">Frequency:</label>
        <input type="text" id="frequency_{{i}}" name="frequency_{{i}}" value="{{frequency_settings[i-1]}}"><br><br>
        {% endfor %}
        <button type="submit">Update</button>
    </form>
</body>
</html>
'''

def load_settings():
    settings = {}
    try:
        with open('/home/100acresranch/settings.conf', 'r') as f:
            for line in f:
                key, value = line.strip().split('=')
                settings[key] = value
    except FileNotFoundError:
        # Initialize default values if the settings file does not exist
        for i in range(1, 21):
            settings[f"voltage_{i}"] = str(14.2 - 0.1 * (i - 1))
            settings[f"frequency_{i}"] = ""
    return settings

@app.route('/')
def index():
    settings = load_settings()
    voltage_settings = [settings.get(f"voltage_{i}", "") for i in range(1, 21)]
    frequency_settings = [settings.get(f"frequency_{i}", "") for i in range(1, 21)]
    return render_template_string(html_form, voltage_settings=voltage_settings, frequency_settings=frequency_settings)

@app.route('/api/update-settings', methods=['POST'])
def update_settings():
    settings = {}
    voltage_frequency_pairs = []

    for i in range(1, 21):
        voltage_key = f"voltage_{i}"
        frequency_key = f"frequency_{i}"
        settings[voltage_key] = request.form[voltage_key]
        settings[frequency_key] = request.form[frequency_key]
        voltage_frequency_pairs.append([settings[voltage_key], settings[frequency_key]])

    # Write the settings to a configuration file
    with open('/home/100acresranch/settings.conf', 'w') as f:
        for key, value in settings.items():
            f.write(f"{key}={value}\n")

    # Write the voltage-frequency pairs to a CSV file
    with open('/home/100acresranch/voltage_frequency_pairs.csv', 'w', newline='') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerow(['Voltage', 'Frequency'])
        csvwriter.writerows(voltage_frequency_pairs)

    logging.info("Settings updated successfully")
    return jsonify({"message": "Settings updated successfully!"})

@app.route('/api/run-custom-script', methods=['POST'])
def run_custom_script():
    try:
        # Run the custom.sh script
        subprocess.run(["/home/100acresranch/custom.sh"], check=True)
        logging.info("Custom script executed successfully")
        return jsonify({"message": "Custom script executed successfully!"})
    except subprocess.CalledProcessError as e:
        logging.error(f"Error executing custom script: {e}")
        return jsonify({"error": "Error executing custom script"}), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5002)
