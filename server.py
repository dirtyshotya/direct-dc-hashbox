import http.server
import socketserver
import urllib.parse as urlparse
import os
import subprocess

PORT = 8000
DIRECTORY = "/home/100acresranch"

class MyRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self.path = "index.html"
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

    def do_POST(self):
        if self.path == "/submit-settings":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode('utf-8')
            parsed_data = urlparse.parse_qs(post_data)

            settings = parsed_data.get('settings', [''])[0]
            max_frequency = parsed_data.get('maxFrequency', [''])[0]
            min_frequency = parsed_data.get('minFrequency', [''])[0]
            freq_step = parsed_data.get('freqStep', [''])[0]
            config_step = parsed_data.get('configStep', [''])[0]

            if settings == "BatteryCharge":
                write_to_file(os.path.join(DIRECTORY, "low_maxFreq.csv"), max_frequency)
                write_to_file(os.path.join(DIRECTORY, "low_minFreq.csv"), min_frequency)
                write_to_file(os.path.join(DIRECTORY, "low_freqStep.csv"), freq_step)
                write_to_file(os.path.join(DIRECTORY, "low_configStep.csv"), config_step)
            
            self.start_or_stop_scripts(settings)

            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Settings applied')

    def start_or_stop_scripts(self, settings):
        # Stop all running scripts
        subprocess.run(['pkill', '-f', 'lux.sh'])
        subprocess.run(['pkill', '-f', 'custom.sh'])

        # Start the appropriate script based on the settings
        if settings == 'Custom':
            subprocess.Popen(['/home/100acresranch/custom.sh'])
        else:
            subprocess.Popen(['/home/100acresranch/lux.sh'])

def write_to_file(filename, content):
    with open(filename, 'w') as f:
        f.write(content)

with socketserver.TCPServer(("", PORT), MyRequestHandler) as httpd:
    print("Serving at port", PORT)
    httpd.serve_forever()
