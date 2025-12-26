#!/bin/bash
cd "$(dirname "$0")"; mkdir -p data
if [ ! -f "data/stats.json" ]; then echo '{"cpu":{"usage":0,"name":"Initializing..."},"ram":{"usage":0},"network":{"usage":0},"disks":[],"gpus":[]}' > data/stats.json; fi
echo "[1/2] Starting Web Server..."; sudo docker compose up --build -d
echo "[2/2] Starting Spy Agent..."; chmod +x spy.sh; ./spy.sh