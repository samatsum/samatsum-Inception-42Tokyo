# DEV_DOC - 開発者向け技術ドキュメント

本ドキュメントでは、Inceptionインフラストラクチャのセットアップ、ビルド、管理、および内部アーキテクチャの理解方法について説明する。後任のエンジニアやピア評価者（レビュアー）が保守および拡張を容易に行えるよう設計されている。

---

## 1. 環境構築（スクラッチから）

### 1.1 前提条件
- Docker EngineおよびDocker Composeがインストールされていること。
- `make` ユーティリティが利用可能であること。
- ホストマシンに必要なデータディレクトリが存在すること。

### 1.2 ホストの名前解決
ローカルでのテストを可能にするため、プロジェクトのドメインをローカルのループバックアドレスにマッピングする。
```bash
# /etc/hosts に追記する（sudoが必要）
127.0.0.1   samatsum.42.fr
```

### 1.3 設定ファイル (`.env`)
冪等性を確保し、手動のコピペミスを排除するため、以下のコマンドを使用して `.env` ファイルを生成する。これにより、制限された権限で `srcs/` ディレクトリにファイルが作成される。

```bash
mkdir -p srcs

cat << 'EOF' > srcs/.env
# .env
DOMAIN_NAME=samatsum.42.fr
# MYSQL
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
# WordPress
WP_TITLE=inception
## admin
WP_ADMIN_USER=supervisor
WP_ADMIN_EMAIL=zunandkun@gmail.com
## viewer
WP_NORMAL_USER=viewer
WP_NORMAL_EMAIL=matsumotosanshiro@gmail.com
## FTPServer
FTP_USER=ftpuser
EOF

chmod 600 srcs/.env
```

### 1.4 シークレット管理
最大限のセキュリティを達成するため、パスワードを標準の環境変数として渡してはならない。代わりに、`secrets/` ディレクトリ内のファイルとして保存し、実行時にコンテナへマウントする。アプリケーションは `_FILE` 環境変数（例: `MYSQL_PASSWORD_FILE`）を介してこれらを読み込むよう設定されている。

```bash
mkdir -p secrets

echo -n "db_pass_here" > secrets/db_password.txt
echo -n "db_root_pass_here" > secrets/db_root_password.txt
echo -n "wp_admin_pass_here" > secrets/credentials.txt
echo -n "wp_normal_pass_here" > secrets/wp_normal_password.txt

chmod 600 secrets/*.txt
```

---

## 2. ビルドと起動

### 2.1 Makefileターゲット

ルートディレクトリの `Makefile` は、運用効率化のためにDocker Composeコマンドを抽象化している。

| ターゲット | 説明 |
|--------|-------------|
| `make up` | イメージをビルドし（必要な場合）、すべてのコンテナを起動する。 |
| `make build` | キャッシュを使用せず、Dockerイメージを強制的に再ビルドする。 |
| `make down` | コンテナを停止し、ネットワークを削除する。 |
| `make stop` | ネットワークを破棄せずにコンテナをクリーンに停止する。 |
| `make start` | 停止したコンテナを起動する。 |
| `make logs` | すべてのコンテナの標準出力・標準エラー出力を追跡する。 |
| `make fclean`| 完全なクリーンアップ: コンテナ、イメージ、ネットワーク、およびデータボリュームを削除する。 |

### 2.2 初回起動
ルートディレクトリに移動して以下を実行する。
```bash
make up
```

---

## 3. コンテナのライフサイクルとアーキテクチャの詳細

すべてのサービスにおいて、「1コンテナ1プロセス（Single Responsibility Principle）」および「フォアグラウンド実行」の原則を厳格に適用している。

### 3.1 スタートアップフローとバックグラウンド実行の禁止
すべてのサービスは、シェルをPID 1として置き換えるためにフォアグラウンドで実行されなければならない。これにより、ゾンビプロセスを防ぎ、グレースフルシャットダウンのためのシグナル（`SIGTERM` など）を正確に捕捉できる。

- **MariaDB**: 
  - `/var/lib/mysql/mysql` が存在しない場合、`entrypoint.sh` がデータベースを初期化する。
  - 最終実行: `exec mariadbd --user=mysql` (フォアグラウンド)。
- **WordPress (PHP-FPM)**: 
  - **競合状態（レースコンディション）の防止**: コアのインストールを試みる前に、スクリプト内で `wp db check` をループ実行し、MariaDBが完全に準備されるまでポーリングを行う。
  - 最終実行: `exec php-fpm8.3 -F` (フォアグラウンド)。
- **NGINX**: 
  - 最終実行: `nginx -g "daemon off;"` (フォアグラウンド)。

### 3.2 ポート80の厳格な拒否
堅牢なセキュリティを確保し、HTTPSを強制するため、単にポート80（HTTP）を非公開にするだけでなく、NGINXの設定で明示的に破棄/拒否（drop/reject）している。リクエストがサーバーに到達した場合でも、サーバーブロックレベルで明示的に拒否され、わずかなパフォーマンスのオーバーヘッドよりも厳格なプロトコル遵守を優先している。

### 3.3 スクリプトの安全性（フェイルファスト）
すべてのエントリポイントスクリプト（`script.sh` / `entrypoint.sh`）は以下で開始される。
```bash
set -uo pipefail
```
これにより、何らかの障害（例：シークレットファイルの欠落やDBのping失敗）が発生した場合、コンテナが不安定な状態で実行され続けることを防ぎ、スクリプトを即座にクラッシュさせることが保証される（Google Shell Style Guide準拠の実装）。

---

## 4. データストレージと永続化

プロジェクトのデータは、コンテナの再起動やVMの再起動をまたいで永続化されなければならない。これは、ホストのバインドマウントをバックエンドとするDockerの名前付きボリューム（Named Volumes）を使用して実現される。

### 4.1 ボリューム設計

データは厳密に分離され、ホストマシンの `/home/samatsum/data/` に保存される。

```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/samatsum/data/mariadb
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/samatsum/data/wordpress
```
**なぜこのアプローチをとるのか？**

`bind` オプション付きの `local` ボリュームを使用することで、Dockerのボリューム管理の抽象化を維持しつつ、データがホストファイルシステムのどこに存在するかを強制できる。これにより、`docker-compose down` 実行時のデータ消失を防ぐ。

### 4.2 完全なリセット (fclean)

```bash
make fclean
```

---