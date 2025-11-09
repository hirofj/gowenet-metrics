#!/bin/bash

# GOWENET Metrics Collection for Pi1 (Primary Node)
# ブロックチェーンメトリクス + ノードリソース収集

# ========================================
# ヘルプ表示
# ========================================
show_help() {
    cat << 'HELP'
GOWENET Pi1専用 統合メトリクス収集スクリプト

使い方:
    ./gowenet_metrics_pi1.sh [間隔] [継続時間]
    ./gowenet_metrics_pi1.sh --help

引数:
    間隔        データ収集間隔（秒） デフォルト: 10秒
    継続時間    データ収集の継続時間（秒） デフォルト: 300秒（5分）

実行例:
    # デフォルト設定（10秒間隔、5分間）
    ./gowenet_metrics_pi1.sh

    # 1時間収集（5秒間隔）
    ./gowenet_metrics_pi1.sh 5 3600

出力:
    ブロックチェーンメトリクス: ~/gowenet-metrics/data/blockchain_[タイムスタンプ].csv
    リソースメトリクス: ~/gowenet-metrics/data/resources_pi1_[タイムスタンプ].csv
    ログファイル: ~/gowenet-metrics/logs/pi1_collection.log

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

# Pi1固定設定
NODE_IP="192.168.3.86"
NODE_PORT="9654"
HOSTNAME="daikon"

# GOWENET設定
BLOCKCHAIN_ID="2tGwFCjwr3w6fW774ytz982h5Th9eiALrKFanmBKZjxQSqTBxW"
SUBNET_ID="2W9boARgCWL25z6pMFNtkCfNA5v28VGg9PmBgUJfuKndEdhrvw"
RPC_URL="http://${NODE_IP}:${NODE_PORT}/ext/bc/${BLOCKCHAIN_ID}/rpc"
PLATFORM_URL="http://${NODE_IP}:9650/ext/bc/P"
INFO_URL="http://${NODE_IP}:9650/ext/info"

# 出力設定
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="/home/$USER/gowenet-metrics/data"
LOG_DIR="/home/$USER/gowenet-metrics/logs"
BLOCKCHAIN_FILE="${OUTPUT_DIR}/blockchain_${TIMESTAMP}.csv"
RESOURCE_FILE="${OUTPUT_DIR}/resources_pi1_${TIMESTAMP}.csv"
LOG_FILE="${LOG_DIR}/pi1_collection.log"

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
log "GOWENET Pi1 Metrics Collection Started"
log "Node: $HOSTNAME ($NODE_IP:$NODE_PORT)"
log "Blockchain Output: $BLOCKCHAIN_FILE"
log "Resource Output: $RESOURCE_FILE"
log "Interval: ${INTERVAL}s, Duration: ${DURATION}s"
log "=========================================="

# ========================================
# ヘルスチェック
# ========================================

check_node() {
    local response=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      -H 'content-type:application/json' "$RPC_URL" 2>/dev/null)
    
    if echo "$response" | grep -q "result"; then
        log "✓ Node is accessible at $RPC_URL"
        return 0
    else
        log "✗ Cannot connect to node at $RPC_URL"
        return 1
    fi
}

if ! check_node; then
    log "ERROR: Node health check failed. Exiting."
    exit 1
fi

# ========================================
# CSVヘッダー作成
# ========================================

# ブロックチェーンメトリクス用ヘッダー
cat > "$BLOCKCHAIN_FILE" << 'HEADER'
timestamp,block_number,block_hash,block_timestamp,tx_count,gas_used,gas_limit,validator_count,avg_block_time,total_peers
HEADER

# リソースメトリクス用ヘッダー
cat > "$RESOURCE_FILE" << 'HEADER'
timestamp,node_name,cpu_percent,mem_used_mb,mem_percent,disk_used_gb,disk_percent,net_rx_mb,net_tx_mb,load_1m,load_5m,load_15m,processes
HEADER

log "CSV headers created"

