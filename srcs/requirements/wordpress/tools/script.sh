#!/bin/bash

WP_PATH="/var/www/html"

# secretsからパスワードを読み込む
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials)
WP_NORMAL_PASSWORD=$(cat /run/secrets/wp_normal_password)

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
        --dbhost=mariadb \
        --skip-check \
        --allow-root

fi

# DB接続を待つ
until wp db check --path=${WP_PATH} --allow-root 2>/dev/null; do
    echo "Waiting for MariaDB..."
    sleep 2
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
        --allow-root

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
