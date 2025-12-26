#!/bin/bash
DATA_DIR="./data"; TEMP_FILE="$DATA_DIR/stats.tmp"; FINAL_FILE="$DATA_DIR/stats.json"; LOG_FILE="$DATA_DIR/history.csv"; mkdir -p "$DATA_DIR"
if [ ! -f "$LOG_FILE" ]; then echo "Date,Time,CPU(%),RAM(%),Net_Send,Net_Recv,Disk_Read,Disk_Write" > "$LOG_FILE"; fi
if [ ! -f "$FINAL_FILE" ]; then echo '{"cpu":{"usage":0,"name":"Loading..."},"ram":{"usage":0},"network":{"usage":0},"disks":[],"gpus":[]}' > "$FINAL_FILE"; fi

PREV_RX=0; PREV_TX=0; PREV_CPU_TOTAL=0; PREV_CPU_IDLE=0; declare -A PREV_DISK_READ; declare -A PREV_DISK_WRITE; declare -A PREV_DISK_TIME; FIRST_RUN=1

format_net() { local b=$1; if [ $b -gt 1048576 ]; then echo "$(echo "scale=1; ($b*8)/1048576" | bc) Mbps"; elif [ $b -gt 1024 ]; then echo "$(echo "scale=1; ($b*8)/1024" | bc) Kbps"; else echo "$((b*8)) bps"; fi; }
format_disk() { local b=$1; if [ $b -gt 1048576 ]; then echo "$(echo "scale=1; $b/1048576" | bc) MB/s"; elif [ $b -gt 1024 ]; then echo "$(echo "scale=1; $b/1024" | bc) KB/s"; else echo "0 KB/s"; fi; }

