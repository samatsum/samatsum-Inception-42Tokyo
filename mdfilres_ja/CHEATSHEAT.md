# Inception ピアレビュー対策チートシート

## 1. 必須検証コマンド集（ライブデモ用）

### 1-1. 予備テスト（機密情報の漏洩チェック）

* 
`cat .gitignore` を実行し、パスワードファイルがGit管理から除外されていることを見せる 。



### 1-2. NGINXポート制限とTLSの確認

* 
NGINX (L4/L6/L7) 

* 
**ポート制限**: `docker ps` を実行し、443番のみto BOnus you 21 portがホストに公開されていることを示す 。


* **HTTP拒否**: `curl -v -I http://samatsum.42.fr` 実行。
* 
`-v` (verbose): 通信のプロトコル詳細を表示 。


* 
`-I` (head): ヘッダーのみ取得 。


* 
**結果**: `Connection refused` になること 。




* **HTTPS成功 & TLS証明**: `curl -k -v -I https://samatsum.42.fr` 実行。
* 
`-k` (insecure): 自己署名証明書の警告を無視 。


* 
**結果**: ログ内の `SSL connection using TLSv1.3` を指差し、TLS 1.2/1.3が使用されていることを証明する 。

* HTTPは平文通信のため証明書は関係なく、`-k` の有無で挙動は変わらない。ポート80が弾かれる (Connection refused) ことを見せる 。





### 1-3. ボリュームのバインド確認

* 
`docker volume ls` でボリューム名を確認する 。


* 
`docker volume inspect mariadb` 等を実行し、出力の `Options.device` に `/home/samatsum/data/` が含まれていること（ホスト側のディレクトリに直結していること）を見せる 。



### 1-4. CLIからのデータベースログイン確認

* 
**ログイン:** `docker exec -it mariadb mariadb -u root -p` 。


* 
`-it` はコンテナ内のプロセスと対話するための仮想端末 (TTY) を割り当てる命令である 。


* パスワードは `secrets/db_root_password.txt` の内容を入力する 。




* **データ確認SQL:**
* 
`SHOW DATABASES;` (データベース一覧を表示) 


* 
`USE wordpress;` (操作対象のデータベースを選択) 


* 
`SHOW TABLES;` (テーブル一覧を表示) 


* 
`SELECT user_login, user_email FROM wp_users;` (WordPressの初期ユーザーが書き込まれていることを証明) 

*
`USE wordpress; [cite_start]SELECT * FROM wp_comments;` でデータが空でないことを示す 。




### 1-5. 永続化 (Persistence) テスト

1. WordPress上で記事やコメントを変更する 。


2. 
`sudo reboot` でホストOSごと再起動する 。


* ※apt版Dockerへの移行により、Snap起因のデッドロックは発生しませんが、プロセス安全性の観点からは事前に `sudo make stop` によるグレースフルシャットダウンを推奨します。


3. 
`sudo make up` を実行する 。


* 
**解説:** 再起動後にコンテナが自動復帰するのは、`docker-compose.yml` で各サービスに `restart: always` (または `unless-stopped`) を設定しているためである 。




4. 再度 `curl -k -I https://samatsum.42.fr` を叩き、データが完全に復元されていることを証明する 。



---

## 2. 構成変更テスト (Configuration Change) 対応手順

構成変更の指示が出た場合は、対象ファイルを修正後、必ず `make fclean` と `make up` を実行して再構築する 。

### パターンA: NGINX のポート変更 (一番簡単)

NGINXはホストOSと直接繋がる唯一のコンテナであるため、内部ネットワークへの影響はない 。

* 
**修正ファイル:** `srcs/docker-compose.yml` 


* 
**修正内容:** `ports: "443:443"` を `"8443:443"` 等に変更する 。



### パターンB: MariaDB のポート変更

「待ち受け側」と「接続側」の両方を変更しないとシステムが停止する 。

* 
**待ち受け側:** `srcs/requirements/mariadb/conf/50-server.cnf`。`port = 3306` を `3307` 等に変更する 。


* 
**接続側:** `srcs/requirements/wordpress/tools/script.sh`。`wp config create` のオプションを `--dbhost=mariadb:3307` に変更する 。


* 
**解説 (競合状態の防止):** DB起動前にWPが接続してクラッシュするのを防ぐため、起動スクリプト内でポーリング (`mysqladmin ping` 等) を行い、DBの起動を待機させている 。





