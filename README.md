# GOWENET Metrics Collection

GOWENETネットワークのパフォーマンスメトリクスを収集・分析するためのツール

## ディレクトリ構造

```
gowenet-metrics/
├── scripts/
│   ├── gowenet_metrics.sh    # 統合メトリクス収集スクリプト（Pi1-Pi4対応）
│   └── archive/              # 旧スクリプト（アーカイブ）
├── data/                     # 収集されたCSVデータ
├── logs/                     # 収集ログ
└── README.md                 # このファイル
```

## メインスクリプト

### `gowenet_metrics.sh` - 統合メトリクス収集スクリプト

**特徴:**
- ✅ **全ノード対応**: Pi1（daikon）、Pi2（tamago）、Pi3（tomato）、Pi4（tamanegi）
- ✅ **自動検出**: ホスト名から自動的にIPアドレスとポートを設定
- ✅ **包括的メトリクス**: ブロック情報、トランザクション、ピア数、バリデータ数など

**対応ノード:**
| ノード | ホスト名 | IPアドレス | ポート |
|--------|----------|------------|--------|
| Pi1 | daikon | 192.168.3.86 | 9654 |
| Pi2 | tamago | 192.168.3.75 | 9650 |
| Pi3 | tomato | 192.168.3.106 | 9650 |
| Pi4 | tamanegi | 192.168.3.73 | 9650 |

## 使い方

### 基本的な使用方法

```bash
cd /home/hirofj/gowenet-metrics/scripts
./gowenet_metrics.sh [interval] [duration]
```

**パラメータ:**
- `interval`: 収集間隔（秒）、デフォルト: 10秒
- `duration`: 収集期間（秒）、デフォルト: 300秒（5分）

### 使用例

```bash
# デフォルト設定で実行（10秒間隔、5分間）
./gowenet_metrics.sh

# 5秒間隔で10分間収集
./gowenet_metrics.sh 5 600

# 1秒間隔で1時間収集
./gowenet_metrics.sh 1 3600
```

### バックグラウンド実行

```bash
# バックグラウンドで実行
nohup ./gowenet_metrics.sh 10 3600 > /dev/null 2>&1 &

# ログを確認
tail -f ../logs/metrics_collection.log
```

## 収集されるメトリクス

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

## 出力ファイル

### データファイル (data/)

**ファイル命名規則:**
```
metrics_<hostname>_<YYYYMMDD>_<HHMMSS>.csv
```

**例:**
- `metrics_daikon_20251107_103000.csv` - Pi1のデータ
- `metrics_tamago_20251107_103000.csv` - Pi2のデータ
- `metrics_tomato_20251107_103000.csv` - Pi3のデータ
- `metrics_tamanegi_20251107_103000.csv` - Pi4のデータ

### ログファイル (logs/)

`metrics_collection.log` - 収集実行ログ

## データの確認

### 最新データの表示

```bash
# 最新5件のファイルをリスト
ls -lt /home/hirofj/gowenet-metrics/data/ | head -6

# 特定ノードの最新データ
ls -t /home/hirofj/gowenet-metrics/data/metrics_daikon_*.csv | head -1

# CSVデータの先頭10行を表示
head -10 /home/hirofj/gowenet-metrics/data/metrics_daikon_*.csv
```

### ログの確認

```bash
# リアルタイムでログ表示
tail -f /home/hirofj/gowenet-metrics/logs/metrics_collection.log

# 最新100行
tail -100 /home/hirofj/gowenet-metrics/logs/metrics_collection.log
```

## データ分析

収集したCSVデータは以下のツールで分析できます：

### Pythonでの分析例

```python
import pandas as pd
import matplotlib.pyplot as plt

# データ読み込み
df = pd.read_csv('metrics_daikon_20251107_103000.csv')

# ブロック番号の推移をプロット
plt.plot(df['timestamp'], df['block_number'])
plt.xlabel('Time')
plt.ylabel('Block Number')
plt.title('Block Production Over Time')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('block_production.png')
```

### 対応ツール

- **Excel / Google Sheets**: CSVを直接開いて分析
- **Python (pandas, matplotlib)**: データ分析・可視化
- **R**: 統計分析
- **Tableau / Power BI**: BI分析

## メンテナンス

### 古いデータの削除

```bash
# 30日以上前のデータを削除
find /home/hirofj/gowenet-metrics/data/ -name "metrics_*.csv" -mtime +30 -delete

# 特定ノードのデータのみ削除
find /home/hirofj/gowenet-metrics/data/ -name "metrics_daikon_*.csv" -mtime +30 -delete
```

### ディスク容量の確認

```bash
# 全体の容量
du -sh /home/hirofj/gowenet-metrics/

# ディレクトリごとの容量
du -sh /home/hirofj/gowenet-metrics/*/
```

### データのバックアップ

```bash
# tarアーカイブ作成
tar -czf gowenet-metrics-backup-$(date +%Y%m%d).tar.gz /home/hirofj/gowenet-metrics/data/

# 外部ストレージへコピー（例）
rsync -av /home/hirofj/gowenet-metrics/data/ /mnt/backup/gowenet-metrics/
```

## トラブルシューティング

### スクリプトが実行できない

```bash
# 実行権限を付与
chmod +x /home/hirofj/gowenet-metrics/scripts/gowenet_metrics.sh
```

### GOWENETノードに接続できない

```bash
# ノードのヘルスチェック
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H 'content-type:application/json' \
  http://192.168.3.86:9654/ext/bc/2tGwFCjwr3w6fW774ytz982h5Th9eiALrKFanmBKZjxQSqTBxW/rpc

# ノードプロセスの確認
ps aux | grep avalanchego | grep -v grep
```

### jqコマンドがない

```bash
# jqのインストール
sudo apt-get update
sudo apt-get install jq -y
```

### データが収集されない

1. ノードが起動しているか確認
2. RPC URLが正しいか確認
3. ログファイルでエラー確認: `tail -f logs/metrics_collection.log`

## 複数ノードでの同時収集

全ノードで同時にメトリクス収集を開始する例：

```bash
# Pi1で実行
ssh hirofj@192.168.3.86 "cd gowenet-metrics/scripts && nohup ./gowenet_metrics.sh 10 3600 &"

# Pi2で実行
ssh hirofj@192.168.3.75 "cd gowenet-metrics/scripts && nohup ./gowenet_metrics.sh 10 3600 &"

# Pi3で実行
ssh hirofj@192.168.3.106 "cd gowenet-metrics/scripts && nohup ./gowenet_metrics.sh 10 3600 &"

# Pi4で実行
ssh hirofj@192.168.3.73 "cd gowenet-metrics/scripts && nohup ./gowenet_metrics.sh 10 3600 &"
```

## 関連プロジェクト

- [GOWENET Block Explorer](../gowenet-explorer/) - ブロックチェーンエクスプローラー
- [Avalanche CLI](https://docs.avax.network/tooling/cli-guides/install-avalanche-cli) - Avalanche開発ツール

## アーカイブ

旧バージョンのスクリプトは `scripts/archive/` に保存されています：
- `collect_metrics.sh`
- `collect_metrics_gowenet.sh`
- `collect_metrics_pi1.sh`
- `collect_metrics_research.sh`

---

**Last Updated**: 2025-11-07  
**Version**: 2.0 (Unified Script)