# ========================================
# ブロックチェーンメトリクス収集関数
# ========================================

get_block_number() {
    local result=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      -H 'content-type:application/json' "$RPC_URL" 2>/dev/null)
    
    local hex=$(echo "$result" | jq -r '.result // "0x0"' 2>/dev/null)
    if [ -n "$hex" ] && [ "$hex" != "null" ]; then
        printf "%d\n" "$hex" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_block_info() {
    local block_num=$1
    local hex_num=$(printf '0x%x' "$block_num" 2>/dev/null)
    curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$hex_num\",false],\"id\":1}" \
      -H 'content-type:application/json' "$RPC_URL" 2>/dev/null | jq -c '.result // {}' 2>/dev/null
}

get_total_peers() {
    # 全ノードのピア数を合計（重複除く推定値）
    local pi1_peers=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"info.peers","params":{},"id":1}' \
      -H 'content-type:application/json' "http://192.168.3.86:9650/ext/info" 2>/dev/null | jq -r '.result.numPeers // 0')
    echo "$pi1_peers"
}

get_validator_count() {
    local result=$(curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"method\":\"platform.getCurrentValidators\",\"params\":{\"subnetID\":\"$SUBNET_ID\"},\"id\":1}" \
      -H 'content-type:application/json' "$PLATFORM_URL" 2>/dev/null)
    
    echo "$result" | jq -r '.result.validators | length // 0' 2>/dev/null || echo "0"
}

