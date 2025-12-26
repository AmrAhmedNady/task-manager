#!/bin/bash

# --- CONFIGURATION ---
DATA_DIR="./data"
TEMP_FILE="$DATA_DIR/stats.tmp"
FINAL_FILE="$DATA_DIR/stats.json"
LOG_FILE="$DATA_DIR/history.csv"

mkdir -p "$DATA_DIR"

# Initialize Log
if [ ! -f "$LOG_FILE" ]; then
    echo "Timestamp,CPU_Usage,RAM_Usage,Disk_Usage,GPU_Usage" > "$LOG_FILE"
fi

echo -e "\033[1;36mmacOS Spy Started. Logging active...\033[0m"

while true; do
    # --- 1. CPU INFO ---
    # Get Model Name
    CPU_NAME=$(sysctl -n machdep.cpu.brand_string)
    
    # Get Usage (Parse 'top')
    # macOS top output: "CPU usage: 12.5% user, 8.3% sys, 79.2% idle"
    CPU_IDLE=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $7}' | tr -d '%')
    # Calculate usage: 100 - idle
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)

    # Get Uptime
    BOOT_TIME=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ',')
    NOW=$(date +%s)
    UPTIME_SEC=$((NOW - BOOT_TIME))
    UPTIME=$(date -u -r $UPTIME_SEC +%H:%M:%S)

    # Process Count
    PROC_COUNT=$(ps -e | wc -l | xargs) # xargs trims whitespace
    THREAD_COUNT=$(ps -M | wc -l | xargs)

    # Speed (Hard on Apple Silicon, returns Frequency on Intel)
    CPU_FREQ=$(sysctl -n hw.cpufrequency 2>/dev/null)
    if [ -z "$CPU_FREQ" ]; then
        CPU_SPEED="Variable" # Apple Silicon hides clock speed
    else
        CPU_SPEED=$(echo "scale=2; $CPU_FREQ / 1000000000" | bc)" GHz"
    fi

    # --- 2. MEMORY (RAM) ---
    # macOS uses vm_stat. Page size is usually 4096 bytes.
    PAGE_SIZE=$(vm_stat | grep "page size" | awk '{print $3}')
    PAGES_FREE=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    PAGES_ACTIVE=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
    PAGES_INACTIVE=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
    PAGES_WIRED=$(vm_stat | grep "Pages wired" | awk '{print $4}' | tr -d '.')
    PAGES_COMPRESSED=$(vm_stat | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

    # Total RAM (Physical)
    MEM_TOTAL_BYTES=$(sysctl -n hw.memsize)
    MEM_TOTAL_GB=$(echo "scale=1; $MEM_TOTAL_BYTES / 1024 / 1024 / 1024" | bc)

    # Calculate Used: (App Memory + Wired + Compressed)
    # This is an approximation similar to Activity Monitor
    MEM_USED_BYTES=$(echo "($PAGES_ACTIVE + $PAGES_WIRED + $PAGES_COMPRESSED) * $PAGE_SIZE" | bc)
    MEM_USED_GB=$(echo "scale=1; $MEM_USED_BYTES / 1024 / 1024 / 1024" | bc)
    
    MEM_PERC=$(echo "scale=0; ($MEM_USED_BYTES * 100) / $MEM_TOTAL_BYTES" | bc)

    # --- 3. DISKS ---
    # Construct JSON array manually
    DISK_JSON="["
    while read -r line; do
        NAME=$(echo $line | awk '{print $1}')
        SIZE=$(echo $line | awk '{print $2}')
        PERC=$(echo $line | awk '{print $5}' | tr -d '%')
        
        if [ "$DISK_JSON" != "[" ]; then DISK_JSON="$DISK_JSON,"; fi
        
        DISK_JSON="$DISK_JSON {
            \"name\": \"Disk ($NAME)\",
            \"usage\": \"$PERC\",
            \"capacity\": \"$SIZE\",
            \"type\": \"APFS\",
            \"letter\": \"/\"
        }"
    done < <(df -h | grep '/$') # Only grab root volume
    DISK_JSON="$DISK_JSON ]"

    # --- 4. GPUS ---
    # Getting real-time GPU % on macOS via script is very hard (requires sudo powermetrics).
    # We will fetch the Model Name.
    GPU_MODEL=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Chipset Model" | head -n 1 | awk -F ": " '{print $2}')
    if [ -z "$GPU_MODEL" ]; then GPU_MODEL="Apple GPU"; fi
    
    # Default to 0% usage because we can't read it easily without root
    GPU_JSON="[{
        \"name\": \"$GPU_MODEL\",
        \"usage\": \"0\",
        \"temp\": \"0\",
        \"driver\": \"Apple Metal\",
        \"ram\": \"Shared\"
    }]"

    # --- 5. BUILD JSON ---
    # Manual string construction
    JSON_STRING="{
        \"cpu\": {
            \"usage\": \"$CPU_USAGE\",
            \"name\": \"$CPU_NAME\",
            \"speed\": \"$CPU_SPEED\",
            \"temp\": \"0\",
            \"procs\": \"$PROC_COUNT\",
            \"threads\": \"$THREAD_COUNT\",
            \"uptime\": \"$UPTIME\"
        },
        \"ram\": {
            \"usage\": \"$MEM_PERC\",
            \"used\": \"$MEM_USED_GB GB\",
            \"total\": \"$MEM_TOTAL_GB GB\",
            \"committed\": \"$MEM_USED_GB / $MEM_TOTAL_GB GB\"
        },
        \"disks\": $DISK_JSON,
        \"gpus\": $GPU_JSON
    }"

    # 6. WRITE & LOG
    echo "$JSON_STRING" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$FINAL_FILE"

    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP,$CPU_USAGE,$MEM_PERC,$DISK_USAGE,0" >> "$LOG_FILE"

    echo -e "Updated: $TIMESTAMP | CPU: $CPU_USAGE% | RAM: $MEM_PERC%"
    
    sleep 1
done