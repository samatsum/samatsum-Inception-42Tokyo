
#FROM:ベースイメージの指定
FROM debian:bookworm

#NGINXが使用するHTTPS用の443番ポートを、koukaipo-totoshite,コンテナ外に見せることを宣言する
EXPOSE 443

#RUN:Dockerイメージのビルド時にシェルコマンドを実行,依存環境をインストール
RUN apt update && apt upgrade -y && apt install -y \
    nginx \
    openssl \
    gettext-base

#ホストマシンにある設定ファイルを、イメージの中の指定した場所にコピー
COPY conf/default /etc/nginx/sites-available/.
COPY tools/script.sh /script.sh

#自己署名証明書（SSL）を作成するための情報
ARG CERT_FOLDER="/etc/nginx/cert"
ARG CERT="/etc/nginx/cert/server.crt"
ARG CERT_KEY="/etc/nginx/cert/server.key"
ARG COUNTRY="JP"
ARG STATE="Tokyo"
ARG LOCALITY="Shinjuku"
ARG ORGANIZATION="42Tokyo"
ARG UNIT="42"
ARG COMMON_NAME="localhost"

#SSL通信に必要な「鍵」と「証明書」をopensslコマンドで生成
RUN mkdir -p ${CERT_FOLDER}
RUN openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
    -out ${CERT} \
    -keyout ${CERT_KEY} \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${UNIT}/CN=${COMMON_NAME}"

RUN chmod +x /script.sh

#このイメージからコンテナが作られ、動き出した瞬間に実行されるコマンドを指定
#PID 1として,script.sh実行
CMD ["/script.sh"]
