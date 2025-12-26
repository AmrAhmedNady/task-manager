const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.static(path.join(__dirname, 'public'))); 

// Default stats to prevent crashes
const defaultStats = { 
    cpu: { usage: 0, name: "Waiting for Spy..." },
    ram: { usage: 0, total: "0 GB" },
    disks: [],
    gpus: [],
    network: { usage: 0, name: "Network" }
};

app.get('/api/stats', (req, res) => {
    const filePath = path.join(__dirname, 'data', 'stats.json');

    fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
            console.error("Error reading stats.json:", err.message);
            return res.json(defaultStats);
        }
        
        try {
            // Remove BOM and whitespace
            const cleanData = data.replace(/^\uFEFF/, '').trim();
            if (!cleanData) return res.json(defaultStats);
            res.json(JSON.parse(cleanData));
        } catch (e) {
            console.error("JSON Parse Error:", e.message);
            res.json(defaultStats);
        }
    });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});