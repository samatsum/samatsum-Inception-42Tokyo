#!/bin/bash

#-u: 未定義の変数を参照した際にエラーとして扱います。
#-o pipefail: パイプライン（A | B）の途中のコマンドが失敗した場合も、パイプ全体の失敗として検知します。
set -uo pipefail

WP_PATH="/var/www/html"

# ==========================================
# 0. 初期準備とシークレットの読み込み
# ==========================================
set +x
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials)
WP_EDITER_PASSWORD=$(cat /run/secrets/wp_editer_password)
set -x

# wp-cliがなければダウンロード
if [ ! -f "/usr/local/bin/wp" ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

# WordPressコアファイルが存在しない場合のみダウンロード
if [ ! -f "${WP_PATH}/wp-includes/version.php" ]; then
    wp core download --path=${WP_PATH} --allow-root
fi

# ==========================================
# 1. 動的設定ファイルの生成（毎回必ず実行）
# ==========================================
rm -f ${WP_PATH}/wp-config.php

wp config create \
    --path=${WP_PATH} \
    --dbname=${MYSQL_DATABASE} \
    --dbuser=${MYSQL_USER} \
    --dbpass=${MYSQL_PASSWORD} \
    --dbhost=mariadb:3306 \
    --skip-check \
    --allow-root

# wp-config.phpを作り直したため、Redisの環境変数も毎回必ず再適用する
wp config set WP_CACHE_KEY_SALT ${DOMAIN_NAME} --path=${WP_PATH} --allow-root
wp config set WP_REDIS_HOST redis --path=${WP_PATH} --allow-root
wp config set WP_REDIS_PORT 6379 --path=${WP_PATH} --allow-root

# ==========================================
# 2. L4/L7 データベース接続待機（ポーリング）
# ==========================================
# WordPress側から「DBに接続できるか？」を確認
# 2秒 × 60回 = 120秒（2分）のタイムアウト
MAX_TRIES=120
TRIES=0

until wp db check --path=${WP_PATH} --allow-root 2>/dev/null; do
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo "Error: MariaDB connection timeout after 2 minutes." >&2
        exit 1 # ここで異常終了させ、Dockerデーモンに再起動を任せる
    fi
    echo "Waiting for MariaDB... ($TRIES/$MAX_TRIES)"
    sleep 1
    TRIES=$((TRIES+1))
done

# ==========================================
# 3. コアのインストール（未インストール時のみ）
# ==========================================
if ! wp core is-installed --path=${WP_PATH} --allow-root 2>/dev/null; then
    wp core install \
        --path=${WP_PATH} \
        --url=${DOMAIN_NAME} \
        --title=${WP_TITLE} \
        --admin_user=${WP_ADMIN_USER} \
        --admin_password=${WP_ADMIN_PASSWORD} \
        --admin_email=${WP_ADMIN_EMAIL} \
        --allow-root \
        --skip-email

    wp user create ${WP_EDITER_USER} ${WP_EDITER_EMAIL} \
        --user_pass=${WP_EDITER_PASSWORD} \
        --role=author \
        --path=${WP_PATH} \
        --allow-root
fi

# ==========================================
# 4. プラグインと状態の強制同期（毎回必ず実行）
# ==========================================
# プラグインが有効化されていなければ有効化
if ! wp plugin is-active redis-cache --path=${WP_PATH} --allow-root; then
    wp plugin activate redis-cache --path=${WP_PATH} --allow-root
fi

# Redisオブジェクトキャッシュが機能していなければ強制有効化
if ! wp redis status --path=${WP_PATH} --allow-root | grep -q "Status: Connected"; then
    wp redis enable --path=${WP_PATH} --allow-root
fi

# /var/www/html 以下のすべてのファイルの所有者を www-data に変更
chown -R www-data:www-data /var/www/html

# ==========================================
# 5. プロセスの起動（PID 1）
# ==========================================
# フォアグラウンドで起動（PID 1になる）
exec php-fpm8.2 -F