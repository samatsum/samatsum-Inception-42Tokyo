#!/bin/bash

# nginx設定ファイル内の環境変数を展開
envsubst '${DOMAIN_NAME}' < /etc/nginx/sites-available/default > /etc/nginx/sites-enabled/default

exec nginx -g "daemon off;"

#envsubst でテンプレート内の ${DOMAIN_NAME} を実際の値に置換
#sites-available → sites-enabled に出力（nginxが読むのは sites-enabled）
#exec nginx -g "daemon off;"：PID 1問題解消＋フォアグラウンド起動
#以前あった echo "127.0.0.1 ..." >> /etc/hosts は不要（DNS解決はDocker networkが行う）
