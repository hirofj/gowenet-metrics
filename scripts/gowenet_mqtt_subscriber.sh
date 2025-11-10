#!/bin/bash

# GOWENET MQTT Subscriber for Pi1
# Pi2-Pi4から送信されるメトリクスを受信してCSVに保存
# Usage: ./gowenet_mqtt_subscriber.sh [start|stop|status]

MQTT_BROKER="192.168.3.86"
MQTT_PORT="1883"
MQTT_TOPIC="gowenet/metrics/#"
OUTPUT_DIR="/home/$USER/gowenet-metrics/data"
LOG_DIR="/home/$USER/gowenet-metrics/logs"
LOG_FILE="${LOG_DIR}/mqtt_subscriber.log"
PID_FILE="${LOG_DIR}/mqtt_subscriber.pid"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 起動時刻を記録するファイル
START_TIME_FILE="${LOG_DIR}/mqtt_subscriber_start_time.txt"

start_subscriber() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Subscriber is already running (PID: $pid)"
            return 1
        fi
    fi
    
    # 起動時刻を記録（ファイル名用）
    date '+%Y%m%d_%H%M%S' > "$START_TIME_FILE"
    
    log "=========================================="
    log "GOWENET MQTT Subscriber Started"
    log "Broker: ${MQTT_BROKER}:${MQTT_PORT}"
    log "Topic: ${MQTT_TOPIC}"
    log "Output Directory: ${OUTPUT_DIR}"
    log "Session Start: $(date '+%Y-%m-%d %H:%M:%S')"
    log "=========================================="
    
    # バックグラウンドで起動
    nohup bash -c '
        MQTT_BROKER="'"$MQTT_BROKER"'"
        MQTT_PORT="'"$MQTT_PORT"'"
        MQTT_TOPIC="'"$MQTT_TOPIC"'"
        OUTPUT_DIR="'"$OUTPUT_DIR"'"
        LOG_FILE="'"$LOG_FILE"'"
        START_TIME_FILE="'"$START_TIME_FILE"'"
        
        log() {
            echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] $1" >> "$LOG_FILE"
        }
        
        # 起動時刻を読み込み
        START_TIME=$(cat "$START_TIME_FILE")
        
        # 各ホスト用の連想配列（bashではdeclareを使う）
        declare -A current_file
        
        mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t "$MQTT_TOPIC" -v | while read -r line; do
            topic=$(echo "$line" | cut -d" " -f1)
            message=$(echo "$line" | cut -d" " -f2-)
            
            # ステータスメッセージはスキップ
            [[ "$topic" == *"/status" ]] && continue
            
            # ホスト名を抽出
            hostname=$(echo "$topic" | awk -F"/" "{print \$3}")
            
            # このホスト用のファイルがまだ作成されていない場合
            if [ -z "${current_file[$hostname]}" ]; then
                csv_file="${OUTPUT_DIR}/resources_${hostname}_${START_TIME}.csv"
                current_file[$hostname]="$csv_file"
                
                # CSVヘッダー作成
                echo "timestamp,node_name,cpu_percent,mem_used_mb,mem_total_mb,mem_percent,swap_used_mb,swap_percent,disk_used_gb,disk_total_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes,avalanche_pids,response_time_ms,temp_celsius" > "$csv_file"
                log "Created: $(basename $csv_file)"
            fi
            
            # データ追記
            csv_file="${current_file[$hostname]}"
            echo "$message" >> "$csv_file"
            
            timestamp=$(echo "$message" | cut -d"," -f1)
            log "Saved: ${hostname} - ${timestamp}"
        done
    ' >> "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    echo "Subscriber started (PID: $(cat $PID_FILE))"
    echo "Log: $LOG_FILE"
}

stop_subscriber() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Subscriber is not running (no PID file)"
        return 1
    fi
    
    pid=$(cat "$PID_FILE")
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo "Subscriber is not running (stale PID file)"
        rm -f "$PID_FILE"
        return 1
    fi
    
    log "Stopping MQTT Subscriber (PID: $pid)..."
    
    # mosquitto_subとその親プロセスを停止
    pkill -P "$pid"
    kill "$pid" 2>/dev/null
    
    # 少し待機
    sleep 1
    
    # 強制終了が必要な場合
    if ps -p "$pid" > /dev/null 2>&1; then
        kill -9 "$pid" 2>/dev/null
    fi
    
    rm -f "$PID_FILE"
    log "MQTT Subscriber stopped"
    echo "Subscriber stopped"
}

status_subscriber() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Subscriber is not running"
        return 1
    fi
    
    pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Subscriber is running (PID: $pid)"
        if [ -f "$START_TIME_FILE" ]; then
            start_time=$(cat "$START_TIME_FILE")
            echo "Session started: $start_time"
        fi
        echo "Log: $LOG_FILE"
        return 0
    else
        echo "Subscriber is not running (stale PID file)"
        rm -f "$PID_FILE"
        return 1
    fi
}

case "$1" in
    start)
        start_subscriber
        ;;
    stop)
        stop_subscriber
        ;;
    status)
        status_subscriber
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start MQTT subscriber in background"
        echo "  stop    - Stop MQTT subscriber"
        echo "  status  - Check subscriber status"
        exit 1
        ;;
esac
