#!/bin/bash

#-u: 未定義の変数を参照した際にエラーとして扱います。
#-o pipefail: パイプライン（A | B）の途中のコマンドが失敗した場合も、パイプ全体の失敗として検知します。
set -uo pipefail

WP_PATH="/var/www/html"

# secretsからパスワードを読み込む
set +x
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials)
WP_NORMAL_PASSWORD=$(cat /run/secrets/wp_normal_password)
set -x

# wp-cliがなければダウンロード
if [ ! -f "/usr/local/bin/wp" ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

# WordPressファイルがなければダウンロード
if [ ! -f "${WP_PATH}/wp-config.php" ]; then
    wp core download --path=${WP_PATH} --allow-root

    wp config create \
        --path=${WP_PATH} \
        --dbname=${MYSQL_DATABASE} \
        --dbuser=${MYSQL_USER} \
        --dbpass=${MYSQL_PASSWORD} \
        --dbhost=mariadb:3306 \
        --skip-check \
        --allow-root

fi

# DB接続を待つ(状態の同期（競合状態の防止）)
# WordPress側から「DBに接続できるか？」を確認（ポーリング）
# 2秒 × 60回 = 120秒（2分）のタイムアウト
MAX_TRIES=60
TRIES=0

until wp db check --path=${WP_PATH} --allow-root 2>/dev/null; do
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo "Error: MariaDB connection timeout after 2 minutes." >&2
        exit 1 # ここで異常終了させ、Dockerデーモンに再起動を任せる
    fi
    echo "Waiting for MariaDB... ($TRIES/$MAX_TRIES)"
    sleep 2
    TRIES=$((TRIES+1))
done

# WordPressが未インストールならインストール

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

    wp user create ${WP_NORMAL_USER} ${WP_NORMAL_EMAIL} \
        --user_pass=${WP_NORMAL_PASSWORD} \
        --role=author \
        --path=${WP_PATH} \
        --allow-root

    # Redis設定
    wp config set WP_CACHE_KEY_SALT ${DOMAIN_NAME} --path=${WP_PATH} --allow-root
    wp config set WP_REDIS_HOST redis --path=${WP_PATH} --allow-root
    wp config set WP_REDIS_PORT 6379 --path=${WP_PATH} --allow-root
    wp plugin activate redis-cache --path=${WP_PATH} --allow-root
fi

# フォアグラウンドで起動（PID 1になる）
exec php-fpm8.2 -F