calculate_avg_block_time() {
    local current_block=$1
    local prev_block=$((current_block - 10))
    
    if [ $prev_block -lt 0 ]; then
        echo "0"
        return
    fi
    
    local current_info=$(get_block_info $current_block)
    local prev_info=$(get_block_info $prev_block)
    
    local current_ts=$(echo "$current_info" | jq -r '.timestamp // "0x0"' 2>/dev/null)
    local prev_ts=$(echo "$prev_info" | jq -r '.timestamp // "0x0"' 2>/dev/null)
    
    if [ -n "$current_ts" ] && [ -n "$prev_ts" ] && [ "$current_ts" != "null" ] && [ "$prev_ts" != "null" ]; then
        local current_dec=$(printf "%d\n" "$current_ts" 2>/dev/null || echo "0")
        local prev_dec=$(printf "%d\n" "$prev_ts" 2>/dev/null || echo "0")
        
        if [ $current_dec -gt 0 ] && [ $prev_dec -gt 0 ] && [ $current_dec -gt $prev_dec ]; then
            echo $(( (current_dec - prev_dec) / 10 ))
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# ========================================
# リソースメトリクス収集関数
# ========================================

get_cpu_usage() {
    # 1秒間のCPU使用率を取得
    top -bn2 -d1 | grep "Cpu(s)" | tail -1 | awk '{print 100 - $8}' | cut -d'%' -f1
}

get_memory_stats() {
    # メモリ使用状況を取得
    free -m | awk 'NR==2 {printf "%d,%d", $3, ($3/$2)*100}'
}

get_disk_stats() {
    # ルートパーティションのディスク使用状況
    df -h / | awk 'NR==2 {gsub(/G/,""); printf "%s,%s", $3, $5}' | sed 's/%//'
}

get_network_stats() {
    # ネットワーク統計（累積値をMBで）
    local interface="eth0"  # または wlan0
    if ! ip link show $interface &>/dev/null; then
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
    fi
    
    if [ -n "$interface" ]; then
        local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
        echo "$((rx_bytes / 1048576)),$((tx_bytes / 1048576))"
    else
        echo "0,0"
    fi
}

get_load_average() {
    # ロードアベレージ
    uptime | awk '{gsub(/,/,""); print $(NF-2), $(NF-1), $NF}'
}

get_process_count() {
    # avalanchegoプロセス数
    pgrep -c avalanchego || echo "0"
}

# ========================================
# メイン収集ループ
# ========================================

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
ITERATION=0
PREV_BLOCK=0

log "Starting metrics collection loop..."

while [ $(date +%s) -lt $END_TIME ]; do
    ITERATION=$((ITERATION + 1))
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ========================================
    # ブロックチェーンメトリクス収集
    # ========================================
    BLOCK_NUM=$(get_block_number)
    
    if [ "$BLOCK_NUM" -gt 0 ]; then
        BLOCK_INFO=$(get_block_info $BLOCK_NUM)
        BLOCK_HASH=$(echo "$BLOCK_INFO" | jq -r '.hash // "N/A"' | cut -c1-16)  # ハッシュを短縮
        BLOCK_TS=$(echo "$BLOCK_INFO" | jq -r '.timestamp // "0x0"' 2>/dev/null)
        BLOCK_TS_DEC=$(printf "%d\n" "$BLOCK_TS" 2>/dev/null || echo "0")
        TX_COUNT=$(echo "$BLOCK_INFO" | jq -r '.transactions | length // 0' 2>/dev/null)
        GAS_USED=$(echo "$BLOCK_INFO" | jq -r '.gasUsed // "0x0"' 2>/dev/null)
        GAS_USED_DEC=$(printf "%d\n" "$GAS_USED" 2>/dev/null || echo "0")
        GAS_LIMIT=$(echo "$BLOCK_INFO" | jq -r '.gasLimit // "0x0"' 2>/dev/null)
        GAS_LIMIT_DEC=$(printf "%d\n" "$GAS_LIMIT" 2>/dev/null || echo "0")
    else
        BLOCK_HASH="N/A"
        BLOCK_TS_DEC="0"
        TX_COUNT="0"
        GAS_USED_DEC="0"
        GAS_LIMIT_DEC="0"
    fi
    
    VALIDATOR_COUNT=$(get_validator_count)
    AVG_BLOCK_TIME=$(calculate_avg_block_time $BLOCK_NUM)
    TOTAL_PEERS=$(get_total_peers)
    
    # ブロックチェーンデータをCSVに出力（新しいブロックの時のみ）
    if [ "$BLOCK_NUM" -ne "$PREV_BLOCK" ]; then
        echo "${TS},${BLOCK_NUM},${BLOCK_HASH},${BLOCK_TS_DEC},${TX_COUNT},${GAS_USED_DEC},${GAS_LIMIT_DEC},${VALIDATOR_COUNT},${AVG_BLOCK_TIME},${TOTAL_PEERS}" >> "$BLOCKCHAIN_FILE"
        PREV_BLOCK=$BLOCK_NUM
    fi
    
    # ========================================
    # リソースメトリクス収集
    # ========================================
    CPU_USAGE=$(get_cpu_usage)
    MEM_STATS=$(get_memory_stats)
    DISK_STATS=$(get_disk_stats)
    NET_STATS=$(get_network_stats)
    LOAD_AVG=$(get_load_average)
    PROCESS_COUNT=$(get_process_count)
    
    # リソースデータをCSVに出力
    echo "${TS},pi1,${CPU_USAGE},${MEM_STATS},${DISK_STATS},${NET_STATS},${LOAD_AVG},${PROCESS_COUNT}" >> "$RESOURCE_FILE"
    
    # ログ出力（10イテレーションごと）
    if [ $((ITERATION % 10)) -eq 0 ]; then
        log "Iteration $ITERATION: Block #$BLOCK_NUM, CPU: ${CPU_USAGE}%, Validators: $VALIDATOR_COUNT"
    fi
    
    sleep $INTERVAL
done

# ========================================
# 完了処理
# ========================================

BLOCKCHAIN_RECORDS=$(wc -l < "$BLOCKCHAIN_FILE")
RESOURCE_RECORDS=$(wc -l < "$RESOURCE_FILE")

log "=========================================="
log "Metrics collection completed"
log "Blockchain records: $((BLOCKCHAIN_RECORDS - 1))"
log "Resource records: $((RESOURCE_RECORDS - 1))"
log "=========================================="

exit 0
