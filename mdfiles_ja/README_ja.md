*本プロジェクトは、42カリキュラムの一環として samatsum によって作成されました。*

## 概要 (Description)

Inceptionは、Docker Composeを使用してマルチサービス・インフラストラクチャを仮想化するシステム管理プロジェクトです。このアーキテクチャは厳格なマイクロサービス手法に従い、プロセスの分離、セキュリティ（TLS v1.2/v1.3）、および高可用性を確保しています。

### アーキテクチャ (Architecture)

```text
                                    [ Internet ]
                                          │
                            HTTPS (Port 443) / FTP (Port 21)
                                          │
┌─────────────────────────────────────────▼─────────────────────────────────────────┐
│                                     VM (Host)                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │                               Docker Compose                                │  │
│  │                                                                             │  │
│  │   ┌──────────────────────────────────────────────────────────────────┐      │  │
│  │   │                    NGINX (TLS 1.2/1.3 Gateway)                   │      │  │
│  │   └─┬──────────────┬───────────────┬───────────────┬───────────────┬─┘      │  │
│  │     │              │               │               │               │        │  │
│  │     │       ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ │  │
│  │     │       │ Static Site │ │ Prometheus  │ │   Grafana   │ │   Adminer   │ │  │
│  │     │       │   (Flask)   │ │  (Metrics)  │ │ (Dashboard) │ │  (DB GUI)   │ │  │
│  │     │       └─────────────┘ └──────┬──────┘ └──────▲──────┘ └──────┬──────┘ │  │
│  │     │                              │               │               │        │  │
│  │     │                              └───────┬───────┘        ┌──────▼──────┐ │  │
│  │     │              [L7 Routing]            │                │   MariaDB   │ │  │
│  │     └─────────────┬────────────────────────┤                │  (Database) │ │  │
│  │                   │                        │                └──────▲──────┘ │  │
│  │           ┌───────▼───────┐        [Data Scraping]                 │        │  │
│  │           │   WordPress   │◀───────────────────────────────────────┘        │  │
│  │           │   (PHP-FPM)   │─────────[ SQL Query ]──────────────────┐        │  │
│  │           └───────┬───────┘                                        │        │  │
│  │                   │                                                │        │  │
│  │           [Object Caching]                                         │        │  │
│  │                   │                                                │        │  │
│  │           ┌───────▼───────┐        ┌───────────────────────┐       │        │  │
│  │           │  Redis Cache  │        │   Shared WP Volume    │◀──────┘        │  │
│  │           │ (In-memory)   │        │   (wordpress_data)    │                │  │
│  │           └───────────────┘        └───────▲───────────────┘                │  │
│  │                                            │                                │  |
│  │   ┌───────────────┐                        │                                │  |
│  │   │  FTP Server   │────────[ File Sync ]───┘                                │  |
│  │   │   (vsftpd)    │                                                         │  |
│  │   └───────────────┘                                                         │  |
│  │                                                                             │``|
│  │  ══════════════════════════════════╧══════════════════════════════════════  │  │
│  │                         inception-network (bridge)                          │  │
│  │                                                                             │  │
│  └────────────────────────────────────┬────────────────────────────────────────┘  │
│                                       │                                           │
│                              Bind Mounts (Persistence)                            │
│                                       ▼                                           │
│                 /home/samatsum/data/{wordpress, mariadb, prometheus}              │
└───────────────────────────────────────────────────────────────────────────────────┘

```

### リクエストフロー (必須課題)

```text
ブラウザ --[HTTPS]--> NGINX --[FastCGI]--> PHP-FPM --[SQL]--> MariaDB
                (443)               (9000)              (3306)

```

## サービス概要 (9コンテナ)

| コンテナ | カテゴリ | 役割 | 主要原則とアーキテクチャ |
| --- | --- | --- | --- |
| **NGINX** | 必須 | TLSゲートウェイ & リバースプロキシ | 外部からの唯一のエントリポイント。バックエンドの負荷軽減のためTLS終端を処理。 |
| **WordPress** | 必須 | CMS (アプリケーション層) | PHP-FPMを介して動的PHPスクリプトを実行。 |
| **MariaDB** | 必須 | RDBMS (永続化層) | Docker Secretsを使用して認証を行い、永続データを安全に管理。 |
| **Redis** | ボーナス | メモリ内オブジェクトキャッシュ | L7のレスポンス時間を大幅に改善。 |
| **Adminer** | ボーナス | DB管理GUI | ブラウザ経由でMariaDBの状態を管理するための視覚的なインターフェースを提供。 |
| **FTP** | ボーナス | ファイル転送プロトコル | 開発者が共有WordPressボリュームを直接操作できるようにする。 |
| **Static Site** | ボーナス | Python (Flask) サイト | PHPスタックから独立して動作する、スタンドアロンの静的ポートフォリオサイト。 |
| **Prometheus** | ボーナス | 時系列メトリクスサーバ | 各サービスのインフラメトリクス（CPU、メモリ、リクエスト）を能動的にスクレイピング。 |
| **Grafana** | ボーナス | 可視化ダッシュボード | Prometheusの生データを、人間が読みやすいインタラクティブな監視ダッシュボードに変換。 |

