#!/bin/bash

# GOWENET Blockchain Metrics Collection (Pi1 Only)
# ブロックチェーンメトリクス専用収集スクリプト

# ========================================
# ヘルプ表示
# ========================================
show_help() {
    cat << 'HELP'
GOWENET ブロックチェーンメトリクス収集スクリプト（Pi1専用）

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

    # リソース収集と同時実行（別ターミナルで）
    ./gowenet_metrics_pi1.sh &
    ./gowenet_resources.sh &

出力:
    ブロックチェーンメトリクス: ~/gowenet-metrics/data/blockchain_[タイムスタンプ].csv
    ログファイル: ~/gowenet-metrics/logs/blockchain_collection.log

注意:
    リソースメトリクスは gowenet_resources.sh を別途実行してください

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
LOG_FILE="${LOG_DIR}/blockchain_collection.log"

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
log "GOWENET Blockchain Metrics Collection Started"
log "Node: $HOSTNAME ($NODE_IP:$NODE_PORT)"
log "Output: $BLOCKCHAIN_FILE"
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

log "CSV header created"

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
# メイン収集ループ
# ========================================

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
ITERATION=0
PREV_BLOCK=0

log "Starting blockchain metrics collection..."

while [ $(date +%s) -lt $END_TIME ]; do
    ITERATION=$((ITERATION + 1))
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ブロックチェーンメトリクス収集
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
        
        # ログ出力（新ブロック時）
        log "New Block #$BLOCK_NUM detected - TX: $TX_COUNT, Validators: $VALIDATOR_COUNT"
    fi
    
    # 進捗ログ（30秒ごと）
    if [ $((ITERATION * INTERVAL % 30)) -eq 0 ]; then
        log "Status: Block #$BLOCK_NUM, Peers: $TOTAL_PEERS, Validators: $VALIDATOR_COUNT"
    fi
    
    sleep $INTERVAL
done

# ========================================
# 完了処理
# ========================================

BLOCKCHAIN_RECORDS=$(wc -l < "$BLOCKCHAIN_FILE")

log "=========================================="
log "Blockchain metrics collection completed"
log "Total records: $((BLOCKCHAIN_RECORDS - 1))"
log "Output file: $BLOCKCHAIN_FILE"
log "=========================================="

# サマリー表示
log "=== Collection Summary ==="
log "Duration: ${DURATION}s"
log "Interval: ${INTERVAL}s"
log "Final Block: $(tail -1 "$BLOCKCHAIN_FILE" | cut -d',' -f4)"
log "New Blocks Recorded: $((BLOCKCHAIN_RECORDS - 1))"
log "=========================="

exit 0