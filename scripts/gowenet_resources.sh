#!/bin/bash

# GOWENET Resource Metrics Collection for Pi2-Pi4
# ノードリソース専用収集スクリプト

# ========================================
# ヘルプ表示
# ========================================
show_help() {
    cat << 'HELP'
GOWENET Pi2-Pi4用 リソースメトリクス収集スクリプト

使い方:
    ./gowenet_resources.sh [間隔] [継続時間]
    ./gowenet_resources.sh --help

引数:
    間隔        データ収集間隔（秒） デフォルト: 10秒
    継続時間    データ収集の継続時間（秒） デフォルト: 300秒（5分）

実行例:
    # デフォルト設定（10秒間隔、5分間）
    ./gowenet_resources.sh

    # 1時間収集（5秒間隔）
    ./gowenet_resources.sh 5 3600

    # バックグラウンド実行
    nohup ./gowenet_resources.sh 10 3600 > /dev/null 2>&1 &

出力:
    CSVファイル: ~/gowenet-metrics/data/resources_[ホスト名]_[タイムスタンプ].csv
    ログファイル: ~/gowenet-metrics/logs/resources_[ホスト名].log

収集メトリクス:
    - CPU使用率
    - メモリ使用量・使用率
    - ディスク使用量・使用率
    - ネットワークI/O
    - ロードアベレージ
    - avalanchegoプロセス数
    - ノードの応答性（ローカルRPC応答時間）

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
    ["tamago"]="pi2"
    ["tomato"]="pi3"
    ["tamanegi"]="pi4"
)

NODE_NAME="${NODE_NAMES[$HOSTNAME]:-$HOSTNAME}"

# ローカルRPCエンドポイント（応答性チェック用）
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
log "GOWENET Resource Metrics Collection Started"
log "Node: $HOSTNAME ($NODE_NAME - $NODE_IP)"
log "Output: $OUTPUT_FILE"
log "Interval: ${INTERVAL}s, Duration: ${DURATION}s"
log "=========================================="

# ========================================
# CSVヘッダー作成
# ========================================

cat > "$OUTPUT_FILE" << 'HEADER'
timestamp,node_name,cpu_percent,mem_used_mb,mem_total_mb,mem_percent,swap_used_mb,swap_percent,disk_used_gb,disk_total_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes,avalanche_pids,response_time_ms,temp_celsius
HEADER

log "CSV header created"

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
# メイン収集ループ
# ========================================

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
ITERATION=0

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
    
    # CSV出力
    echo "${TS},${NODE_NAME},${CPU_USAGE},${MEM_STATS},${DISK_STATS},${NET_STATS},${LOAD_AVG},${PROC_INFO},${RESPONSE_TIME},${TEMPERATURE}" >> "$OUTPUT_FILE"
    
    # ログ出力（10イテレーションごと）
    if [ $((ITERATION % 10)) -eq 0 ]; then
        log "Iteration $ITERATION: CPU: ${CPU_USAGE}%, Temp: ${TEMPERATURE}°C, Response: ${RESPONSE_TIME}ms"
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

log "=========================================="
log "Resource metrics collection completed"
log "Total records: $((TOTAL_RECORDS - 1))"
log "Output file: $OUTPUT_FILE"
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
