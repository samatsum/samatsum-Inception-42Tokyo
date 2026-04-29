#!/bin/bash

# 環境変数（ENV）にパスワードを入れると、コンテナ内の全プロセスから見えてしまい、
# docker inspectコマンドでも丸見えになるため、ファイルからの読み出し（tmpfs）で堅牢性を確保する。
# secretsからパスワードを読み込む
set +x
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
set -x

# 初回のみDB初期化
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    mariadbd --user=mysql --datadir=/var/lib/mysql &

    # 裏側で起動したMariaDBが、リクエストを受け付けられる状態になるまでポーリング（定期確認）する。
    MAX_TRIES=120
    TRIES=0
    until mysqladmin ping >/dev/null 2>&1; do
        if [ "$TRIES" -ge "$MAX_TRIES" ]; then
            echo "Error: MariaDB background startup timeout." >&2
            exit 1 # 異常終了させてDockerに再起動を促す
        fi
        echo "Waiting for MariaDB to be ready... ($TRIES/$MAX_TRIES)"
        sleep 1
        TRIES=$((TRIES+1))
    done


set +x
# DBの作成、ユーザーの作成、権限の付与を行う。
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
set -x
    # 裏側で動いているMariaDBを正規の手段でシャットダウン
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    sleep 2
fi


# フォアグラウンドで起動（PID 1になる）
exec mariadbd --user=mysql --datadir=/var/lib/mysql
