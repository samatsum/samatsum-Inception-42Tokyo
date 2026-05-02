# USER_DOC - ユーザー操作ガイド

本ドキュメントは、エンドユーザーおよび管理者がInceptionインフラストラクチャを操作するための必須情報を提供する。

## 1. サービス概要

本スタックは、追加の管理ツールおよび最適化ツールを備えた、フル機能のWordPress環境を提供する。

| サービス | 役割 | アクセス / プロトコル |
| :--- | :--- | :--- |
| **NGINX** | セキュアゲートウェイ (TLS 1.2/1.3) | `https://samatsum.42.fr` |
| **WordPress** | コンテンツ管理システム | NGINX経由 |
| **Adminer** | データベース管理ツール | `https://samatsum.42.fr/adminer` |
| **MariaDB** | リレーショナルデータベース | 内部アクセスのみ |
| **Redis** | オブジェクトキャッシュ (速度最適化) | 内部アクセスのみ |
| **FTP (vsftpd)** | ファイル転送サービス | `ftp://samatsum.42.fr` (ポート 21) |

---

## 2. プロジェクトの起動と停止

すべての操作は、プロジェクトルートに配置された `Makefile` を通じて管理される。

### インフラの起動
```bash
make up
```
*注: 初回実行時、システムは自動的にイメージをビルドし、データベースを初期化する。これには数分かかる場合がある。*

### インフラの停止
```bash
# データを保持したままコンテナを停止する
make down

# コンテナ、ネットワーク、およびすべての永続データを完全に削除する
make fclean
```

---

## 3. プラットフォームへのアクセス

### 3.1 WordPress Webサイト
- **メインサイト**: [https://samatsum.42.fr](https://samatsum.42.fr)
- **管理ダッシュボード**: [https://samatsum.42.fr/wp-admin](https://samatsum.42.fr/wp-admin)

### 3.2 データベース管理 (Adminer)
Adminerを使用すると、Webインターフェース経由でMariaDBデータベースを管理できる。
- **URL**: [https://samatsum.42.fr/adminer](https://samatsum.42.fr/adminer)
- **サーバー**: `mariadb`
- **ユーザー名/パスワード**: セクション4を参照。

### 3.3 FTPアクセス
FileZillaなどのFTPクライアントを使用して、WordPressのファイルを管理する。
- **ホスト**: `samatsum.42.fr`
- **ポート**: `21`

---

## 4. 認証情報の管理

セキュリティ上の理由から、パスワードは `.env` ファイルには保存されない。 これらは `srcs/secrets/` ディレクトリ内のプレーンテキストファイルに保存される。

| 認証情報 | パスの場所 |
| :--- | :--- |
| **WP管理者パスワード** | `srcs/secrets/credentials.txt` |
| **DBユーザーパスワード** | `srcs/secrets/db_password.txt` |
| **FTPユーザーパスワード** | `srcs/secrets/ftp_password.txt` |

*注: `srcs/secrets/` ディレクトリへのアクセスは、ホストユーザーのみに制限されている。*

---

## 5. サービスの稼働確認

すべてのサービスが正常に稼働していることを確認するため、以下の方法を使用する。

### 5.1 コンテナステータスの確認
以下のコマンドを実行し、すべてのサービスのステータスを確認する。
```bash
docker ps
```
すべてのサービスのステータスが `Up`（ヘルスチェックが実装されている場合は `Up (healthy)`）である必要がある。

### 5.2 リアルタイムログの監視
WordPressなどのサービスが応答しない場合は、ログを確認してエラーがないか調査する。
```bash
make logs
```

### 5.3 SSL/TLSの検証
`curl` を使用して、NGINXがHTTPS経由で正しくコンテンツを提供しているか検証できる。
```bash
## HTTPレスポンスヘッダーの取得（-I）
curl -I [https://samatsum.42.fr](https://samatsum.42.fr)
```

