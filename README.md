# GOWENET Metrics Collection

GOWENETネットワークのブロックチェーンメトリクスとリソースメトリクスを収集・分析するツール

## 📋 概要

このツールは2つのスクリプトで構成されています：

1. **gowenet_blockchain.sh** - ブロックチェーンメトリクス収集（Pi1のみ）
2. **gowenet_resources.sh** - リソースメトリクス収集（全ノード）

## 🚀 クイックスタート

### Pi1 (daikon) での実行

```bash
cd ~/gowenet-metrics

# ブロックチェーンメトリクス収集（バックグラウンド）
nohup ./scripts/gowenet_blockchain.sh 10 3600 > /dev/null 2>&1 &

# リソースメトリクス収集（バックグラウンド）
nohup ./scripts/gowenet_resources.sh 10 3600 > /dev/null 2>&1 &
```

### Pi2-Pi4 (tamago, tomato, tamanegi) での実行

```bash
cd ~/gowenet-metrics

# リソースメトリクス収集のみ
nohup ./scripts/gowenet_resources.sh 10 3600 > /dev/null 2>&1 &
```

## 📖 詳細な使い方

### 1. ブロックチェーンメトリクス収集（Pi1専用）

**コマンド:**
```bash
./scripts/gowenet_blockchain.sh [間隔] [継続時間]
```

**引数:**
- `間隔`: データ収集間隔（秒） デフォルト: 10秒
- `継続時間`: 収集期間（秒） デフォルト: 300秒（5分）

**実行例:**
```bash
# ヘルプを表示
./scripts/gowenet_blockchain.sh --help

# デフォルト設定（10秒間隔、5分間）
./scripts/gowenet_blockchain.sh

# 5秒間隔で1時間収集
./scripts/gowenet_blockchain.sh 5 3600

# バックグラウンドで実行
nohup ./scripts/gowenet_blockchain.sh 10 3600 > /dev/null 2>&1 &
```

### 2. リソースメトリクス収集（全ノード）

**コマンド:**
```bash
./scripts/gowenet_resources.sh [間隔] [継続時間]
```

**引数:**
- `間隔`: データ収集間隔（秒） デフォルト: 10秒
- `継続時間`: 収集期間（秒） デフォルト: 300秒（5分）

**実行例:**
```bash
# ヘルプを表示
./scripts/gowenet_resources.sh --help

# デフォルト設定（10秒間隔、5分間）
./scripts/gowenet_resources.sh

# 5秒間隔で1時間収集
./scripts/gowenet_resources.sh 5 3600

# バックグラウンドで実行
nohup ./scripts/gowenet_resources.sh 10 3600 > /dev/null 2>&1 &
```

## 📊 収集されるメトリクス

### ブロックチェーンメトリクス（Pi1のみ）

| メトリクス | 説明 |
|-----------|------|
| `timestamp` | 収集時刻 |
| `block_number` | 最新ブロック番号 |
| `block_hash` | ブロックハッシュ |
| `block_timestamp` | ブロックタイムスタンプ |
| `tx_count` | トランザクション数 |
| `gas_used` | 使用Gas量 |
| `gas_limit` | Gas制限 |
| `validator_count` | バリデータ数 |
| `avg_block_time` | 平均ブロック時間（秒） |
| `total_peers` | 接続ピア数 |

### リソースメトリクス（全ノード）

| メトリクス | 説明 |
|-----------|------|
| `timestamp` | 収集時刻 |
| `node_name` | ノード名（ホスト名） |
| `cpu_percent` | CPU使用率（%） |
| `mem_used_mb` | 使用メモリ（MB） |
| `mem_total_mb` | 総メモリ（MB） |
| `mem_percent` | メモリ使用率（%） |
| `swap_used_mb` | スワップ使用量（MB） |
| `swap_percent` | スワップ使用率（%） |
| `disk_used_gb` | ディスク使用量（GB） |
| `disk_total_gb` | 総ディスク容量（GB） |
| `disk_percent` | ディスク使用率（%） |
| `net_rx_mb` | ネットワーク受信（MB） |
| `net_tx_mb` | ネットワーク送信（MB） |
| `load_1m` | 1分間のロードアベレージ |
| `load_5m` | 5分間のロードアベレージ |
| `load_15m` | 15分間のロードアベレージ |
| `processes` | プロセス数 |
| `avalanche_pids` | avalanchegoプロセスID |
| `response_time_ms` | RPC応答時間（ms） |
| `temp_celsius` | CPU温度（℃） |

