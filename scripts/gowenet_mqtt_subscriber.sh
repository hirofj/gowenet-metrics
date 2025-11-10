#!/bin/bash

# GOWENET MQTT Subscriber for Pi1
# Pi2-Pi4から送信されるメトリクスを受信してCSVに保存
# 開始/終了メッセージで新規ファイル作成を制御

MQTT_BROKER="192.168.3.86"
MQTT_PORT="1883"
MQTT_TOPIC="gowenet/metrics/#"
OUTPUT_DIR="/home/$USER/gowenet-metrics/data"
LOG_DIR="/home/$USER/gowenet-metrics/logs"
LOG_FILE="${LOG_DIR}/mqtt_subscriber.log"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# ホスト名ごとの現在のファイル名とタイムスタンプを記録
declare -A current_file
declare -A session_start_time

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "GOWENET MQTT Subscriber Started"
log "Broker: ${MQTT_BROKER}:${MQTT_PORT}"
log "Topic: ${MQTT_TOPIC}"
log "Output Directory: ${OUTPUT_DIR}"
log "=========================================="

# メッセージ受信・保存処理
mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t "$MQTT_TOPIC" -v | while read -r line; do
    topic=$(echo "$line" | cut -d' ' -f1)
    message=$(echo "$line" | cut -d' ' -f2-)
    
    # ホスト名を抽出
    hostname=$(echo "$topic" | awk -F'/' '{print $3}')
    message_type=$(echo "$topic" | awk -F'/' '{print $4}')
    
    # 開始メッセージ処理
    if [ "$message_type" = "start" ]; then
        # メッセージからタイムスタンプを取得
        timestamp=$(echo "$message" | cut -d',' -f1)
        # YYYYMMDD_HHMMSS形式に変換
        date_part=$(echo "$timestamp" | cut -d' ' -f1 | tr -d '-')
        time_part=$(echo "$timestamp" | cut -d' ' -f2 | tr -d ':')
        file_timestamp="${date_part}_${time_part}"
        
        session_start_time[$hostname]=$file_timestamp
        csv_file="${OUTPUT_DIR}/resources_${hostname}_${file_timestamp}.csv"
        current_file[$hostname]=$csv_file
        
        # CSVヘッダー作成
        echo "timestamp,node_name,cpu_percent,mem_used_mb,mem_total_mb,mem_percent,swap_used_mb,swap_percent,disk_used_gb,disk_total_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes,avalanche_pids,response_time_ms,temp_celsius" > "$csv_file"
        log "Started session: ${hostname} - ${timestamp} -> $(basename $csv_file)"
        continue
    fi
    
    # 終了メッセージ処理
    if [ "$message_type" = "end" ]; then
        log "Ended session: ${hostname} - File: $(basename ${current_file[$hostname]})"
        unset current_file[$hostname]
        unset session_start_time[$hostname]
        continue
    fi
    
    # 通常のデータメッセージ処理（message_typeが空の場合）
    if [ -z "$message_type" ]; then
        csv_file="${current_file[$hostname]}"
        
        # ファイルが設定されていない場合（開始メッセージなしでデータが来た場合）
        if [ -z "$csv_file" ]; then
            # メッセージのタイムスタンプから自動的にファイルを作成
            timestamp=$(echo "$message" | cut -d',' -f1)
            date_part=$(echo "$timestamp" | cut -d' ' -f1 | tr -d '-')
            time_part=$(echo "$timestamp" | cut -d' ' -f2 | tr -d ':')
            file_timestamp="${date_part}_${time_part}"
            
            csv_file="${OUTPUT_DIR}/resources_${hostname}_${file_timestamp}.csv"
            current_file[$hostname]=$csv_file
            
            # CSVヘッダー作成
            echo "timestamp,node_name,cpu_percent,mem_used_mb,mem_total_mb,mem_percent,swap_used_mb,swap_percent,disk_used_gb,disk_total_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes,avalanche_pids,response_time_ms,temp_celsius" > "$csv_file"
            log "Auto-started session: ${hostname} - ${timestamp} -> $(basename $csv_file)"
        fi
        
        # データ追記
        echo "$message" >> "$csv_file"
        timestamp=$(echo "$message" | cut -d',' -f1)
        log "Saved: ${hostname} - ${timestamp}"
    fi
done
