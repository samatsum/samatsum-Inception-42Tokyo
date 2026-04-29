#!/bin/bash
set -uo pipefail

set +x
FTP_USER=${FTP_USER:-ftpuser}
FTP_PASS=$(cat /run/secrets/ftp_password)
set -x

# ユーザーが存在しなければ作成
if ! id "$FTP_USER" &>/dev/null; then
    useradd -m -d /var/www/html -s /bin/bash "$FTP_USER"
    echo "$FTP_USER:$FTP_PASS" | chpasswd
fi

exec vsftpd /etc/vsftpd.conf
