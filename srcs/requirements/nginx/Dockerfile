# ==============================================================================
# FROM    : ベースイメージの指定。コンテナの土台（OSや基本環境）を決める。
#           ※原則としてDockerfileの先頭に記述する。
#
# EXPOSE  : コンテナが使用する予定のポートを「宣言」する。（ドキュメント的役割）
#           ※これ単体では外のネットワークとは繋がらず、docker-composeの `ports` とセットで機能する。
#
# RUN     : イメージの【ビルド時】に実行されるコマンド。
#           ※実行するたびに新しい「レイヤー（地層）」が作られイメージサイズ（空間計算量）が増加する。
#             そのため、関連する処理は `&&` で繋ぎ、1つのRUNにまとめるのがベスto。
#
# COPY    : ホスト（手元のPC）のファイルを、コンテナイメージ内に【ビルド時】にコピーする。
#
# ARG     : 【ビルド時】のみ使用できる一時的な変数。コンテナ起動後には消滅する。
#
# ENV     : 【コンテナ起動後】もOS内に残り続ける環境変数。アプリケーションの動作設定などに使う。
#
# WORKDIR : 以降の RUN, COPY, CMD などを実行する際の「基準ディレクトリ（作業場所）」を指定する。
#           ※ `RUN cd /path` と書いても次のRUNには引き継がれないため、ディレクトリ移動は必ずこれを使う。
#
# CMD     : コンテナが【起動した瞬間】にデフォルトで実行される主役プロセス（PID 1）。
#           ※1つのDockerfileにつき最後に1つだけ有効。このプロセスが終了すると、コンテナ自体も終了する。
# ==============================================================================

FROM debian:bookworm

#HTTPS用の443番ポート
EXPOSE 443

RUN apt update && apt upgrade -y && apt install -y \
    nginx \
    openssl \
    gettext-base

COPY conf/default /etc/nginx/sites-available/.
COPY tools/script.sh ./script.sh

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

RUN chmod +x ./script.sh

#COPY tools/script.sh ./script.sh してるよ
#PID 1として,./script.sh実行
CMD ["./script.sh"]

# ==============================================================================
# 【根本原理：NGINXとは何か？】
# システムの「受付・案内係（リバースプロキシ / Webサーバー）」です。
# インターネットからのHTTPリクエストを最前線（L7/アプリケーション層）で受け止め、
# バックエンド（WordPress等のアプリ層）へ適切に通信を振り分ける役割を担います。
# 
# [応用機能（今回の課題外）]
# 本来は単なるWebサーバーにとどまらず、複数台のサーバーへアクセスを分散させる
# 「ロードバランサー（負荷分散）」機能や、応答速度（時間計算量）を劇的に高める
# 「リバースプロキシキャッシュ」、悪意ある攻撃を弾く「WAF（ファイアウォール）」の
# 起点としても機能する、ネットワーク層における最強の「盾」であり「交通整理役」です。
# ==============================================================================