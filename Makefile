# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: samatsum <samatsum@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/12/26 20:22:22 by samatsum          #+#    #+#              #
#    Updated: 2026/04/14 14:16:58 by samatsum         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Makefile

# Configuration
COMPOSE = docker compose -f srcs/docker-compose.yml
VOLUME = /home/samatsum/data

all: up

# ホストOS側でマウント用ディレクトリを事前作成し、Docker(root)による自動生成と権限エラーを防ぐ。
up:
	@mkdir -p $(VOLUME)/mariadb
	@mkdir -p $(VOLUME)/wordpress
	@mkdir -p $(VOLUME)/prometheus
	@chmod 755 $(VOLUME)
	@chmod 755 $(VOLUME)/mariadb
	@chmod 755 $(VOLUME)/wordpress
	@chmod 755 $(VOLUME)/prometheus
	@$(COMPOSE) up --build



#プロセスを殺すだけでなく、L3レイヤーで構築した仮想スイッチ（inception-network）を破壊し、ルーティングテーブルからIPを消去
#コンテナのイメージと、ホストOSにマウントされた永続化データ（ボリューム）はそのまま残るため、次に make up した時、データは完全に引き継がれます。
#https://docs.docker.com/reference/cli/docker/compose/down/
down:
	@$(COMPOSE) down

#Dockerデーモンが、各コンテナの PID 1 プロセスに対して「SIGTERM（終了）」シグナルを送信
# コンテナのファイルシステム(OverlayFS)は維持されるため再起動が高速
#https://docs.docker.com/reference/cli/docker/compose/stop/
stop:
	@$(COMPOSE) stop

# stop状態で維持されているコンテナのファイルシステム上で、再度プロセスを起動する。
#https://docs.docker.com/reference/cli/docker/compose/start/
start:
	@$(COMPOSE) start

# 全コンテナの標準出力(stdout)・標準エラー出力(stderr)を追跡する。
#https://docs.docker.com/reference/cli/docker/compose/logs/
logs:
	@$(COMPOSE) logs -f

#https://docs.docker.com/reference/cli/docker/container/ls/
status:
	@docker container ls -a


#コンテナ内で生成されたファイルとホストユーザーとの間で権限の不一致が起きるため、sudoでの実行を前提としている
clean:
	@$(COMPOSE) down -v --rmi all --remove-orphans 2>/dev/null || true
	@rm -rf $(VOLUME)

fclean: clean
	@sudo docker system prune -af --volumes 2>/dev/null || true
	@sudo docker volume rm mariadb wordpress prometheus 2>/dev/null || true
	@sudo rm -rf $(VOLUME)

re: fclean up

.PHONY: all up down stop start logs status clean fclean re

# # 1. コンテナの完全停止（異常終了したネットワーク等の破棄）
# sudo docker compose -f srcs/docker-compose.yml down -v

# # 2. 【最重要】ゴーストボリュームの「名指し」強制削除
# # （docker system pruneでは保護されて消えないため、直接指定して破壊）
# sudo docker volume rm mariadb wordpress prometheus

# # 3. ホスト側の物理データの完全消去（物理層のリセット）
# sudo rm -rf /home/samatsum/data

# # 4. Dockerデーモンの再起動（Snap特有の権限ロックとキャッシュのクリア）
# sudo snap restart docker

# # 5. 環境の一から再構築
# sudo make up