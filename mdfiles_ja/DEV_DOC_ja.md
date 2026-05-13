# DEV_DOC - 開発者向けセットアップガイド

このドキュメントでは、開発者がローカル環境でInceptionインフラストラクチャをクローン、セットアップ、および管理するための正確な手順を提供します。

---

## 1. 事前準備 (Prerequisites)

開始する前に、ホストマシン（Linux VM）が以下の要件を満たしていることを確認してください。このスタックは9つのコンテナを同時に実行するため、十分なリソースが必要です。

### 1.1 ハードウェアおよびOS要件

* **OS**: Ubuntu 22.04 LTS (Jammy Jellyfish) [カーネル 6.8.0以降]
* **アーキテクチャ**: x86_64
* **CPU**: マルチコアプロセッサ（5コアでテスト済み）
* **メモリ (RAM)**: **8GB推奨**（8GBでテスト済み）.
* **ストレージ**: 15〜20GBの空きディスク容量。

### 1.2 ソフトウェア要件

* **Git**: リポジトリのクローン用。
* **Docker Engine & Docker Compose (V2)**
* **Make**: セットアップ作業の自動化用。
* **Sudo/Root 権限**: `/etc/hosts` の編集、Dockerデーモンの再起動、およびローカルボリュームディレクトリの管理に必要です。

---

## 2. セットアップ手順 (Setup Procedure)

### ステップ 2.1: リポジトリのクローン

プロジェクトをローカルマシンにクローンし、ルートディレクトリに移動します。

```bash
git clone <your_repository_url> samatsum-inception
cd samatsum-inception

```

### ステップ 2.2: ホスト名の解決 (Host Resolution)

ブラウザからTLS証明書を使用してローカルテストを行えるように、プロジェクトのドメインをローカルループバックアドレス（127.0.0.1）にマッピングします。

```bash
# /etc/hosts に追記 (sudo権限が必要)
127.0.0.1   samatsum.42.fr

```

### ステップ 2.3: 設定ファイル (`.env`)

`srcs/` ディレクトリに、機密情報ではない設定変数を保持するための `.env` ファイルを生成します。

chmod 400 ha 所有者のみ読み取り可能（書き込み・実行不可)
```bash
mkdir -p srcs
cat << 'EOF' > srcs/.env
DOMAIN_NAME=samatsum.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
WP_TITLE=inception
WP_ADMIN_USER=supervisor
WP_ADMIN_EMAIL=zunandkun@gmail.com
WP_EDITER_USER=editer
WP_EDITER_EMAIL=matsumotosanshiro@gmail.com
FTP_USER=ftpuser
GRAFANA_ADMIN_USER=admin
EOF
chmod 400 srcs/.env

```

### ステップ 2.4: 秘密情報の管理 (Secrets Management)

パスワードは `.env` に保存しては**いけません**。
`secrets/` ディレクトリ（Gitの管理対象外）に保存してください。これらは実行時にコンテナ内へ安全にマウントされます。

chmod 400 ha 所有者のみ読み取り可能（書き込み・実行不可)
```bash
mkdir -p secrets
echo -n "db_pass_here" > secrets/db_password.txt
echo -n "db_root_pass_here" > secrets/db_root_password.txt
echo -n "wp_admin_pass_here" > secrets/credentials.txt
echo -n "wp_editer_pass_here" > secrets/wp_editer_password.txt
echo -n "ftp_pass_here" > secrets/ftp_password.txt
echo -n "grafana_pass_here" > secrets/grafana_password.txt
chmod 400 secrets/*.txt

```

---

## 3. Makefile の使用方法

ルートディレクトリにある `Makefile` は、複雑なセットアップや破棄の操作を抽象化します。

| ターゲット | アクション |
| --- | --- |
| `make up` | ホスト側のボリュームディレクトリを `chmod 755` で作成し、イメージをビルドして全コンテナを起動します。 |
| `make down` | コンテナを停止し、L3仮想ネットワークを破棄します。（ホスト上のデータは保持されます）。 |
| `make stop` | ネットワークを破棄せずに、コンテナプロセスを正常に停止（SIGTERM）させます。 |
| `make start` | `stop` 状態のコンテナを再開させます。 |
| `make logs` | 全コンテナの `stdout`/`stderr` ログをリアルタイムで表示します。 |
| `make status` | 全コンテナとその現在の状態を一覧表示します（`docker container ls -a`）。 |
| `make clean` | プロジェクトのコンテナ、イメージ、および孤立したネットワークを安全に削除します（`--remove-orphans`）。 |
| `make fclean` | `clean` を実行後、Dockerシステムのプルーン、名前付きボリュームの削除、および物理ホストデータ（`/home/samatsum/data`）を完全に削除します。 |
| `make emergency` | **[最終リセット]** Dockerデーモンを再起動し、すべてのグローバルコンテナを強制削除、システムをプルーンし、物理ホストデータを削除します。 |
| `make re` | 完全なリセットのため、`fclean` を実行した後に `up` を実行します。 |

**インフラを初めて起動する場合は、単に以下を実行してください:**

```bash
make up

```

---

## 4. Docker Compose コマンド

デバッグのために Makefile を介さずに操作する必要がある場合は、`srcs/docker-compose.yml` にある設定ファイルに対して生の `docker compose` コマンドを使用できます。

* **ビルドと実行 (バックグラウンド)**: `docker compose -f srcs/docker-compose.yml up --build -d`
* **コンテナの停止と削除**: `docker compose -f srcs/docker-compose.yml down`
* **ボリュームを含むすべての削除**: `docker compose -f srcs/docker-compose.yml down -v`
* **特定のコンテナのログ確認**: `docker compose -f srcs/docker-compose.yml logs -f wordpress`

---

## 5. データの永続化 (Data Persistence)

コンテナを破棄（`make down`）してもデータが消失しないように、このプロジェクトでは**ホストバインドマウント**によってバックアップされた Docker 名前付きボリュームを使用しています。

データは、`/home/samatsum/data/` 以下の3つの独立したホストディレクトリに厳格に分離されています。

1. **`/home/samatsum/data/mariadb`**: リレーショナルデータベースファイルを保存。
2. **`/home/samatsum/data/wordpress`**: WordPressのコアファイル、テーマ、アップロードされたメディアを保存。FTPコンテナと共有されます。
3. **`/home/samatsum/data/prometheus`**: Grafanaダッシュボード用の時系列メトリクスデータを保存。