### パターンC: WordPress (PHP-FPM) のポート変更

* 
**待ち受け側:** `srcs/requirements/wordpress/conf/www.conf`。`listen = 9000` を `9001` 等に変更する 。


* 
**転送側:** `srcs/requirements/nginx/conf/default`。`fastcgi_pass wordpress:9000;` を `9001;` に変更する 。



---

## 3. コア・アーキテクチャの解説 (原理質問対策)

### 仮想マシン (VM) と比較したDockerの利点

アーキテクチャのレイヤー構造における差分は以下の通りである 。

* 
**VM:** ゲストOSを丸ごと起動するため、数GBのメモリと数分の起動時間を消費する 。


* 
**Docker:** ゲストOSを持たず、ホストOSのカーネルを共有してプロセスを隔離 (Namespace/Cgroups) しているだけである 。起動時間はミリ秒単位で、空間計算量も極めて少ない 。


* 
**【根本原理】** VMが「物理マシンをソフトウェアで再現したもの」であるのに対し、Dockerは「ホストOS上で動く、隔離されたただのプロセス」である 。カーネルを共有しているため、無駄なリソース消費がなく、極めて高い「効率性」と「可搬性」を実現する 。



### Docker と Docker Compose の仕組み (なぜ動くのか)

#### Dockerの仕組み (単一コンテナの隔離)

Dockerは魔法ではなく、Linuxカーネルの標準機能を組み合わせて作られたプロセス隔離技術である 。

1. 
**Namespaces (名前空間):** プロセスが見えるリソース（プロセスID、ネットワーク等）を切り離し、「自分専用のOSで動いている」と錯覚させる 。


2. 
**cgroups:** コンテナが使用できるハードウェアリソースを制限・監視し、暴走を防ぐ（堅牢性の担保） 。


3. 
**UnionFS (Overlay2):** 複数のファイルシステムを透過的に重ねて見せる技術。イメージはリードオンリーで、一番上に書き込み可能な層を追加する（コピーオンライト方式）。これによりストレージの空間計算量を劇的に削減する 。



#### Docker Composeの仕組み (複数コンテナのオーケストレーション)

Docker Composeは、「理想のシステム状態」と「現状」の差分を埋める宣言的ツールである 。

* 
**自動ネットワーク解決:** L3ネットワーク (Bridge) を一括作成し、IPではなく `wordpress:9000` のような「サービス名」での相互通信（内部DNS）を可能にする 。


* 
**ディレクトリ分離の理由:** 単一責任原則（1関数1責務に相当）を守り、ビルド時に無関係なファイルが送信されるのを防ぎ、時間・空間計算量を最小化する 。



### Docker Compose の有無による「Dockerイメージの違い」

**Dockerイメージそのもの（バイナリやファイル構造）に一切の違いはない** 。
違うのは「実行時のコンテキスト（環境変数、ネットワーク、ボリューム、起動オプション）」である 。Composeを使用することで、実行環境がYAMLコードとして固定化され、再現性と可読性が飛躍的に向上する 。

### ネットワーク・通信・マウントの原理

* 
**L3/L4 隔離:** 仮想L3スイッチを用い、NGINX (443) 以外のポートをホストから隠蔽する 。`network: host` は隔離が崩壊するため、`--link` は動的IP変更に追従できないため禁止されている 。


* 
**Webスタック (FastCGI):** NGINXがブラウザからのリクエストを受け、`.php` はFastCGIプロトコルに変換して9000番ポート経由でWordPressに委譲する 。


* 
**マウントの概念 (ハイブリッド方式):** `driver: local` で `device` を指定することで、実態はホストディレクトリ直結の「バインドマウント」でありながら、Docker側には「名前付きボリューム」として登録され、管理が容易になる 。



---

## 4. 発展・ボーナス実装の解説と検証

### 4-1. ボーナス実装の原理

* 
**PID 1問題とシグナル処理:** コンテナはPID 1が死ぬと停止する。NGINX/MariaDBは `exec` でシェルを上書きしアプリをPID 1に昇格させ、Static-site/FTPはシグナル無視によるゾンビプロセス化を防ぐため極小initの `tini` をENTRYPOINTに挟んでいる 。


