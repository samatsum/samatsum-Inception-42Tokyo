#!/bin/bash

# シンボリックリンクを削除して独立ファイルにする
rm -f /etc/nginx/sites-enabled/default

envsubst '${DOMAIN_NAME}' < /etc/nginx/sites-available/default > /etc/nginx/sites-enabled/default

exec nginx -g "daemon off;"
