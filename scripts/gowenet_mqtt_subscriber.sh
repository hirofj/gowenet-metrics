#!/bin/bash

# GOWENET MQTT Subscriber for Pi1
# Pi2-Pi4から送信されるメトリクスを受信してCSVに保存
# 日付ごとにファイルを分割

MQTT_BROKER="192.168.3.86"
MQTT_PORT="1883"
MQTT_TOPIC="gowenet/metrics/#"
OUTPUT_DIR="/home/$USER/gowenet-metrics/data"
LOG_DIR="/home/$USER/gowenet-metrics/logs"
LOG_FILE="${LOG_DIR}/mqtt_subscriber.log"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

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
    
    # ステータスメッセージはスキップ
    [[ "$topic" == *"/status" ]] && continue
    
    # ホスト名を抽出
    hostname=$(echo "$topic" | awk -F'/' '{print $3}')
    
    # メッセージからタイムスタンプを抽出（YYYY-MM-DD HH:MM:SS形式）
    timestamp=$(echo "$message" | cut -d',' -f1)
    
    # タイムスタンプから日付のみを抽出してファイル名用に変換
    # 例: "2025-11-10 10:15:17" -> "20251110"
    file_date=$(echo "$timestamp" | cut -d' ' -f1 | sed 's/-//g')
    
    # CSVファイル名（日付ごとに分割）
    csv_file="${OUTPUT_DIR}/resources_${hostname}_${file_date}.csv"
    
    # CSVヘッダー作成（ファイルが存在しない場合のみ）
    if [ ! -f "$csv_file" ]; then
        echo "timestamp,node_name,cpu_percent,mem_used_mb,mem_total_mb,mem_percent,swap_used_mb,swap_percent,disk_used_gb,disk_total_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes,avalanche_pids,response_time_ms,temp_celsius" > "$csv_file"
        log "Created: $csv_file"
    fi
    
    # データ追記
    echo "$message" >> "$csv_file"
    log "Saved: ${hostname} - ${timestamp} -> $(basename $csv_file)"
done