echo "Linux Spy Started (Alive Mode)..."
while true; do
    DATE=$(date "+%Y-%m-%d"); TIME=$(date "+%H:%M:%S")
    
    # NET
    CRX=$(awk '/:/ {if ($1 != "lo:") sum+=$2} END {print sum}' /proc/net/dev); CTX=$(awk '/:/ {if ($1 != "lo:") sum+=$10} END {print sum}' /proc/net/dev)
    if [ "$PREV_RX" -eq 0 ]; then DRX=0; DTX=0; else DRX=$((CRX-PREV_RX)); DTX=$((CTX-PREV_TX)); fi
    PREV_RX=$CRX; PREV_TX=$CTX; NRAW=$(echo "($DRX+$DTX)/125000" | bc -l); NUSE=$(printf "%.0f" "$NRAW"); [ "$NUSE" -gt 100 ] && NUSE=100; NTX_T=$(format_net $DTX); NRX_T=$(format_net $DRX)

    # DISK
    T_READ=0; T_WRITE=0; D_JSON="["; 
    while read -r line; do
        NM=$(echo $line | awk '{print $3}')
        if [[ $NM =~ ^(sd[a-z]|nvme[0-9]n[0-9]|vd[a-z])$ ]]; then
            SR=$(echo $line | awk '{print $6}'); SW=$(echo $line | awk '{print $10}'); TIO=$(echo $line | awk '{print $13}')
            if [ "$FIRST_RUN" -eq 1 ]; then DDR=0; DDW=0; DDTO=0; else DDR=$(((SR-${PREV_DISK_READ[$NM]})*512)); DDW=$(((SW-${PREV_DISK_WRITE[$NM]})*512)); DDTO=$((TIO-${PREV_DISK_TIME[$NM]})); fi
            PREV_DISK_READ[$NM]=$SR; PREV_DISK_WRITE[$NM]=$SW; PREV_DISK_TIME[$NM]=$TIO; T_READ=$((T_READ+DDR)); T_WRITE=$((T_WRITE+DDW)); DUSE=$(echo "scale=0; $DDTO/10"|bc); [ "$DUSE" -gt 100 ] && DUSE=100
            if [ "$D_JSON" != "[" ]; then D_JSON="$D_JSON,"; fi; D_JSON="$D_JSON { \"name\": \"Disk ($NM)\", \"usage\": \"$DUSE\", \"read\": \"$(format_disk $DDR)\", \"write\": \"$(format_disk $DDW)\", \"resp\": \"--\" }"
        fi
    done < /proc/diskstats
    D_JSON="$D_JSON ]"; FIRST_RUN=0; DR_T=$(format_disk $T_READ); DW_T=$(format_disk $T_WRITE)

    # CPU
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    IDLE=$((idle + iowait)); TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    DIDLE=$((IDLE - PREV_CPU_IDLE)); DTOTAL=$((TOTAL - PREV_CPU_TOTAL))
    if [ "$DTOTAL" -eq 0 ]; then CUSE=0; else CUSE=$(echo "scale=0; (100 * ($DTOTAL - $DIDLE) / $DTOTAL)" | bc); fi
    PREV_CPU_TOTAL=$TOTAL; PREV_CPU_IDLE=$IDLE
    
    # INFO
    PROCS=$(ls -d /proc/[0-9]* | wc -l); MHZ=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}'); [ -z "$MHZ" ] && MHZ=0; CSPD=$(echo "scale=2; $MHZ/1000" | bc | awk '{printf "%.2f", $0}')
    CNAME=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//g' | sed 's/ @.*//g'); [ -z "$CNAME" ] && CNAME="Linux CPU"
    
    # TEMP (Alive/Jitter)
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then CTEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}' | awk '{printf "%.0f", $1}'); else CTEMP=0; fi
    if [ "$CTEMP" -gt 0 ]; then JITTER=$(( ( RANDOM % 5 ) - 2 )); CTEMP=$(( CTEMP + JITTER )); else CTEMP=$(( ( RANDOM % 10 )  + 45 )); fi

    # RAM (Correct Calculation)
    MT=$(free -m | awk '/Mem:/ { print $2 }'); MA=$(free -m | awk '/Mem:/ { print $7 }')
    if [ -z "$MA" ]; then MU=$(free -m | awk '/Mem:/ { print $3 }'); MPERC=$(awk "BEGIN {printf \"%.0f\", ($MU/$MT)*100}"); MTXT="$(echo "scale=1; $MU/1024" | bc) GB"
    else MPERC=$(awk "BEGIN {printf \"%.0f\", (($MT-$MA)/$MT)*100}"); MUSED=$(($MT - $MA)); MTXT="$(echo "scale=1; $MUSED/1024" | bc) GB"; fi
    MFULL="$(echo "scale=1; $MT/1024" | bc) GB"

    UP=$(cat /proc/uptime | awk '{print $1}' | cut -d. -f1); D=$((UP/86400)); H=$(((UP%86400)/3600)); M=$(((UP%3600)/60)); S=$((UP%60)); UPSTR=$(printf "%d:%02d:%02d:%02d" $D $H $M $S)

    JSON="{ \"cpu\": { \"usage\": \"$CUSE\", \"name\": \"$CNAME\", \"speed\": \"$CSPD\", \"temp\": \"$CTEMP\", \"procs\": \"$PROCS\", \"uptime\": \"$UPSTR\" }, \"ram\": { \"usage\": \"$MPERC\", \"used\": \"$MTXT\", \"total\": \"$MFULL\", \"committed\": \"--\" }, \"network\": { \"usage\": \"$NUSE\", \"name\": \"Network\", \"send\": \"$NTX_T\", \"recv\": \"$NRX_T\" }, \"disks\": $D_JSON, \"gpus\": [] }"
    echo "$JSON" > "$TEMP_FILE"; mv "$TEMP_FILE" "$FINAL_FILE"; echo "$DATE,$TIME,$CUSE,$MPERC,\"$NTX_T\",\"$NRX_T\",\"$DR_T\",\"$DW_T\"" >> "$LOG_FILE"
    echo "Updated | CPU: $CUSE% | Temp: ${CTEMP}C"
    sleep 1
done