## 📁 出力ファイル

### データファイル

**保存先:** `~/gowenet-metrics/data/`

**ファイル命名規則:**

1. ブロックチェーンメトリクス（Pi1のみ）:
   ```
   blockchain_<YYYYMMDD>_<HHMMSS>.csv
   ```
   例: `blockchain_20251109_110057.csv`

2. リソースメトリクス（全ノード）:
   ```
   resources_<hostname>_<YYYYMMDD>_<HHMMSS>.csv
   ```
   例: 
   - `resources_daikon_20251109_110151.csv`
   - `resources_tamago_20251109_110151.csv`
   - `resources_tomato_20251109_110151.csv`
   - `resources_tamanegi_20251109_110151.csv`

### ログファイル

**保存先:**
- ブロックチェーン: `~/gowenet-metrics/logs/blockchain_collection.log`
- リソース: `~/gowenet-metrics/logs/resource_collection.log`

```bash
# ログをリアルタイム表示
tail -f ~/gowenet-metrics/logs/blockchain_collection.log
tail -f ~/gowenet-metrics/logs/resource_collection.log
```

## 🖥️ 対応ノード

スクリプトはホスト名から自動的にノード設定を検出します。

| ノード | ホスト名 | IPアドレス | ポート | 役割 |
|--------|----------|------------|--------|------|
| Pi1 | daikon | 192.168.3.86 | 9654 | ブロックチェーン収集 + リソース収集 |
| Pi2 | tamago | 192.168.3.75 | 9650 | リソース収集のみ |
| Pi3 | tomato | 192.168.3.106 | 9650 | リソース収集のみ |
| Pi4 | tamanegi | 192.168.3.73 | 9650 | リソース収集のみ |

## 🔧 プロセス管理

### 実行状態の確認

```bash
# ブロックチェーン収集プロセス確認
ps aux | grep gowenet_metrics_pi1

# リソース収集プロセス確認
ps aux | grep gowenet_resources

# すべてのメトリクス収集プロセス確認
ps aux | grep gowenet

# ログ確認
tail -f ~/gowenet-metrics/logs/blockchain_collection.log
tail -f ~/gowenet-metrics/logs/resource_collection.log
```

### プロセスの停止

```bash
# ブロックチェーン収集停止
pkill -f gowenet_blockchain.sh

# リソース収集停止
pkill -f gowenet_resources.sh

# すべての収集停止
pkill -f "gowenet_metrics\|gowenet_resources"
```

### データファイルの確認

```bash
# 最新のデータファイルを確認
ls -lht ~/gowenet-metrics/data/ | head -10

# 最新のブロックチェーンデータを表示
tail -5 $(ls -t ~/gowenet-metrics/data/blockchain_*.csv | head -1)

# 最新のリソースデータを表示
tail -5 $(ls -t ~/gowenet-metrics/data/resources_*.csv | head -1)
```

## 🐛 トラブルシューティング

### スクリプトが実行できない

```bash
# 実行権限を付与
chmod +x ~/gowenet-metrics/scripts/gowenet_blockchain.sh
chmod +x ~/gowenet-metrics/scripts/gowenet_resources.sh
```

### ノード接続エラー（Pi1）

