#!/bin/bash

# GOWENET Resource Metrics Collection with MQTT Support
# ノードリソース収集 + MQTT送信機能統合スクリプト

# ========================================
# ヘルプ表示
# ========================================
show_help() {
    cat << 'HELP'
GOWENET リソースメトリクス収集スクリプト（MQTT対応版）

使い方:
    ./gowenet_resources_mqtt.sh [間隔] [継続時間]
    ./gowenet_resources_mqtt.sh --help

引数:
    間隔        データ収集間隔（秒） デフォルト: 10秒
    継続時間    データ収集の継続時間（秒） デフォルト: 300秒（5分）

実行例:
    # デフォルト設定（10秒間隔、5分間）
    ./gowenet_resources_mqtt.sh

    # MQTT有効化して実行
    MQTT_ENABLED=true ./gowenet_resources_mqtt.sh

    # カスタムブローカーを指定
    MQTT_BROKER=192.168.3.86 ./gowenet_resources_mqtt.sh

    # バックグラウンド実行
    nohup ./gowenet_resources_mqtt.sh 10 3600 > /dev/null 2>&1 &

環境変数:
    MQTT_ENABLED    MQTT送信の有効/無効 (true/false) デフォルト: false
    MQTT_BROKER     MQTTブローカーのIP デフォルト: 192.168.3.86
    MQTT_QOS        QoSレベル (0/1/2) デフォルト: 1

出力:
    CSVファイル: ~/gowenet-metrics/data/resources_[ホスト名]_[タイムスタンプ].csv
    ログファイル: ~/gowenet-metrics/logs/resources_[ホスト名].log
    MQTTトピック: gowenet/metrics/[ホスト名]

HELP
}

# ヘルプオプションのチェック
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# ========================================
# 設定セクション
# ========================================

# 自動検出：ホスト名からノード情報を取得
HOSTNAME=$(hostname)
NODE_IP=$(hostname -I | awk '{print $1}')

# ノード情報マッピング
declare -A NODE_NAMES=(
    ["daikon"]="pi1"
    ["tamago"]="pi2"
    ["tomato"]="pi3"
    ["tamanegi"]="pi4"
)

NODE_NAME="${NODE_NAMES[$HOSTNAME]:-$HOSTNAME}"


# MQTT設定（環境変数で制御）
# MQTT_ENABLEDは自動判定（環境変数が設定されていない場合のみ）
MQTT_BROKER=${MQTT_BROKER:-"192.168.3.86"}
MQTT_PORT=${MQTT_PORT:-1883}
MQTT_TOPIC="gowenet/metrics/${HOSTNAME}"
MQTT_QOS=${MQTT_QOS:-1}
MQTT_RETAIN=${MQTT_RETAIN:-false}

# MQTTの自動判定（環境変数MQTT_ENABLEDが未設定の場合のみ）
if [ -z "${MQTT_ENABLED+x}" ]; then
    case "$HOSTNAME" in
        "daikon")
            MQTT_ENABLED=false  # Pi1は受信側なので送信しない
            ;;
        "tamago"|"tomato"|"tamanegi")
            MQTT_ENABLED=true   # Pi2-4は送信する
            ;;
        *)
            MQTT_ENABLED=false  # デフォルトは無効
            ;;
    esac
fi
LOCAL_RPC="http://localhost:9650/ext/health"

# 出力設定
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="/home/$USER/gowenet-metrics/data"
LOG_DIR="/home/$USER/gowenet-metrics/logs"
OUTPUT_FILE="${OUTPUT_DIR}/resources_${HOSTNAME}_${TIMESTAMP}.csv"
LOG_FILE="${LOG_DIR}/resources_${HOSTNAME}.log"

# 収集間隔（秒）
INTERVAL="${1:-10}"
DURATION="${2:-300}"

# ========================================
# 初期化
# ========================================

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "GOWENET Resource Metrics Collection Started (MQTT Version)"
log "Node: $HOSTNAME ($NODE_NAME - $NODE_IP)"
log "Output: $OUTPUT_FILE"
log "MQTT Enabled: $MQTT_ENABLED"
if [ "$MQTT_ENABLED" = "true" ]; then
    log "MQTT Broker: $MQTT_BROKER:$MQTT_PORT"
    log "MQTT Topic: $MQTT_TOPIC"
    log "MQTT QoS: $MQTT_QOS"
fi
log "Interval: ${INTERVAL}s, Duration: ${DURATION}s"
log "=========================================="

# ========================================
# MQTT接続チェック
# ========================================

