const express = require('express');
const fs = require('fs');
const path = require('path');
const bodyParser = require('body-parser');
const { exec } = require('child_process');

const app = express();
const port = 3000;

// Middleware
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('/home/100acresranch'));

// Frequency file mappings
const frequencyFiles = {
  'MaxHash70': '/home/100acresranch/maxHash70.csv',
  'MaxHash80': '/home/100acresranch/maxHash80.csv',
  'MaxHash90': '/home/100acresranch/maxHash90.csv',
  'MaxHash100': '/home/100acresranch/maxHash100.csv',
  'Duration': '/home/100acresranch/duration.csv',
};

// Voltage settings file path
const voltageSettingsPath = '/home/100acresranch/voltage_settings.json';

// POST endpoint for auto voltage settings
app.post('/set-voltage-thresholds', (req, res) => {
  const { voltageOn, voltageOff } = req.body;

  if (
    typeof voltageOn !== 'number' ||
    typeof voltageOff !== 'number' ||
    voltageOn <= 0 ||
    voltageOff <= 0 ||
    voltageOff >= voltageOn
  ) {
    return res.status(400).json({ message: 'Invalid voltage thresholds' });
  }

  const voltageSettings = { voltageOn, voltageOff };

  fs.writeFile(voltageSettingsPath, JSON.stringify(voltageSettings, null, 2), 'utf8', (err) => {
    if (err) {
      console.error('Error saving voltage thresholds:', err);
      return res.status(500).json({ message: 'Failed to save voltage thresholds' });
    }
    res.json({ message: 'Voltage thresholds saved successfully' });
  });
});

// GET endpoint to fetch current voltage thresholds
app.get('/get-voltage-thresholds', (req, res) => {
  fs.readFile(voltageSettingsPath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).json({ message: 'Error reading voltage thresholds' });
    }
    try {
      const settings = JSON.parse(data);
      res.json(settings);
    } catch (parseError) {
      console.error('Error parsing voltage thresholds:', parseError);
      res.status(500).json({ message: 'Error parsing voltage thresholds' });
    }
  });
});

// GET endpoint for default frequency
app.get('/get-default-frequency/:selection', (req, res) => {
  const selection = req.params.selection;
  const filePath = frequencyFiles[selection];

  if (!filePath) {
    return res.status(404).json({ error: 'Selection not found' });
  }

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).json({ error: 'Error fetching default frequency' });
    }
    res.json({ frequency: data.trim() });
  });
});

// Voltage display endpoint
app.get('/voltage', (req, res) => {
  const multiplierFilePath = '/home/100acresranch/house/multiplier.csv';
  const voltageFilePath = '/home/100acresranch/house/voltage.csv';

  fs.readFile(multiplierFilePath, 'utf8', (err, multiplierData) => {
    if (err) {
      return res.status(500).send('Error reading multiplier file');
    }

    const multiplier = parseFloat(multiplierData.trim());
    if (isNaN(multiplier)) {
      return res.status(500).send('Invalid multiplier value');
    }

    fs.readFile(voltageFilePath, 'utf8', (err, voltageData) => {
      if (err) {
        return res.status(500).send('Error reading voltage file');
      }

      const lines = voltageData.trim().split('\n');
      const lastLine = lines[lines.length - 1];

      const voltageValue = parseFloat(lastLine);
      if (isNaN(voltageValue)) {
        return res.status(500).send('Invalid voltage data');
      }

      const voltage = (voltageValue * multiplier).toFixed(3);

      const htmlContent = `
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>Voltage Display</title>
          <style>
            body, html {
              height: 100%;
              margin: 0;
              display: flex;
              justify-content: center;
              align-items: center;
              background-color: transparent;
              text-shadow: 0 0 5px magenta, 0 0 10px magenta, 0 0 15px magenta;
            }
            .voltage-display {
              width: 200px;
              height: 200px;
              display: flex;
              justify-content: center;
              align-items: center;
              text-align: center;
              font-size: 1.5rem;
              color: neon-green;
              background: linear-gradient(to right, rgba(0, 0, 0, 0.7) 50%, transparent 50%);
              background-size: 200% 100%;
              border-radius: 50%;
              box-shadow: 0 0 10px magenta, 0 0 20px magenta, 0 0 30px magenta;
              animation: glow 2s infinite alternate;
            }
            @keyframes glow {
              0% { box-shadow: 0 0 5px magenta, 0 0 10px magenta, 0 0 15px magenta; }
              100% { box-shadow: 0 0 15px magenta, 0 0 30px magenta, 0 0 45px magenta; }
            }
          </style>
        </head>
        <body>
          <div class="voltage-display">
            <h1>${voltage}V</h1>
          </div>
        </body>
        </html>
      `;
      res.send(htmlContent);
    });
  });
});