## 使用方法

### クイックスタート

1. `/etc/hosts` に `127.0.0.1 samatsum.42.fr` を追加し、ドメインをローカルにマッピングします。
2. `.env` ファイルと `secrets/` ディレクトリが正しく設定されていることを確認してください（生成スクリプトについては `DEV_DOC.md` を参照）。
3. インフラをビルドして起動します：

```bash
make up

```

*日常的な操作やサービスへのアクセスURLについては `USER_DOC.md` を、技術仕様の詳細やMakefileのターゲットについては `DEV_DOC.md` を参照してください。*

## 4つの比較（設計判断の根拠）

### 1. Virtual Machine vs Docker

| 観点 | Virtual Machine | Docker Container |
|------|-----------------|------------------|
| 仮想化層 | **ハードウェア層**（Hypervisor） | **アプリケーション層**（コンテナランタイム） |
| OS | 各 VM に完全な OS カーネル | ホスト OS のカーネルを共有 |
| 起動時間 | 数十秒〜数分 | 数秒 |
| リソース効率 | 低（OS 全体をエミュレート） | 高（プロセス分離のみ） |
| 分離レベル | 強（完全な仮想化） | 中（namespace + cgroups） |

**本課題での判断**: Docker コンテナを VM 内で動作させる。課題要件で「VM を使用すること」が指定されているため、ホスト OS → VM → Docker の 3 層構成となる。

