*本プロジェクトは、samatsumによる42カリキュラムの一環として作成された。*

## 概要

Inceptionは、Docker Composeを用いてマルチサービスインフラを仮想化するシステム管理プロジェクトである。このアーキテクチャは厳格なマイクロサービスアプローチに従い、分離性、セキュリティ（TLS v1.2/v1.3）、および高可用性を確保している。

### アーキテクチャ（必須要件）

```text
┌─────────────────────────────────────────────────────────────┐
│                        VM (Host)                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Docker Compose                      │  │
│  │  ┌─────────┐    ┌─────────────┐    ┌─────────────┐    │  │
│  │  │  NGINX  │◀───│  WordPress  │◀───│   MariaDB   │    │  │
│  │  │ :443    │    │  php-fpm    │    │   :3306     │    │  │
│  │  │ TLS 1.2+│    │  wp-cli     │    │             │    │  │
│  │  └────┬────┘    └──────┬──────┘    └──────┬──────┘    │  │
│  │       │                │                  │           │  │
│  │       └────────────────┴──────────────────┘           │  │
│  │                 inception-network (bridge)            │  │
│  │                                                       │  │
│  │       [volumes: wordpress, mariadb]                   │  │
│  └──────────────── │  ───────────────────────────────────┘  │
│                    │                                        │ 
│                Bind (o: bind)                               │ 
│                    │                                        │
│          [device volumes]                                   │
│            /home/samatsum/data/wordpress                    │
│            /home/samatsum/data/mariadb                      │
└─────────────────────────────────────────────────────────────┘
```

### リクエストフロー
```text
Browser --[HTTPS]--> NGINX --[FastCGI]--> PHP-FPM --[SQL]--> MariaDB
                (443)               (9000)              (3306)
```

---

## 使用手順

### 前提条件
- Docker EngineおよびDocker Composeがインストールされていること。
- ドメイン `samatsum.42.fr` が `/etc/hosts` 内で `127.0.0.1` にマッピングされていること。
- `srcs/.env` に `.env` ファイルが準備されていること。
- `secrets/` ディレクトリにシークレットファイルが準備されていること。

### ビルドと実行

ルートディレクトリから以下のコマンドを実行する。
```bash
make up
```

### 一般的な操作（Makefile）

| ターゲット | 説明 |
|--------|-------------|
| `make up` | ローカルにボリュームを作成し、すべてのコンテナをビルドして起動する |
| `make down` | コンテナを停止・削除し、ネットワークを破棄する |
| `make stop` | ネットワークを破棄せずにコンテナをクリーンに停止する |
| `make start` | 停止したコンテナを起動する |
| `make logs` | すべてのコンテナの標準出力・標準エラー出力を追跡する |
| `make status` | すべてのコンテナとそのステータスを一覧表示する |
| `make clean` | コンテナとボリュームを削除する |
| `make fclean` | Dockerイメージ、ボリューム、ネットワークを含む完全なクリーンアップを行う |
| `make re` | 完全にクリーンアップして最初から再起動する（`fclean` -> `up`） |

---

## 設計の選択と技術比較

### 1. 仮想マシンとDockerの比較
仮想マシン（VM）はハードウェア層を仮想化するため、インスタンスごとに完全なゲストOSが必要となり、空間的および時間的コストが増加する。Dockerは名前空間（namespaces）とcgroupsを使用してOSカーネルレベルで仮想化を行うため、リソース消費を最小限に抑え、ほぼ瞬時の起動（O(1)のプロセス生成）を実現する。

### 2. シークレットと環境変数の比較
標準的な環境変数は `docker inspect` 経由で可視化されてしまう。本プロジェクトではDocker Secretsを使用し、メモリ常駐型ファイルシステム（`tmpfs`）の `/run/secrets/` にマウントすることで、機密データ（パスワード）がコンテナのディスクに一切触れないようにし、高いセキュリティを維持している。