// POST endpoint to control relay and manage service
app.post('/set-relay', (req, res) => {
  const { state } = req.body; // Expect "on", "off", or "auto"

  if (state === 'on' || state === 'off') {
    // Stop the auto service for manual commands
    exec('sudo systemctl stop relay_control.service', (error, stdout, stderr) => {
      if (error) {
        console.error(`Error stopping auto service: ${stderr}`);
        return res.status(500).json({ message: 'Failed to stop auto service' });
      }

      // Run the manual relay command
      const command = `sudo python3 /home/100acresranch/relay_control.py ${state}`;
      exec(command, (error, stdout, stderr) => {
        if (error) {
          console.error(`Error executing relay command: ${stderr}`);
          return res.status(500).json({ message: `Failed to set relay state to ${state}` });
        }
        res.json({ message: `Relay state set to: ${state}` });
      });
    });
  } else if (state === 'auto') {
    // Start the auto service for automatic control
    exec('sudo systemctl start relay_control.service', (error, stdout, stderr) => {
      if (error) {
        console.error(`Error starting auto service: ${stderr}`);
        return res.status(500).json({ message: 'Failed to start auto mode' });
      }
      res.json({ message: 'Auto mode started successfully' });
    });
  } else {
    res.status(400).json({ message: 'Invalid relay state' });
  }
});

// WiFi Configuration Endpoint
app.post('/wificonfig', (req, res) => {
  const wifiName = req.body.wifi_name;
  const wifiPassword = req.body.wifi_password;

  if (!wifiName.match(/^[a-zA-Z0-9_\-]+$/) || !wifiPassword.match(/^[a-zA-Z0-9_\-]+$/)) {
    return res.status(400).send('Invalid characters in WiFi name or password.');
  }

  const command = `sudo nmcli device wifi connect "${wifiName}" password "${wifiPassword}"`;

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error configuring WiFi: ${stderr}`);
      return res.status(500).send('Error configuring WiFi.');
    }
    res.send('WiFi configured successfully.');
  });
});

// Offset Configuration Endpoint
app.post('/offset', (req, res) => {
  const offsetValue = req.body.offsetValue;
  fs.writeFile(path.join(__dirname, 'offset.csv'), offsetValue, (err) => {
    if (err) {
      console.error('Failed to save offset value:', err);
      return res.status(500).send('Error saving offset value.');
    }
    res.send('Offset value saved successfully.');
  });
});

// Miner IP Submission Endpoint
app.post('/submit-ip', (req, res) => {
  const ip = req.body.ip;
  fs.writeFile(path.join(__dirname, 'ip.csv'), ip, (err) => {
    if (err) {
      console.error('Failed to save IP address:', err);
      return res.status(500).send('Error saving IP address.');
    }
    res.send('IP address saved successfully.');
  });
});

// Tuner Configuration Endpoint
app.post('/tuner', (req, res) => {
  const { settings, maxFrequency, minFrequency, freqStep, configStep } = req.body;

  if (!settings) {
    return res.status(400).send('Settings not provided');
  }

  const basePath = '/home/100acresranch/';
  const fileSuffix = settings === 'Duration' ? 'duration' : settings.replace('MaxHash', '');

  const paths = {
    maxFreqFile: `${basePath}maxHash${fileSuffix}.csv`,
    minFreqFile: `${basePath}minFreq${fileSuffix}Th.csv`,
    freqStepFile: `${basePath}freqStep${fileSuffix}.csv`,
    configStepFile: `${basePath}configStep${fileSuffix}.csv`,
  };

  const writeToFile = (filePath, data) => {
    return new Promise((resolve, reject) => {
      if (data === undefined) {
        resolve();
      } else {
        fs.writeFile(filePath, data, 'utf8', err => {
          if (err) reject(err);
          else resolve();
        });
      }
    });
  };

  Promise.all([
    writeToFile(paths.maxFreqFile, maxFrequency),
    writeToFile(paths.minFreqFile, minFrequency),
    writeToFile(paths.freqStepFile, freqStep),
    writeToFile(paths.configStepFile, configStep),
  ])
    .then(() => res.send('Tuner settings updated successfully'))
    .catch(err => res.status(500).send('Failed.'));
});

// Start the server
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