* 
**Docker Secrets の堅牢性:** ホスト上のファイルを読み込み、コンテナ内部の `/run/secrets/` に `tmpfs` (RAM上の一時ファイルシステム) を作成してマウントする 。ディスクに一切書き込まれないため、極めて高いメモリ安全・堅牢性を担保する 。



### 4-2. ボーナスの役割と検証コマンド

#### 1. Redis（キャッシュによる高速化）

* 
**役割:** WordPressの表示速度を劇的に速くするための「一時記憶（キャッシュ）」サーバー 。時間計算量を O(1) に近づける。


* 
**接続先:** WordPressコンテナがこれを利用する 。


* 
**メリット:** 通常、ページ表示のたびにMariaDBへデータを計算しに行くが、結果をRedisに保存しておくことで、2回目以降の表示を計算なしで高速に返せる 。


* 
**検証手順 (コマンド):** `docker exec -it wordpress wp redis status --path=/var/www/html --allow-root` を実行し、`Status: Connected` と表示されれば、通信（L4）とキャッシュ連携（L7）が共に成功 。


* 
**検証手順 (ブラウザ):** `https://samatsum.42.fr/wp-admin` にログインし、左メニュー「設定」>「Redis」を開き、「ステータス: 接続済み」を確認する 。



#### 2. FTP (vsftpd)（ファイル転送）

* 
**役割:** サーバー内のファイルを、自分のPCから直接アップロード・ダウンロードするための窓口 。


* 
**接続先:** `wordpress_data` ボリュームを共有する 。


* 
**メリット:** WPのテーマや画像を、FTPクライアントを使って直接管理できる 。


* 
**検証手順 (コマンド):** `ftp -p samatsum.42.fr` (Passiveモード) で接続 。ユーザー名 (`ftpuser`) と secretsのパスワードでログインし、`ls` コマンドで `wp-config.php` 等が見えれば成功 。


* 
**検証手順 (GUI):** FileZilla等で ホスト: `samatsum.42.fr`、ポート: 21、同ユーザー情報で接続しディレクトリツリーを表示 。



#### 3. Static Site (Flask)（シンプルな紹介サイト）

* 
**役割:** WordPressとは別の、Python製の独立したシンプルなWebサイト 。


* 
**接続先:** NGINXがこのサイトへのアクセスを中継する 。


* 
**メリット:** PHP以外の言語（Python/Flask）でサイトを動かす経験を積む要件 。


* 
**検証手順 (コマンド):** `curl -k https://samatsum.42.fr/site/` 。


* 
**検証手順 (ブラウザ):** `https://samatsum.42.fr/site/` にアクセスし、「samatsum - Student at 42 Tokyo」という画面が出れば、NGINXからポート5000へのリバースプロキシが成功している 。



#### 4. Prometheus（稼働データの収集）

* 
**役割:** 各サービスが「今どれくらい忙しいか」「エラーが起きていないか」という数値データ（メトリクス）を定期的に集めて回る収集家 。


* 
**対象:** NGINXのリクエスト数や、WordPressのプロセス数などを監視する 。


* 
**メリット:** サーバーダウンの予兆やアクセス集中具合をデータ蓄積できる 。


* 
**検証手順 (ブラウザ):** `https://samatsum.42.fr/prometheus/` にアクセスし、上部メニュー「Status」>「Targets」を選択。エンドポイント (`localhost:9090`) のStateが緑色の `UP` であればスクレイピング成功 。



#### 5. Grafana（監視ダッシュボード）

* 
**役割:** Prometheusが集めた複雑な数値を、グラフやチャートにして可視化するモニター 。


* 
**接続先:** `prometheus` コンテナからデータを受け取る 。


* 
**メリット:** ブラウザを開くだけでサーバー状態が一目でわかるダッシュボードを作成できる 。


* 
**検証手順 (ブラウザ):** `https://samatsum.42.fr/grafana/` にアクセス 。ユーザー名 `admin`、パスワード `password`（初期値）でログインし、「Dashboards」から「WordPress Monitoring」を開き、PHP-FPMのプロセス数等が表示されれば成功 。



#### 6. Adminer（データベース管理GUI）

* 
**ログイン情報:** `System: MySQL`, `Server: mariadb` (内部DNS名), `Username: wpuser`, `Password: db_password.txtの内容`, `Database: wordpress` 。