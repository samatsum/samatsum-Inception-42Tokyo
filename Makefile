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


# ==============================================================================
# Clean Targets
# ==============================================================================

# [clean] プロジェクト固有のコンテナ、イメージ、ネットワーク、ボリュームを安全に削除
# ※ ホスト側の永続データ（$(VOLUME)）は残す。
clean:
	@echo "Cleaning project resources..."
	@sudo $(COMPOSE) down -v --rmi all --remove-orphans 2>/dev/null || true

# [fclean] cleanに加えて、ホスト側の永続データ削除とシステム全体のガベージコレクション
# 空間計算量を最小化し、冪等性を担保する。
fclean: clean
	@echo "Deep cleaning (removing host data and pruning)..."
	@sudo docker system prune -af --volumes 2>/dev/null || true
	@sudo docker volume rm mariadb wordpress prometheus 2>/dev/null || true
	@sudo rm -rf $(VOLUME)

# [emergency] デッドロック時の強制リセット（最終手段）
# ※ 警告: 他のプロジェクトのコンテナも全て巻き込んで強制終了します。
emergency:
	@echo "EMERGENCY RESET: Phase 1 - Restarting Docker daemon..."
	@sudo systemctl restart docker
	@echo "Phase 2 - Waiting for daemon to be ready..."
	@sleep 2 # デーモンがソケットをオープンするまでの猶予
	@echo "Phase 3 - Forcefully removing all containers and cleaning system..."
	@sudo docker rm -f $$(sudo docker ps -qa) 2>/dev/null || true
	@sudo docker system prune -af --volumes 2>/dev/null || true
	@echo "Phase 4 - Deleting host physical data..."
	@sudo rm -rf $(VOLUME)
	@echo "Reset complete."

re: fclean up

.PHONY: all up down stop start logs status clean fclean emergency re

# # 1. コンテナの完全停止（異常終了したネットワーク等の破棄）
# sudo docker compose -f srcs/docker-compose.yml down -v

# # 2. 【最重要】ゴーストボリュームの「名指し」強制削除
# # （docker system pruneでは保護されて消えないため、直接指定して破壊）
# sudo docker volume rm mariadb wordpress prometheus

# # 3. ホスト側の物理データの完全消去（物理層のリセット）
# sudo rm -rf /home/samatsum/data

# # 4. Dockerデーモンの再起
# sudo systemctl restart docker

# # 5. 環境の一から再構築
# sudo make up