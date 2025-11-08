# GOWENET Metrics Collection

GOWENETネットワークのパフォーマンスメトリクスを収集・分析するツール

## 🚀 クイックスタート

```bash
# デフォルト設定で実行（10秒間隔、5分間）
cd ~/gowenet-metrics
./scripts/gowenet_metrics.sh

# バックグラウンドで1時間実行
nohup ./scripts/gowenet_metrics.sh 10 3600 > /dev/null 2>&1 &
```

## 📖 使い方

### 基本コマンド

```bash
./scripts/gowenet_metrics.sh [間隔] [継続時間]
```

**引数:**
- `間隔`: データ収集間隔（秒） デフォルト: 10秒
- `継続時間`: 収集期間（秒） デフォルト: 300秒（5分）

### 実行例

```bash
# ヘルプを表示
./scripts/gowenet_metrics.sh --help

# デフォルト設定（10秒間隔、5分間）
./scripts/gowenet_metrics.sh

# 5秒間隔で10分間収集
./scripts/gowenet_metrics.sh 5 600

# 1秒間隔で1時間収集
./scripts/gowenet_metrics.sh 1 3600

# バックグラウンドで実行
nohup ./scripts/gowenet_metrics.sh 10 3600 > /dev/null 2>&1 &
```

## 📊 収集されるメトリクス

| メトリクス | 説明 |
|-----------|------|
| `timestamp` | 収集時刻 |
| `node_name` | ノード名（ホスト名） |
| `node_ip` | ノードIPアドレス |
| `block_number` | 最新ブロック番号 |
| `block_hash` | ブロックハッシュ |
| `block_timestamp` | ブロックタイムスタンプ |
| `tx_count` | トランザクション数 |
| `gas_used` | 使用Gas量 |
| `gas_limit` | Gas制限 |
| `num_peers` | 接続ピア数 |
| `is_bootstrapped` | ブートストラップ完了状態 |
| `validator_count` | バリデータ数 |
| `avg_block_time` | 平均ブロック時間（秒） |

## 📁 出力ファイル

### データファイル

**保存先:** `~/gowenet-metrics/data/`

**ファイル命名規則:**
```
metrics_<hostname>_<YYYYMMDD>_<HHMMSS>.csv
```

**例:**
- `metrics_daikon_20251108_143000.csv`
- `metrics_tamago_20251108_143000.csv`

### ログファイル

**保存先:** `~/gowenet-metrics/logs/metrics_collection.log`

```bash
# ログをリアルタイム表示
tail -f ~/gowenet-metrics/logs/metrics_collection.log
```

## 🖥️ 対応ノード

スクリプトはホスト名から自動的にノード設定を検出します。

| ノード | ホスト名 | IPアドレス | ポート |
|--------|----------|------------|--------|
| Pi1 | daikon | 192.168.3.86 | 9654 |
| Pi2 | tamago | 192.168.3.75 | 9650 |
| Pi3 | tomato | 192.168.3.106 | 9650 |
| Pi4 | tamanegi | 192.168.3.73 | 9650 |

## 🔧 プロセス管理

### 実行状態の確認

```bash
# プロセス確認
ps aux | grep gowenet_metrics

# ログ確認
tail -f ~/gowenet-metrics/logs/metrics_collection.log
```

### プロセスの停止

```bash
# 実行中のプロセスを停止
pkill -f gowenet_metrics.sh
```

## 🐛 トラブルシューティング

### スクリプトが実行できない

```bash
# 実行権限を付与
chmod +x ~/gowenet-metrics/scripts/gowenet_metrics.sh
```

### ノード接続エラー

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

## 📂 ディレクトリ構造

```
gowenet-metrics/
├── scripts/
│   ├── gowenet_metrics.sh      # メインスクリプト
│   └── gowenet_metrics.sh.old  # バックアップ
├── data/                       # 収集されたCSVデータ
├── logs/                       # 実行ログ
└── README.md                   # このファイル
```

## 🧹 メンテナンス

### 古いデータの削除

```bash
# 30日以上前のデータを削除
find ~/gowenet-metrics/data -name "metrics_*.csv" -mtime +30 -delete
```

### データのバックアップ

```bash
# tar圧縮でバックアップ
tar -czf metrics-backup-$(date +%Y%m%d).tar.gz ~/gowenet-metrics/data/
```

## 📝 バージョン情報

- **Version:** 2.1
- **Last Updated:** 2025-11-08
- **New Features:** --help オプション追加