### 3. Dockerネットワークとホストネットワークの比較
ホストネットワークを使用すると、コンテナとホストOS間の分離が失われる。専用のDockerブリッジネットワーク（`inception-network`）を実装することで、L3の分離を確保している。コンテナは内部DNS（サービス名）を介してのみ通信し、外部への公開はポート443のNGINXのみに厳密に制限されている。

### 4. Dockerボリュームとバインドマウントの比較
バインドマウントは特定のホストパスに依存するため、移植性が損なわれる。本プロジェクトでは、`local` ドライバと `o: bind` オプションを使用した名前付きボリュームを採用し、指定されたパス（`/home/samatsum/data`）にデータを永続化しつつ、Dockerが管理する抽象化とライフサイクルを維持している。

---

## リソース
- [Docker公式ドキュメント](https://docs.docker.com/)
- **AIの使用:** 本プロジェクトでは、AIをペアプログラミングのナビゲーターとして使用した。

AIはテクニカルメンターとして活用され、インフラストラクチャのアーキテクチャ監査、PID 1のシグナル伝播の最適化、およびbashスクリプト内での厳格なフェイルファスト実装の確保に役立てられた。すべてのロジックは手動で検証およびテストされている。

---

### 2. `DEV_DOC.md`

# DEV_DOC - 開発者向け技術ドキュメント

本ドキュメントでは、Inceptionインフラストラクチャを保守する開発者向けに、環境構築、アーキテクチャの決定事項、および操作コマンドについて詳述する。

## 環境構築

### 1. ホストの名前解決
ドメインをローカルのループバックアドレスにマッピングする。
```bash
# /etc/hosts に追記する（sudoが必要）
127.0.0.1   samatsum.42.fr
```

### 2. `.env` ファイルの準備
以下の変数を含む `srcs/.env` を作成する。
```env
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
```

### 3. シークレットの生成
パスワードはプロジェクトルートの `secrets/` ディレクトリに安全に保存する必要がある。このディレクトリはGitの管理対象外（`.gitignore`）となっている。
```bash
mkdir -p secrets

echo -n "db_pass_here" > secrets/db_password.txt
echo -n "db_root_pass_here" > secrets/db_root_password.txt
echo -n "wp_admin_pass_here" > secrets/credentials.txt
echo -n "wp_normal_pass_here" > secrets/wp_normal_password.txt
echo -n "ftp_pass_here" > secrets/ftp_password.txt
```

---

## コンテナのライフサイクルと管理

### ビルドと起動
```bash
make up
```
*注: `Makefile` は、Dockerがバインドする前に正しいホストディレクトリ（`/home/samatsum/data/*`）が `755` の権限で作成されていることを自動的に保証し、root所有権の競合を防ぐ。*

### 完全なクリーンアップ（全リセット）
すべてのコンテナ、イメージ、データボリュームを完全に消去するには以下のコマンドを実行する。
```bash
make fclean
```

---

## アーキテクチャの詳細

### PID 1とシグナル処理（グレースフルシャットダウン）
グレースフルシャットダウン（終了コード0）を保証し、`SIGKILL`（終了コード137）を排除するため、PID 1を動的に処理している。
- **コアサービス（MariaDB、NGINX、WordPress）**: `script.sh` の最後に `exec` コマンドを使用し、シェルプロセスをサービスデーモンに置き換えることで、`SIGTERM` を直接受信できるようにしている。
- **ボーナスサービス（Static-site、FTP）**: 単純なPythonサーバーや `vsftpd` はPID 1として実行されるように設計されていないため、`Dockerfile` で `tini` をインストールし、エントリポイント（`ENTRYPOINT ["/usr/bin/tini", "--", "/script.sh"]`）として使用することで、シグナルを転送し、ゾンビプロセスを適切に刈り取っている。

### スクリプトの安全性（フェイルファスト）
すべてのエントリポイントスクリプトでは、厳格なbash設定を使用している。
```bash
set -uo pipefail
```
これにより、コマンドが失敗した場合や未定義の変数がアクセスされた場合（例：シークレットのマウント忘れ）、不安定な状態で処理を続行するのではなく、スクリプトが即座にクラッシュすることが保証される。

### 競合状態（レースコンディション）の防止
`wordpress` の初期化スクリプトには堅牢なポーリング機構が実装されている。インストールのコマンドを実行する前に、リトライループ内で `wp db check` を使用して `mariadb` とのL7接続を確認することで、コンテナの並列起動時における競合状態を防いでいる。

---

### 3. `USER_DOC.md`

# USER_DOC - ユーザー操作ガイド

## サービス概要

本インフラストラクチャは、安全なWordPressブログとともに、さまざまな管理・監視用のボーナスサービスをホストしている。外部からのアクセスはすべて、HTTPS（ポート443）経由でNGINXを通して厳密にルーティングされる。

| サービス | URL | 役割 |
|---------|-----|------|
| **WordPress** | `https://samatsum.42.fr` | メインのブログプラットフォーム |
| **Adminer** | `https://samatsum.42.fr/adminer` | DBのGUI管理ツール |
| **Static Site** | `https://samatsum.42.fr/site/` | 軽量なポートフォリオ |
| **Grafana** | `https://samatsum.42.fr/grafana/` | 監視ダッシュボード |
| **Prometheus** | `https://samatsum.42.fr/prometheus/` | メトリクス収集 |

*注: 本プロジェクトでは自己署名TLS証明書を使用しているため、ブラウザにセキュリティ警告が表示される。サービスにアクセスするには、「詳細設定」をクリックし、「samatsum.42.fr にアクセスする」を選択する必要がある。*

---

## 起動 / 停止コマンド

プロジェクトルートに用意されている `Makefile` を使用してインフラストラクチャを管理できる。

| アクション | コマンド |
|--------|---------|
| **インフラの起動** | `make up` |
| **安全な停止** | `make stop` |
| **サービスの再開** | `make start` |
| **ヘルスチェック** | `make status` |
| **リアルタイムログの表示** | `make logs` |

---

## 認証情報とアクセス

セキュリティのため、パスワードはハードコードされていない。管理者によって管理される `secrets/` フォルダから読み込まれる。

### WordPressへのアクセス
- **管理画面URL**: `https://samatsum.42.fr/wp-admin`
- **ユーザー名**: `.env` で定義 (`WP_ADMIN_USER`)
- **パスワード**: `secrets/credentials.txt` に記載

### データベース管理 (Adminer)
- **URL**: `https://samatsum.42.fr/adminer`
- **システム**: `MySQL`
- **サーバー**: `mariadb` *(Dockerの内部DNS名)*
- **ユーザー名**: `.env` で定義 (`MYSQL_USER`)
- **パスワード**: `secrets/db_password.txt` に記載
- **データベース**: `.env` で定義 (`MYSQL_DATABASE`)

### ファイル転送 (FTP)
FTP経由でWordPressのファイルを直接アップロードまたは変更できる。
- **ホスト**: `samatsum.42.fr`
- **ポート**: `21`
- **ユーザー名**: `.env` で定義 (またはデフォルトの `ftpuser`)
- **パスワード**: `secrets/ftp_password.txt` に記載

---

## トラブルシューティング

### 1. 変更が反映されない（キャッシュ）
WordPressへの変更がすぐに反映されない場合、Redisのオブジェクトキャッシュが原因である可能性がある。少し待つか、WordPressの管理画面からキャッシュをクリアすること。

### 2. 502 Bad Gateway
WordPressやAdminerにアクセスした際に `502 Bad Gateway` が表示される場合、PHP-FPMコンテナがまだ初期化中である可能性が高い。約10〜15秒待ってからページをリロードすること。進行状況は `make logs` を実行して追跡できる。

### 3. 完全なリセット
システムの状態が破損した場合やデータベースの認証情報を忘れた場合は、インフラストラクチャとそのデータを完全に破棄して最初からやり直すことができる。
```bash
make fclean
make up
```
*(警告: `make fclean` はすべてのデータベースエントリとWordPressの投稿を完全に削除する)。*