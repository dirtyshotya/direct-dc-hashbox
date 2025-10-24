const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();
const port = 3001;

// Middleware to serve static files from the correct directory
const staticDir = '/home/100acresranch';
app.use(express.static(staticDir));

// Serve dynamic content at /voltage
app.get('/voltage', (req, res) => {
  const voltageFilePath = path.join(staticDir, 'voltage.txt');

  fs.readFile(voltageFilePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading voltage file:', err);
      res.status(500).json({ error: 'Error reading voltage data' });
      return;
    }

    try {
      const voltageData = JSON.parse(data);
      res.json(voltageData);
    } catch (parseError) {
      console.error('Error parsing voltage data:', parseError);
      res.status(500).json({ error: 'Error parsing voltage data' });
    }
  });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
