# GOWENET Metrics Collection System

GOWENETブロックチェーンネットワークのメトリクス収集システム

## システム構成

### ノード構成

| デバイス | ホスト名 | IPアドレス | ポート | 役割 |
|---------|---------|-----------|-------|------|
| Pi1 | daikon | 192.168.3.86 | 9654 | ブロックチェーン収集 + MQTT Subscriber |
| Pi2 | tamago | 192.168.3.75 | 9650 | リソース収集（MQTT送信） |
| Pi3 | tomato | 192.168.3.106 | 9650 | リソース収集（MQTT送信） |
| Pi4 | tamanegi | 192.168.3.73 | 9650 | リソース収集（MQTT送信） |

### データフロー

```
Pi2-Pi4 (データ送信)
    ↓ MQTT (gowenet/metrics/*)
Pi1 (MQTT Subscriber + データ収集)
    ↓
CSVファイル保存 (data/)
```

## 使用方法

### 1. 実験開始前の準備（Pi1: daikon）

MQTTサブスクライバーを起動してデータ受信の準備：

```bash
./scripts/gowenet_mqtt_subscriber.sh start
```

起動時刻が自動的にファイル名に使用されます（例：`resources_tomato_20251110_104530.csv`）

### 2. 各ノードでメトリクス収集開始

#### Pi1 (daikon) - ブロックチェーンメトリクス収集

```bash
./collectMetrics_pi1.sh
```

または手動で：

```bash
nohup ./scripts/gowenet_blockchain.sh 10 3600 > /dev/null 2>&1 &
nohup ./scripts/gowenet_resources.sh 10 3600 > /dev/null 2>&1 &
```

#### Pi2-Pi4 (tamago, tomato, tamanegi) - リソースメトリクス収集

```bash
./collectMetrics_piX.sh
```

または手動で：

```bash
nohup ./scripts/gowenet_resources_mqtt.sh 10 3600 > /dev/null 2>&1 &
```

### 3. 実験終了（Pi1: daikon）

MQTTサブスクライバーを停止：

```bash
./scripts/gowenet_mqtt_subscriber.sh stop
```

### サブスクライバーの管理コマンド

```bash
# 起動
./scripts/gowenet_mqtt_subscriber.sh start

# 停止
./scripts/gowenet_mqtt_subscriber.sh stop

# 状態確認
./scripts/gowenet_mqtt_subscriber.sh status
```

## スクリプト詳細

### ブロックチェーンメトリクス収集（Pi1のみ）

```bash
./scripts/gowenet_blockchain.sh [間隔] [継続時間]
```

- **間隔**: メトリクス収集間隔（秒）デフォルト: 10秒
- **継続時間**: 収集継続時間（秒）デフォルト: 300秒（5分）

収集データ：
- ブロック高
- トランザクション数
- ガス使用量
- レスポンス時間
- タイムスタンプ

### リソースメトリクス収集（全ノード）

#### Pi1 (ローカル収集)

```bash
./scripts/gowenet_resources.sh [間隔] [継続時間]
```

#### Pi2-Pi4 (MQTT送信)

```bash
./scripts/gowenet_resources_mqtt.sh [間隔] [継続時間]
```

収集データ：
- CPU使用率
- メモリ使用量
- ディスク使用量
- ネットワーク送受信量
- システム負荷
- Avalancheプロセス数
- 温度
- RPCレスポンス時間

### MQTT Subscriber（Pi1のみ）

```bash
./scripts/gowenet_mqtt_subscriber.sh {start|stop|status}
```

機能：
- Pi2-Pi4からのメトリクスをMQTT経由で受信
- 起動時刻でファイル名を生成
- ホスト名ごとにCSVファイルを作成
- バックグラウンドで動作

## 出力ファイル

### データファイル（`~/gowenet-metrics/data/`）

#### ブロックチェーンメトリクス（Pi1のみ）
- `blockchain_YYYYMMDD_HHMMSS.csv`

#### リソースメトリクス（全ノード）
- `resources_daikon_YYYYMMDD_HHMMSS.csv` (Pi1 - ローカル)
- `resources_tamago_YYYYMMDD_HHMMSS.csv` (Pi2 - MQTT)
- `resources_tomato_YYYYMMDD_HHMMSS.csv` (Pi3 - MQTT)
- `resources_tamanegi_YYYYMMDD_HHMMSS.csv` (Pi4 - MQTT)