check_mqtt_connection() {
    if [ "$MQTT_ENABLED" = "true" ]; then
        # mosquitto_pubがインストールされているか確認
        if ! command -v mosquitto_pub &> /dev/null; then
            log "WARNING: mosquitto_pub not found. MQTT disabled."
            log "Install with: sudo apt-get install mosquitto-clients"
            MQTT_ENABLED=false
            return 1
        fi
        
        # ブローカーへの接続確認
        if ! nc -zv "$MQTT_BROKER" "$MQTT_PORT" &> /dev/null; then
            log "WARNING: Cannot connect to MQTT broker at $MQTT_BROKER:$MQTT_PORT"
            log "MQTT will be disabled for this session."
            MQTT_ENABLED=false
            return 1
        fi
        
        log "✓ MQTT connection verified"
        
        # 初回接続テスト
        echo "test" | mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
            -t "${MQTT_TOPIC}/status" -l -q "$MQTT_QOS" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log "✓ MQTT test message sent successfully"
        else
            log "WARNING: MQTT test failed, but continuing..."
        fi
    fi
}

# MQTT接続チェック実行
check_mqtt_connection

# 開始メッセージを送信
if [ "$MQTT_ENABLED" = "true" ]; then
    start_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$start_timestamp" | mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "gowenet/metrics/${HOSTNAME}/start" -l -q "$MQTT_QOS" 2>/dev/null
    log "Sent start message to MQTT"
fi

# ========================================
# CSVヘッダー作成
# ========================================

cat > "$OUTPUT_FILE" << 'HEADER'
timestamp,node_name,cpu_percent,mem_used_mb,mem_total_mb,mem_percent,swap_used_mb,swap_percent,disk_used_gb,disk_total_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes,avalanche_pids,response_time_ms,temp_celsius
HEADER

log "CSV header created"

# ========================================
# データ送信関数（CSV + MQTT）
# ========================================

send_metrics() {
    local csv_line="$1"
    
    # 常にローカルCSVに保存
    echo "$csv_line" >> "$OUTPUT_FILE"
    
    # MQTT送信（有効な場合のみ）
    if [ "$MQTT_ENABLED" = "true" ]; then
        # CSV形式でそのまま送信
        echo "$csv_line" | mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
            -t "$MQTT_TOPIC" -l -q "$MQTT_QOS" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            # 成功時は何も出力しない（ログ削減）
            :
        else
            # エラー時のみログ出力
            log "WARNING: MQTT send failed for topic $MQTT_TOPIC"
        fi
    fi
}

# ========================================
# リソースメトリクス収集関数
# ========================================

get_cpu_usage() {
    # 1秒間のCPU使用率を取得（より正確な測定）
    top -bn2 -d1 | grep "Cpu(s)" | tail -1 | awk '{print 100 - $8}' | cut -d'%' -f1
}

get_memory_stats() {
    # 詳細なメモリ統計
    free -m | awk '
        NR==2 {printf "%d,%d,%.1f,", $3, $2, ($3/$2)*100}
        NR==3 {printf "%d,%.1f", $3, ($3/$2)*100}
    '
}

get_disk_stats() {
    # ルートパーティションの詳細なディスク使用状況
    df -BG / | awk 'NR==2 {
        gsub(/G/,""); 
        printf "%s,%s,%s", $3, $2, $5
    }' | sed 's/%//'
}

get_network_stats() {
    # ネットワーク統計（累積値をMBで）
    local interface="eth0"  # デフォルトインターフェース
    
    # インターフェースの自動検出
    if ! ip link show $interface &>/dev/null; then
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
    fi
    
    if [ -n "$interface" ]; then
        local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
        
        # 前回の値を保存（差分計算用）
        if [ -z "$PREV_RX" ]; then
            PREV_RX=$rx_bytes
            PREV_TX=$tx_bytes
        fi
        
        # 累積値をMBで出力
        echo "$((rx_bytes / 1048576)),$((tx_bytes / 1048576))"
    else
        echo "0,0"
    fi
}

get_load_average() {
    # ロードアベレージ（1分、5分、15分）
    cat /proc/loadavg | awk '{print $1, $2, $3}' | tr ' ' ','
}

get_process_info() {
    # プロセス総数とavalanchegoのPID
    local total_procs=$(ps aux | wc -l)
    local avalanche_pids=$(pgrep avalanchego | tr '\n' ':' | sed 's/:$//' || echo "none")
    echo "$total_procs,$avalanche_pids"
}

get_response_time() {
    # ローカルノードの応答時間（ミリ秒）
    if command -v curl &> /dev/null; then
        local start=$(date +%s%N)
        curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
            -H 'content-type:application/json' "$LOCAL_RPC" &>/dev/null
        local end=$(date +%s%N)
        
        if [ $? -eq 0 ]; then
            echo $(( (end - start) / 1000000 ))
        else
            echo "-1"
        fi
    else
        echo "0"
    fi
}

get_temperature() {
    # Raspberry Pi CPU温度（摂氏）
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "scale=1; $temp / 1000" | bc
    else
        echo "0"
    fi
}

