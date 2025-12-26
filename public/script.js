let history = {}; 
let selectedDevice = 'cpu';

const colors = { cpu: '#0078d4', ram: '#d233d2', disk: '#0f7b0f', gpu: '#d13438', network: '#dd3e78' };

function initHistory(key) { if (!history[key]) history[key] = new Array(60).fill(0); }

async function fetchStats() {
    try {
        const response = await fetch('data/stats.json?t=' + new Date().getTime());
        if (!response.ok) throw new Error("File not found");
        const data = await response.json();
        const get = (v, s='') => (v !== undefined && v !== null && v !== "") ? v + s : '--';

        const devices = [];
        
        // 1. CPU
        if (data.cpu) {
            // Alert Check
            const tempVal = parseInt(data.cpu.temp);
            const alertBox = document.getElementById('temp-alert');
            if (tempVal > 80) alertBox.classList.remove('hidden'); else alertBox.classList.add('hidden');

            devices.push({ 
                id: 'cpu', type: 'cpu', label: 'CPU', val: data.cpu.usage, sub: data.cpu.name,
                stats: [
                    { label: 'Base Speed', val: get(data.cpu.speed, ' GHz') },
                    { label: 'Processes', val: get(data.cpu.procs) },
                    { label: 'Uptime', val: get(data.cpu.uptime) },
                    { label: 'Temperature', val: data.cpu.temp > 0 ? data.cpu.temp + '°C' : '--' }
                ]
            });
        }

        // 2. RAM
        if (data.ram) {
            devices.push({ 
                id: 'ram', type: 'ram', label: 'Memory', val: data.ram.usage, sub: get(data.ram.total),
                stats: [
                    { label: 'In Use', val: get(data.ram.used) },
                    { label: 'Available', val: (100 - data.ram.usage) + '%' },
                    { label: 'Committed', val: get(data.ram.committed) }
                ]
            });
        }

        // 3. DISKS
        if(data.disks) data.disks.forEach((d, i) => {
            devices.push({
                id: `disk${i}`, type: 'disk', label: d.name, val: d.usage, sub: `${d.read} R / ${d.write} W`,
                stats: [
                    { label: 'Active Time', val: d.usage + '%' },
                    { label: 'Read Speed', val: d.read },
                    { label: 'Write Speed', val: d.write },
                    { label: 'Response Time', val: get(d.resp, ' ms') }
                ]
            });
        });

        // 4. NETWORK
        if (data.network) {
            devices.push({
                id: 'net', type: 'network', label: 'Wi-Fi', val: data.network.usage, sub: data.network.name,
                stats: [
                    { label: 'Send', val: data.network.send },
                    { label: 'Receive', val: data.network.recv },
                    { label: 'Signal Strength', val: 'Excellent' }
                ]
            });
        }

        // 5. GPUS
        if(data.gpus) data.gpus.forEach((g, i) => {
            devices.push({
                id: `gpu${i}`, type: 'gpu', label: 'GPU ' + i, val: g.usage, sub: g.name,
                stats: [
                    { label: 'Utilization', val: g.usage + '%' },
                    { label: 'Temperature', val: g.temp > 0 ? g.temp + '°C' : '--' },
                    { label: 'Driver', val: get(g.driver).substring(0, 15) + '...' },
                    { label: 'Memory', val: get(g.ram) }
                ]
            });
        });

        renderSidebar(devices);
        devices.forEach(d => {
            initHistory(d.id);
            history[d.id].push(d.val);
            if(history[d.id].length > 60) history[d.id].shift();
        });

        const activeItem = devices.find(d => d.id === selectedDevice) || devices[0];
        if(activeItem) updateMainView(activeItem);

    } catch (e) { console.log("Waiting for data..."); }
}

function renderSidebar(devices) {
    const list = document.getElementById('device-list');
    list.innerHTML = '';
    devices.forEach(d => {
        const div = document.createElement('div');
        div.className = `nav-item ${d.id === selectedDevice ? 'active' : ''}`;
        div.onclick = () => { selectedDevice = d.id; fetchStats(); };
        const col = colors[d.type] || '#fff';
        const roundedVal = Math.round(d.val);
        div.innerHTML = `
            <div class="nav-item-top"><span class="item-name">${d.label}</span><span class="item-usage">${roundedVal}%</span></div>
            <div class="item-sub">${d.sub}</div>
            <div class="mini-bar-bg"><div class="mini-bar-fill" style="width:${roundedVal}%; background:${col}"></div></div>`;
        list.appendChild(div);
    });
}

function updateMainView(device) {
    document.getElementById('detail-title').innerText = device.label;
    document.getElementById('detail-subtitle').innerText = device.sub;
    const usageEl = document.getElementById('detail-usage');
    usageEl.innerText = Math.round(device.val) + '%';
    const color = colors[device.type] || colors.cpu;
    usageEl.style.color = color;
    drawGraph('main-graph', history[device.id], color);
    const grid = document.getElementById('stats-grid');
    grid.innerHTML = '';
    device.stats.forEach(s => {
        const div = document.createElement('div');
        div.className = 'stat-box';
        div.innerHTML = `<span class="stat-label">${s.label}</span><span class="stat-value">${s.val}</span>`;
        grid.appendChild(div);
    });
}

function drawGraph(id, data, color) {
    const canvas = document.getElementById(id);
    const ctx = canvas.getContext('2d');
    if(canvas.clientWidth !== canvas.width || canvas.clientHeight !== canvas.height) { canvas.width = canvas.clientWidth; canvas.height = canvas.clientHeight; }
    const w = canvas.width; const h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = '#383838'; ctx.lineWidth = 1; ctx.beginPath();
    for(let i=1; i<4; i++) { let y = (h/4)*i; ctx.moveTo(0, y); ctx.lineTo(w, y); }
    for(let i=1; i<6; i++) { let x = (w/6)*i; ctx.moveTo(x, 0); ctx.lineTo(x, h); }
    ctx.stroke();
    ctx.beginPath();
    const step = w / (data.length - 1);
    data.forEach((val, i) => { const x = i * step; const y = h - ((val / 100) * h); if(i===0) ctx.moveTo(x, y); else ctx.lineTo(x, y); });
    ctx.lineJoin = 'round'; ctx.lineWidth = 3; ctx.strokeStyle = color; ctx.stroke();
    ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
    let r=0, g=0, b=0; if(color.startsWith('#')) { r = parseInt(color.slice(1, 3), 16); g = parseInt(color.slice(3, 5), 16); b = parseInt(color.slice(5, 7), 16); }
    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, `rgba(${r}, ${g}, ${b}, 0.2)`); grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad; ctx.fill();
}

setInterval(fetchStats, 1000); fetchStats();