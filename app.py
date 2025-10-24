from flask import Flask, render_template, request, jsonify
import logging
import subprocess

app = Flask(__name__)

# Setup logging
logging.basicConfig(filename='/home/100acresranch/debug.log', level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s %(message)s')

# Example settings for initial profiles
SETTINGS = {
    "Efficiency": {
        "maxFrequency": "None",
        "minFrequency": "None",
        "freqStep": "None",
        "configStep": "None"
    },
    "BatteryCharge": {
        "maxFrequency": "None",
        "minFrequency": "None",
        "freqStep": "None",
        "configStep": "None"
    },
    "70": {
        "maxFrequency": "70",
        "minFrequency": "60",
        "freqStep": "1",
        "configStep": "10"
    },
    "80": {
        "maxFrequency": "80",
        "minFrequency": "70",
        "freqStep": "1",
        "configStep": "10"
    },
    "90": {
        "maxFrequency": "90",
        "minFrequency": "80",
        "freqStep": "1",
        "configStep": "10"
    },
    "100": {
        "maxFrequency": "100",
        "minFrequency": "90",
        "freqStep": "1",
        "configStep": "10"
    },
    "Custom": {}
}

FILE_PATHS = {
    "Efficiency": {
        "maxFrequency": "/home/100acresranch/efficiency_maxFreq.csv",
        "minFrequency": "/home/100acresranch/efficiency_minFreq.csv",
        "freqStep": "/home/100acresranch/efficiency_freqStep.csv",
        "configStep": "/home/100acresranch/efficiency_configStep.csv"
    },
    "BatteryCharge": {
        "maxFrequency": "/home/100acresranch/low_maxFreq.csv",
        "minFrequency": "/home/100acresranch/low_minFreq.csv",
        "freqStep": "/home/100acresranch/low_freqStep.csv",
        "configStep": "/home/100acresranch/low_configStep.csv"
    },
    "70": {
        "maxFrequency": "/home/100acresranch/maxhash70_maxFreq.csv",
        "minFrequency": "/home/100acresranch/maxhash70_minFreq.csv",
        "freqStep": "/home/100acresranch/maxhash70_freqStep.csv",
        "configStep": "/home/100acresranch/maxhash70_configStep.csv"
    },
    "80": {
        "maxFrequency": "/home/100acresranch/maxhash80_maxFreq.csv",
        "minFrequency": "/home/100acresranch/maxhash80_minFreq.csv",
        "freqStep": "/home/100acresranch/maxhash80_freqStep.csv",
        "configStep": "/home/100acresranch/maxhash80_configStep.csv"
    },
    "90": {
        "maxFrequency": "/home/100acresranch/maxhash90_maxFreq.csv",
        "minFrequency": "/home/100acresranch/maxhash90_minFreq.csv",
        "freqStep": "/home/100acresranch/maxhash90_freqStep.csv",
        "configStep": "/home/100acresranch/maxhash90_configStep.csv"
    },
    "100": {
        "maxFrequency": "/home/100acresranch/maxhash100_maxFreq.csv",
        "minFrequency": "/home/100acresranch/maxhash100_minFreq.csv",
        "freqStep": "/home/100acresranch/maxhash100_freqStep.csv",
        "configStep": "/home/100acresranch/maxhash100_configStep.csv"
    },
    "Custom": {}
}

# Store the process ID of the running custom script
custom_script_process = None

@app.route('/')
def index():
    app.logger.info('Rendering index page.')
    return render_template('index.html')

@app.route('/load-settings/<setting>', methods=['GET'])
def load_settings(setting):
    setting = setting.replace("MaxHash", "")
    if setting in SETTINGS:
        app.logger.info(f'Loading settings for {setting}')
        return jsonify(SETTINGS[setting])
    else:
        app.logger.error(f'Invalid setting requested: {setting}')
        return jsonify({"error": "Invalid setting"}), 400

@app.route('/tuner', methods=['POST'])
def tuner():
    global custom_script_process

    setting = request.form.get('settings')
    max_frequency = request.form.get('maxFrequency')
    min_frequency = request.form.get('minFrequency')
    freq_step = request.form.get('freqStep')
    config_step = request.form.get('configStep')

    app.logger.info(f"Received settings: {setting}")
    app.logger.info(f"Form data: maxFrequency={max_frequency}, minFrequency={min_frequency}, freqStep={freq_step}, configStep={config_step}")

    if setting == "Custom":
        if custom_script_process is not None:
            app.logger.info("Custom script is already running.")
            return jsonify({"message": "Custom script is already running"}), 200

        custom_script_path = "home/100acresranch/custom.sh"  # Ensure this is the correct path
        custom_script_process = subprocess.Popen([custom_script_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        app.logger.info("Custom script started.")
        return jsonify({"message": "Custom settings applied"}), 200
    else:
        if custom_script_process is not None:
            custom_script_process.terminate()
            custom_script_process.wait()
            custom_script_process = None
            app.logger.info("Custom script stopped.")

        if not setting or not max_frequency or not min_frequency or not freq_step or not config_step:
            app.logger.error("Missing required form data")
            return jsonify({"error": "Missing required form data"}), 400

        app.logger.info(f"Max: {max_frequency}, Min: {min_frequency}, Freq Step: {freq_step}, Config Step: {config_step}")

        if setting in SETTINGS:
            SETTINGS[setting] = {
                "maxFrequency": max_frequency,
                "minFrequency": min_frequency,
                "freqStep": freq_step,
                "configStep": config_step
            }
            if setting in FILE_PATHS:
                write_to_file(FILE_PATHS[setting]['maxFrequency'], max_frequency)
                write_to_file(FILE_PATHS[setting]['minFrequency'], min_frequency)
                write_to_file(FILE_PATHS[setting]['freqStep'], freq_step)
                write_to_file(FILE_PATHS[setting]['configStep'], config_step)
            app.logger.info(f"Settings saved for {setting}")
            return jsonify({"message": "Settings applied"}), 200
        else:
            app.logger.error(f"Invalid setting: {setting}")
            return jsonify({"error": "Invalid setting"}), 400

def write_to_file(filename, content):
    with open(filename, 'w') as f:
        f.write(content)
        app.logger.info(f"Written to {filename}: {content}")

@app.route('/update', methods=['GET'])
def update():
    # Placeholder for update logic
    app.logger.info('Update called.')
    return "Update completed", 200

@app.route('/voltage', methods=['GET'])
def voltage():
    # Placeholder for voltage iframe content
    app.logger.info('Voltage info requested.')
    return "Voltage info"

if __name__ == '__main__':
    app.run(debug=True)