# ========================================
# ネットワーク差分計算用変数
# ========================================

PREV_RX=""
PREV_TX=""

# ========================================
# 開始時のステータス送信
# ========================================

if [ "$MQTT_ENABLED" = "true" ]; then
    # 収集開始を通知
    status_msg="STARTED,$(date +%s),${HOSTNAME},${NODE_IP},${INTERVAL},${DURATION}"
    echo "$status_msg" | mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "${MQTT_TOPIC}/status" -l -q "$MQTT_QOS" 2>/dev/null
fi

# ========================================
# メイン収集ループ
# ========================================

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
ITERATION=0
MQTT_SUCCESS_COUNT=0
MQTT_FAIL_COUNT=0

log "Starting resource metrics collection..."

# 初回実行（ベースライン取得）
get_network_stats > /dev/null

while [ $(date +%s) -lt $END_TIME ]; do
    ITERATION=$((ITERATION + 1))
    
    # タイムスタンプ
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    
    # メトリクス収集
    CPU_USAGE=$(get_cpu_usage)
    MEM_STATS=$(get_memory_stats)
    DISK_STATS=$(get_disk_stats)
    NET_STATS=$(get_network_stats)
    LOAD_AVG=$(get_load_average)
    PROC_INFO=$(get_process_info)
    RESPONSE_TIME=$(get_response_time)
    TEMPERATURE=$(get_temperature)
    
    # CSVライン作成
    CSV_LINE="${TS},${NODE_NAME},${CPU_USAGE},${MEM_STATS},${DISK_STATS},${NET_STATS},${LOAD_AVG},${PROC_INFO},${RESPONSE_TIME},${TEMPERATURE}"
    
    # データ送信（CSV + MQTT）
    send_metrics "$CSV_LINE"
    
    # ログ出力（10イテレーションごと）
    if [ $((ITERATION % 10)) -eq 0 ]; then
        if [ "$MQTT_ENABLED" = "true" ]; then
            log "Iteration $ITERATION: CPU: ${CPU_USAGE}%, Temp: ${TEMPERATURE}°C, MQTT: Active"
        else
            log "Iteration $ITERATION: CPU: ${CPU_USAGE}%, Temp: ${TEMPERATURE}°C, MQTT: Disabled"
        fi
    fi
    
    # CPU使用率が高い場合の警告
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        log "WARNING: High CPU usage detected: ${CPU_USAGE}%"
    fi
    
    # 温度警告（Raspberry Pi）
    if (( $(echo "$TEMPERATURE > 70" | bc -l) )); then
        log "WARNING: High temperature detected: ${TEMPERATURE}°C"
    fi
    
    # 待機
    sleep $INTERVAL
done

# ========================================
# 完了処理
# ========================================

TOTAL_RECORDS=$(wc -l < "$OUTPUT_FILE")

# 終了メッセージを送信
if [ "$MQTT_ENABLED" = "true" ]; then
    end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$end_timestamp" | mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "gowenet/metrics/${HOSTNAME}/end" -l -q "$MQTT_QOS" 2>/dev/null
    log "Sent end message to MQTT"
fi

# 終了ステータスをMQTTで送信
if [ "$MQTT_ENABLED" = "true" ]; then
    status_msg="COMPLETED,$(date +%s),${HOSTNAME},${TOTAL_RECORDS}"
    echo "$status_msg" | mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "${MQTT_TOPIC}/status" -l -q "$MQTT_QOS" 2>/dev/null
fi

log "=========================================="
log "Resource metrics collection completed"
log "Total records: $((TOTAL_RECORDS - 1))"
log "Output file: $OUTPUT_FILE"
if [ "$MQTT_ENABLED" = "true" ]; then
    log "MQTT Topic: $MQTT_TOPIC"
    log "MQTT Messages sent to broker: $MQTT_BROKER"
fi
log "=========================================="

# サマリー統計の計算
if command -v awk &> /dev/null; then
    log "=== Resource Usage Summary ==="
    
    # CPU使用率の平均
    AVG_CPU=$(tail -n +2 "$OUTPUT_FILE" | awk -F',' '{sum+=$3; count++} END {if(count>0) printf "%.1f", sum/count}')
    log "Average CPU Usage: ${AVG_CPU}%"
    
    # メモリ使用率の平均
    AVG_MEM=$(tail -n +2 "$OUTPUT_FILE" | awk -F',' '{sum+=$6; count++} END {if(count>0) printf "%.1f", sum/count}')
    log "Average Memory Usage: ${AVG_MEM}%"
    
    # 平均温度
    AVG_TEMP=$(tail -n +2 "$OUTPUT_FILE" | awk -F',' '{sum+=$20; count++} END {if(count>0) printf "%.1f", sum/count}')
    log "Average Temperature: ${AVG_TEMP}°C"
    
    log "=============================="
fi

exit 0