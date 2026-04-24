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
    apt-transport-https \
    software-properties-common \
    wget \
    gpg \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key && \
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

RUN apt-get update && apt-get install -y \
    grafana \
    && rm -rf /var/lib/apt/lists/*

COPY conf/grafana.ini /etc/grafana/grafana.ini
COPY tools/script.sh /script.sh

RUN chmod +x /script.sh

EXPOSE 3000

CMD ["/script.sh"]
