# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: samatsum <samatsum@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/12/26 20:22:22 by samatsum          #+#    #+#              #
#    Updated: 2026/02/14 14:16:58 by samatsum         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Makefile

# Configuration
COMPOSE = docker compose -f srcs/docker-compose.yml
VOLUME = /home/samatsum/data

all: up

up:
	@mkdir -p $(VOLUME)/mariadb
	@mkdir -p $(VOLUME)/wordpress
	@mkdir -p $(VOLUME)/prometheus
	@chmod 755 $(VOLUME)
	@chmod 755 $(VOLUME)/mariadb
	@chmod 755 $(VOLUME)/wordpress
	@chmod 755 $(VOLUME)/prometheus
	@$(COMPOSE) up --build

down:
	@$(COMPOSE) down

stop:
	@$(COMPOSE) stop

start:
	@$(COMPOSE) start

logs:
	@$(COMPOSE) logs -f

status:
	@docker ps


#コンテナ内で生成されたファイルとホストユーザーとの間で権限の不一致が起きるため、sudoでの実行を前提としている
clean:
	@$(COMPOSE) down -v --rmi all --remove-orphans 2>/dev/null || true
	@rm -rf $(VOLUME)

fclean: clean
	@docker system prune -af 2>/dev/null || true
	@rm -rf $(VOLUME)

re: fclean up

.PHONY: all up down stop start logs status clean fclean re
