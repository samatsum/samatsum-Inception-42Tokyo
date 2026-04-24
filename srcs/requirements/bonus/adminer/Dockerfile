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

RUN apt-get update && apt-get install -y \
    php8.2 \
    php8.2-mysql \
    php8.2-fpm \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/php && \
    mkdir -p /var/www/html

RUN curl -L https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php -o /var/www/html/index.php

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/script.sh /script.sh

RUN chmod +x /script.sh && \
    chown -R www-data:www-data /var/www/html && \
    chmod 755 /var/www/html/index.php

WORKDIR /var/www/html

EXPOSE 8080

CMD ["/script.sh"]