**注意**: MQTT経由のファイルは、全て同じタイムスタンプ（Subscriber起動時刻）で作成されます。

### ログファイル（`~/gowenet-metrics/logs/`）

- `blockchain_collection.log` - ブロックチェーン収集ログ
- `resource_collection.log` - リソース収集ログ
- `mqtt_subscriber.log` - MQTTサブスクライバーログ

## MQTT設定

### ブローカー
- **ホスト**: 192.168.3.86 (Pi1: daikon)
- **ポート**: 1883

### トピック
- `gowenet/metrics/#` - 全メトリクスのルートトピック
- `gowenet/metrics/{hostname}` - 各ホストのメトリクスデータ
- `gowenet/metrics/{hostname}/status` - ステータスメッセージ

### QoS
- レベル1（最低1回配信保証）

## 実験ワークフロー例

### 1時間の実験を実施する場合

```bash
# 1. Pi1でMQTTサブスクライバー起動
ssh hirofj@daikon.local
./scripts/gowenet_mqtt_subscriber.sh start

# 2. Pi1でブロックチェーン収集開始
nohup ./scripts/gowenet_blockchain.sh 10 3600 > /dev/null 2>&1 &
nohup ./scripts/gowenet_resources.sh 10 3600 > /dev/null 2>&1 &

# 3. Pi2-Pi4で収集開始
ssh hirofj@tamago.local "./gowenet-metrics/scripts/gowenet_resources_mqtt.sh 10 3600"
ssh hirofj@tomato.local "./gowenet-metrics/scripts/gowenet_resources_mqtt.sh 10 3600"
ssh hirofj@tamanegi.local "./gowenet-metrics/scripts/gowenet_resources_mqtt.sh 10 3600"

# 4. 実験終了後、Pi1でサブスクライバー停止
ssh hirofj@daikon.local
./scripts/gowenet_mqtt_subscriber.sh stop
```

## トラブルシューティング

### MQTTサブスクライバーが起動しない

```bash
# 状態確認
./scripts/gowenet_mqtt_subscriber.sh status

# ログ確認
tail -f ~/gowenet-metrics/logs/mqtt_subscriber.log

# 強制停止して再起動
pkill -f mosquitto_sub
rm -f ~/gowenet-metrics/logs/mqtt_subscriber.pid
./scripts/gowenet_mqtt_subscriber.sh start
```

### データが保存されない

```bash
# MQTT接続確認
mosquitto_sub -h 192.168.3.86 -p 1883 -t "gowenet/metrics/#" -v

# 権限確認
ls -l ~/gowenet-metrics/data/
ls -l ~/gowenet-metrics/logs/
```

### ノードの収集スクリプトが動作しない

```bash
# ログ確認
tail -f ~/gowenet-metrics/logs/resource_collection.log

# プロセス確認
ps aux | grep gowenet

# 手動実行でエラー確認
./scripts/gowenet_resources_mqtt.sh 10 60
```

## 必要なパッケージ

### Pi1 (daikon)
- `mosquitto` - MQTTブローカー
- `mosquitto-clients` - MQTTクライアント
- `curl`, `jq` - API通信とJSON処理
- `bc` - 計算処理

### Pi2-Pi4 (tamago, tomato, tamanegi)
- `mosquitto-clients` - MQTTクライアント
- `curl`, `jq` - API通信とJSON処理
- `bc` - 計算処理

### インストールコマンド

```bash
# Pi1のみ
sudo apt-get update
sudo apt-get install -y mosquitto mosquitto-clients curl jq bc

# Pi2-Pi4
sudo apt-get update
sudo apt-get install -y mosquitto-clients curl jq bc
```

## バージョン情報

- **Version**: 4.0
- **Last Updated**: 2025-11-10
- **主な変更点**:
  - MQTTサブスクライバーにstart/stop/statusコマンドを追加
  - セッション管理をサブスクライバーの起動/停止で制御
  - ファイル名をサブスクライバー起動時刻で統一
  - start/endメッセージプロトコルを削除（シンプル化）

## ライセンス

このプロジェクトは教育・研究目的で使用されます。
