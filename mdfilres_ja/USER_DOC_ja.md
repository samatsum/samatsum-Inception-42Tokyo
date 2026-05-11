ご提示いただいた`USER_DOC.md`の内容を和訳しました。エンドユーザーや評価者がサービスを操作・検証するためのガイドであることを考慮し、手順が明確に伝わるよう構成しています。

---

# USER_DOC - ユーザー操作ガイド

このガイドは、エンドユーザーおよび管理者がInceptionインフラストラクチャを管理・検証するために必要な情報を提供します。ピアレビュー（相互評価）で求められる基本操作、サービスへのアクセス、および健全性確認の手順を網羅しています。

## 1. サービスアクセスポイント

すべてのサービスは、NGINXを介して **HTTPS (ポート 443)** でルーティングされます。通常のHTTPアクセス（ポート 80）は厳格に禁止されており、拒否されます。

| サービス | アクセスURL / プロトコル | 説明 |
| --- | --- | --- |
| **WordPress** | [https://samatsum.42.fr](https://www.google.com/search?q=https://samatsum.42.fr) | メインのCMSウェブサイト。 |
| **Adminer** | [https://samatsum.42.fr/adminer](https://www.google.com/search?q=https://samatsum.42.fr/adminer) | データベース管理GUI。 |
| **Static Site** | [https://samatsum.42.fr/site/](https://www.google.com/search?q=https://samatsum.42.fr/site/) | 独立したFlaskベースのポートフォリオサイト。 |
| **Grafana** | [https://samatsum.42.fr/grafana/](https://www.google.com/search?q=https://samatsum.42.fr/grafana/) | 監視ダッシュボード。 |
| **Prometheus** | [https://samatsum.42.fr/prometheus](https://www.google.com/search?q=https://samatsum.42.fr/prometheus) | メトリクス収集エンジン。 |
| **FTP** | `ftp://samatsum.42.fr` (ポート 21) | ファイル転送プロトコル。 |

---

## 2. 基本操作

プロジェクトのルートディレクトリで以下のコマンドを使用します。

### 2.1 インフラの起動

すべてのコンテナをビルドしてバックグラウンドで起動します。

```bash
make up

```

### 2.2 インフラの停止

データの永続性を維持したまま、実行中のコンテナをすべて停止します。

```bash
make stop

```

### 2.3 クリーンアップ

コンテナとネットワークを削除します（ボリュームは保持されます）。

```bash
make clean

```

---

## 3. 認証情報 (Credentials)

セキュリティ保護のため、パスワードは `.env` ではなく `secrets/` ディレクトリ内のファイルに保存されています。

* **WordPress 管理者**:
* ユーザー名: `WP_ADMIN_USER`
* パスワード: `secrets/credentials.txt` の内容


* **WordPress 一般ユーザー**:
* ユーザー名: `WP_NORMAL_USER`
* パスワード: `secrets/wp_normal_password.txt` の内容


* **MariaDB (DBユーザー)**:
* ユーザー名: `MYSQL_USER`
* パスワード: `secrets/db_password.txt` の内容


* **FTP ユーザー**:
* ユーザー名: `FTP_USER`
* パスワード: `secrets/ftp_password.txt` の内容


* **Grafana 管理者**:
* ユーザー名: `GRAFANA_ADMIN_USER`
* パスワード: `secrets/grafana_password.txt` の内容



---

## 4. 検証手順 (Health Checks)

### 4.1 SSL/TLS の確認

ブラウザで [https://samatsum.42.fr](https://www.google.com/search?q=https://samatsum.42.fr) を開き、URLの横にある鍵アイコンをクリックして、証明書が `samatsum.42.fr` に対して発行されていることを確認してください。

### 4.2 Adminer (データベースGUI)

[https://samatsum.42.fr/adminer](https://www.google.com/search?q=https://samatsum.42.fr/adminer) にアクセスし、以下でログインします。

* **System**: `MySQL`
* **Server**: `mariadb`
* **Username**: `wpuser`
* **Password**: `secrets/db_password.txt` の内容

### 4.3 Redis (オブジェクトキャッシュ)

WordPressがRedisコンテナと通信しているか確認します。

```bash
docker exec -it wordpress wp redis status --path=/var/www/html --allow-root

```

**成功指標**: 出力に `Status: Connected` と表示されること。

### 4.4 FTP (ボリューム共有)

FTPサーバーが共有ボリュームを操作できるか確認します。

1. CLI経由で接続: `ftp -p samatsum.42.fr` (パッシブモードを使用)。
2. `ftpuser` としてログインし、`ls` を実行。
3. `wp-config.php` などのコアファイルが表示されることを確認。

### 4.5 監視パイプライン (Prometheus & Grafana)

1. **Prometheus**: [https://samatsum.42.fr/prometheus/targets](https://www.google.com/search?q=https://samatsum.42.fr/prometheus/targets) にアクセスし、状態が緑色の **UP** であることを確認。
2. **Grafana**: [https://samatsum.42.fr/grafana/](https://www.google.com/search?q=https://samatsum.42.fr/grafana/) にアクセス。「WordPress Monitoring」ダッシュボードを開き、NGINXのリクエスト数やPHP-FPMのプロセス数のリアルタイムグラフを確認。

### 4.6 静的サイト (Flask)

[https://samatsum.42.fr/site/](https://www.google.com/search?q=https://samatsum.42.fr/site/) にアクセスし、Pythonベースのサイトが独立して表示されることを確認。