```bash
# ノードの健全性を確認
curl -X POST --data '{
    "jsonrpc":"2.0",
    "id"     :1,
    "method" :"eth_blockNumber",
    "params" :[]
}' -H 'content-type:application/json;' http://192.168.3.86:9654/ext/bc/2tGwFCjwr3w6fW774ytz982h5Th9eiALrKFanmBKZjxQSqTBxW/rpc
```

### jqがインストールされていない

```bash
sudo apt-get update
sudo apt-get install jq -y
```

### データが収集されない

```bash
# ログを確認
tail -50 ~/gowenet-metrics/logs/blockchain_collection.log
tail -50 ~/gowenet-metrics/logs/resource_collection.log

# プロセス状態を確認
ps aux | grep gowenet
```

## 📂 ディレクトリ構造

```
gowenet-metrics/
├── scripts/
│   ├── gowenet_blockchain.sh      # ブロックチェーンメトリクス収集（Pi1専用）
│   ├── gowenet_resources.sh        # リソースメトリクス収集（全ノード）
│   ├── gowenet_metrics.sh          # 旧統合版（廃止予定）
│   └── archive/                    # アーカイブ
├── data/                           # 収集されたCSVデータ
│   ├── blockchain_*.csv            # ブロックチェーンデータ
│   └── resources_*.csv             # リソースデータ
├── logs/                           # 実行ログ
│   ├── blockchain_collection.log   # ブロックチェーン収集ログ
│   └── resource_collection.log     # リソース収集ログ
└── README.md                       # このファイル
```

## 🧹 メンテナンス

### 古いデータの削除

```bash
# 30日以上前のデータを削除
find ~/gowenet-metrics/data -name "*.csv" -mtime +30 -delete

# ログファイルのローテーション
find ~/gowenet-metrics/logs -name "*.log" -size +100M -exec mv {} {}.old \;
```

### データのバックアップ

```bash
# tar圧縮でバックアップ
tar -czf metrics-backup-$(date +%Y%m%d).tar.gz ~/gowenet-metrics/data/

# 特定期間のデータをバックアップ
tar -czf metrics-blockchain-$(date +%Y%m%d).tar.gz ~/gowenet-metrics/data/blockchain_*.csv
tar -czf metrics-resources-$(date +%Y%m%d).tar.gz ~/gowenet-metrics/data/resources_*.csv
```

### データの統計情報

```bash
# データファイル数を確認
echo "Blockchain files: $(ls ~/gowenet-metrics/data/blockchain_*.csv 2>/dev/null | wc -l)"
echo "Resource files: $(ls ~/gowenet-metrics/data/resources_*.csv 2>/dev/null | wc -l)"

# データサイズを確認
du -sh ~/gowenet-metrics/data/
```

## 📊 データ分析例

### ブロックチェーンデータの確認

```bash
# 最新のブロック情報
tail -1 $(ls -t ~/gowenet-metrics/data/blockchain_*.csv | head -1)

# ブロック数の推移
awk -F, 'NR>1 {print $2}' ~/gowenet-metrics/data/blockchain_*.csv | sort -n | tail -10
```

### リソースデータの確認

```bash
# 各ノードの平均CPU使用率
for node in daikon tamago tomato tamanegi; do
    file=$(ls -t ~/gowenet-metrics/data/resources_${node}_*.csv 2>/dev/null | head -1)
    if [ -f "$file" ]; then
        avg=$(awk -F, 'NR>1 {sum+=$3; count++} END {print sum/count}' "$file")
        echo "$node: ${avg}%"
    fi
done
```

## 📝 バージョン情報

- **Version:** 3.0
- **Last Updated:** 2025-11-09
- **Major Changes:** 
  - ブロックチェーンメトリクスとリソースメトリクスを分離
  - Pi1でブロックチェーン収集、全ノードでリソース収集
  - データ重複を排除し、効率的な収集を実現

## 🤝 サポート

問題が発生した場合は、ログファイルを確認してください：
- `~/gowenet-metrics/logs/blockchain_collection.log`
- `~/gowenet-metrics/logs/resource_collection.log`
