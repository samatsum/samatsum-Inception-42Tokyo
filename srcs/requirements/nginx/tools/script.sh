#!/bin/bash
#1gyoumega #!: 「このファイルはスクリプトです。以下のプログラムを使って実行してください」という合図。
##/bin/bash: 「bash（シェルの一種）を使って実行してください」という指定。

# デフォルト設定の削除
rm -f /etc/nginx/sites-enabled/default

#設定を動的に変更(DOMAIN_NAME is samatsum.42.fr)
envsubst '${DOMAIN_NAME}' < /etc/nginx/sites-available/default > /etc/nginx/sites-enabled/default


# exec ,PID 1 を実行している中身（プロセス）を、シェルから NGINX へと入れ替える
# '-g "daemon off;"': NGINXを「バックグラウンド」ではなく「フォアグラウンド」で動かし続ける命令。
# Dockerコンテナは「フォアグラウンドで動いているプログラム」がいなくなると終了してしまうため、この設定が必須
exec nginx -g "daemon off;"