> 参考動画: [YouTube — VM vs Docker 対比解説](https://www.youtube.com/watch?v=-NTdH4Y2veI)

### 2. Docker Secrets vs Environment Variables

| 観点 | Docker Secrets | Environment Variables |
|------|----------------|----------------------|
| 用途 | 機密情報（パスワード、API キー等） | 非機密設定値（URL、ユーザー名等） |
| 保存場所 | `/run/secrets/` （tmpfs、メモリ上） | プロセス環境 |
| 可視性 | `docker inspect` で見えない | `docker inspect` で見える |
| git 管理 | `.gitignore` で除外必須 | `.env` として管理可 |

**【結論】**
環境変数は設定値（ドメイン名やポート番号など）を渡すには便利ですが、機密情報の保存には適していません。Docker Secretsを使用することで、データがメモリ上（tmpfs）のみに保持され、極めて高い堅牢性とメモリ安全性が担保されます。


### 3. Docker Network vs Host Network

| 観点 | Docker Network (bridge) | Host Network |
|------|------------------------|--------------|
| 分離 | コンテナ間で独立したネットワーク | ホストのネットワーク名前空間を直接使用 |
| DNS | Docker 内部 DNS（コンテナ名で解決） | ホストの `/etc/resolv.conf` |
| ポート | 明示的にマッピング（`-p 443:443`） | コンテナがホストのポートを直接占有 |
| セキュリティ | 高（外部から直接アクセス不可） | 低（ホストと同等） |

**【結論】**
Host Networkはネットワークの隔離（Network Namespace）を破壊し、セキュリティ上の大きな脆弱性を生みます。Docker Network（Bridge）を使用することで、L3レイヤーでのコンテナ間の安全な通信（内部DNS）と、L4レイヤーでの厳密なアクセス制御（必要なポートだけを外に開く）が可能になります。



### 4. Docker Volumes vs Bind Mounts

| 観点 | Named Volumes | Bind Mounts |
|------|---------------|-------------|
| 管理 | Docker が管理（`docker volume ls`） | ホストのファイルシステム直接 |
| パス指定 | 論理名（`mariadb_data`） | 絶対パス（`/home/user/data`） |
| ポータビリティ | 高（Docker 環境間で移動可） | 低（ホストパスに依存） |
| 初期化 | 空 or イメージからコピー | ホスト側のファイルが優先 |


> 参考資料: [Qiita — P-man_Brown: Named Volumes + driver_opts](https://qiita.com/P-man_Brown/items/6d6e870acc1720f04486)（→ [クロスリファレンス](dev_docs/references.md#qiita)）
- `mariadb_data` → `/home/samatsum/data/mariadb`
- `wordpress_data` → `/home/samatsum/data/wordpress`

これにより、Docker の Volume 管理機能を活かしつつ、VM 再起動後もデータを永続化。

**【結論】**
Bind Mountsは手元のコードをコンテナに同期させるような開発環境では便利ですが、ホスト環境への依存度が強くなります。Docker Volumesを使用することで、データの管理をDockerに一任でき、システムの堅牢性と移植性が向上します。


確認方法
```bash
docker volume ls
docker volume inspect <実際の名前>
docker compose config --volumes
```

---

## Resources（一次資料）

### Docker

- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Use secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Volumes in Compose](https://docs.docker.com/reference/compose-file/volumes/)
- [Network in Compose](https://docs.docker.com/compose/how-tos/networking/)
- [Docker Compose CLI Reference](https://docs.docker.com/reference/cli/docker/compose/)

### Alpine Linux

- [Alpine Linux Releases](https://alpinelinux.org/releases/)
- [Alpine Wiki - MariaDB](https://wiki.alpinelinux.org/wiki/MariaDB)
- [Alpine Wiki - Nginx](https://wiki.alpinelinux.org/wiki/Nginx)

### NGINX

- [nginx.org Documentation](https://nginx.org/en/docs/)
- [nginx.org Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
- [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)

### MariaDB

- [mariadb-install-db](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)
- [MariaDB Server Documentation](https://mariadb.com/kb/en/documentation/)
- [mariadb-install-db — デフォルト作成アカウント](https://mariadb.com/kb/en/mariadb-install-db/#user-accounts-created-by-default)

### WordPress / PHP

- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
- [wp core install](https://developer.wordpress.org/cli/commands/core/install/)
- [wp user create](https://developer.wordpress.org/cli/commands/user/create/)
- [wp post list](https://developer.wordpress.org/cli/commands/post/list/)

### TLS / セキュリティ

- [RFC 8446 (TLS 1.3)](https://datatracker.ietf.org/doc/html/rfc8446)
- [OpenSSL Documentation](https://www.openssl.org/docs/)

### Makefile

- [GNU Make Manual](https://www.gnu.org/software/make/manual/make.html)

### 環境（VM）

- [VirtualBox User Manual](https://www.virtualbox.org/manual/UserManual.html)

### moby/moby Issues（restart policy）

- [#11065 — Non-fatal signals break restart policies](https://github.com/moby/moby/issues/11065)
- [#26464 — Taking stop-signal into account when docker kill](https://github.com/moby/moby/pull/26464)
- [#41302 — Signal breaks unless-stopped restart policy](https://github.com/moby/moby/issues/41302)
- [#47792 — docker kill prevents unless-stopped from starting after reboot](https://github.com/moby/moby/issues/47792)

### 書籍

- [Docker（日本語版）](https://www.oreilly.com/library/view/docker/9784873117768/) — O'Reilly Japan, 2016年8月, 384ページ（紙の本で参照）

### 参考資料（補助）

課題書に明記されていないが参照した資料。一次資料で確認した内容の理解補助として使用。

- [Qiita — P-man_Brown: Named Volumes + driver_opts ハイブリッド方式](https://qiita.com/P-man_Brown/items/6d6e870acc1720f04486)（→ §4 Volumes 設計判断の採用根拠）
- [Qiita — etaroid: Docker secrets 補足 記事1](https://qiita.com/etaroid/items/b1024c7d200a75b992fc)
- [Qiita — etaroid: Docker secrets 補足 記事2](https://qiita.com/etaroid/items/88ec3a0e2d80d7cdf87a)
- [Qiita — etaroid: Docker secrets 補足 記事3](https://qiita.com/etaroid/items/40106f13d47bfcbc2572)
- [YouTube — VM vs Docker 対比解説](https://www.youtube.com/watch?v=-NTdH4Y2veI)（→ §1 VM vs Docker 設計判断の参考）

---

## AI 使用説明

本課題では AI（Claude）を**ペアプログラミングの Navigator** として活用した。

### 使用方針（AI-Navigated Pair Programming with Scaffolding）

- **AI がやったこと**: 概念の解説、設計判断の根拠説明、確認用コマンドの提示、コードのスケルトン提示、レビュー・フィードバック、翻訳、エラー解決
- **AI がやらなかったこと**: 完成コードの直接生成、ファイルの直接編集
