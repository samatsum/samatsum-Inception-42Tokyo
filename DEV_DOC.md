# Developer Documentation — Inception

This document explains how to set up the development environment from scratch, build and run the project, and manage containers and data.

## Prerequisites

The following must be installed on the virtual machine:

- **Docker** (version 20.10 or later)
- **Docker Compose** (v2, included with Docker Desktop or installed as a plugin)
- **make**
- **git**

To install Docker and Docker Compose on Ubuntu:

    sudo apt update
    sudo apt install -y docker.io docker-compose-v2
    sudo systemctl enable docker
    sudo systemctl start docker

Ensure your user can run Docker commands (or use `sudo`):

    sudo usermod -aG docker $USER

## Building the Environment from Scratch

### 1. Clone the Repository

    git clone <repository-url>
    cd samatsum-Inception-42Tokyo

### 2. Configure the Domain

Add the domain to the VM's hosts file:

    echo "127.0.0.1 samatsum.42.fr" | sudo tee -a /etc/hosts

### 3. Create the Environment File

Create `srcs/.env` with the following variables:

    DOMAIN_NAME=samatsum.42.fr
    MYSQL_DATABASE=wordpress
    MYSQL_USER=wpuser
    WP_TITLE=inception
    WP_ADMIN_USER=supervisor
    WP_ADMIN_EMAIL=your_admin_email@example.com
    WP_NORMAL_USER=viewer
    WP_NORMAL_EMAIL=your_normal_email@example.com

Important: `WP_ADMIN_EMAIL` and `WP_NORMAL_EMAIL` must be different addresses. The admin username must not contain "admin" or "administrator."

### 4. Create the Secrets Files

    mkdir -p secrets
    echo "your_db_password" > secrets/db_password.txt
    echo "your_db_root_password" > secrets/db_root_password.txt
    echo "your_wp_admin_password" > secrets/credentials.txt
    echo "your_wp_normal_password" > secrets/wp_normal_password.txt

These files are excluded from Git via `.gitignore`. Never commit them to the repository.

### 5. Create Host Data Directories

The Makefile handles this automatically, but if you need to create them manually:

    sudo mkdir -p /home/samatsum/data/mariadb
    sudo mkdir -p /home/samatsum/data/wordpress
    sudo mkdir -p /home/samatsum/data/prometheus
    sudo chmod 755 /home/samatsum/data /home/samatsum/data/mariadb /home/samatsum/data/wordpress /home/samatsum/data/prometheus

## Building and Running with Makefile and Docker Compose

### Build and Start

    sudo make up

This runs `mkdir -p` for the data directories and then executes `docker compose -f srcs/docker-compose.yml up --build`. Containers are started in the foreground with logs attached.

### Full Rebuild

    sudo make re

This runs `fclean` (removes all containers, volumes, images, and host data) and then `up`.

### Background Mode

If you want to run in the background, use Docker Compose directly:

    sudo docker compose -f srcs/docker-compose.yml up -d --build

## Container and Volume Management Commands

### View Running Containers

    docker ps -a

### View Logs

    sudo make logs

Or for a specific container:

    docker logs <container-name>
    docker logs mariadb
    docker logs wp-php
    docker logs nginx

### Enter a Container Shell

    docker exec -it <container-name> bash

Examples:

    docker exec -it wp-php bash
    docker exec -it mariadb bash
    docker exec -it nginx bash

### Execute Commands Inside Containers

    docker exec wp-php wp user list --path=/var/www/html --allow-root
    docker exec mariadb mysqladmin ping -u root -p"$(cat secrets/db_root_password.txt)"

### Stop Containers

    sudo make stop       # Stop without removing
    sudo make down       # Stop and remove containers

### Remove Everything

    sudo make clean      # Remove containers, volumes, images
    sudo make fclean     # Full clean including system prune and host data

### Manage Volumes

List volumes:

    docker volume ls

Inspect a volume:

    docker volume inspect mariadb
    docker volume inspect wordpress

## Data Storage and Persistence

### Named Volumes

The project uses three Docker named volumes:

| Volume | Container Mount Point | Host Path | Purpose |
|---|---|---|---|
| `mariadb` | `/var/lib/mysql` | `/home/samatsum/data/mariadb` | MariaDB database files |
| `wordpress` | `/var/www/html` | `/home/samatsum/data/wordpress` | WordPress site files |
| `prometheus` | `/prometheus` | `/home/samatsum/data/prometheus` | Prometheus metrics data |

The volumes are defined in `srcs/docker-compose.yml` using the `local` driver with bind options, which maps Docker named volumes to specific directories on the host filesystem.

### Persistence Behavior

- **On `make down`**: Containers are removed, but volumes and data persist. Running `make up` again will reuse existing data without re-initializing.
- **On `make clean` / `make fclean`**: Volumes and host data directories are deleted. The next `make up` will perform a fresh initialization (MariaDB database creation, WordPress download and install).
- **On container crash**: Containers are configured with `restart: unless-stopped`, so Docker will automatically restart them.

### WordPress Initialization

The WordPress container's `script.sh` handles initialization:

1. Downloads WP-CLI if not present.
2. Downloads WordPress core files if `wp-config.php` does not exist.
3. Waits for MariaDB to become available.
4. Installs WordPress and creates the admin and normal users.
5. Configures Redis cache settings.
6. Starts PHP-FPM in the foreground (`exec php-fpm8.2 -F`).

On subsequent starts (when data persists), steps 1-5 are skipped because the data already exists.

### MariaDB Initialization

The MariaDB container's `script.sh` handles initialization:

1. If `/var/lib/mysql/mysql` does not exist, runs `mysql_install_db`.
2. Starts MariaDB temporarily to create the database, user, and grant privileges.
3. Shuts down the temporary instance.
4. Starts MariaDB in the foreground with `exec mysqld_safe`.

On subsequent starts, step 1-3 are skipped because the database directory already exists.

## Project Structure

    .
    ├── Makefile
    ├── README.md
    ├── USER_DOC.md
    ├── DEV_DOC.md
    ├── secrets/                    # Not tracked by Git
    │   ├── credentials.txt
    │   ├── db_password.txt
    │   ├── db_root_password.txt
    │   └── wp_normal_password.txt
    └── srcs/
        ├── .env                    # Not tracked by Git
        ├── docker-compose.yml
        └── requirements/
            ├── nginx/
            │   ├── Dockerfile
            │   ├── conf/default
            │   └── tools/script.sh
            ├── wordpress/
            │   ├── Dockerfile
            │   ├── conf/www.conf
            │   └── tools/script.sh
            ├── mariadb/
            │   ├── Dockerfile
            │   ├── conf/50-server.cnf
            │   └── tools/script.sh
            └── bonus/
                ├── adminer/
                ├── redis/
                └── prometheus/

## Network Architecture

All containers are connected to a single bridge network (`inception-network`). Only NGINX exposes a port to the host (443). Inter-container communication uses container names as hostnames:

- NGINX → WordPress: `fastcgi_pass wp-php:9000`
- WordPress → MariaDB: `dbhost=mariadb` (port 3306)
- WordPress → Redis: `WP_REDIS_HOST=redis` (port 6379)
- NGINX → Adminer: `fastcgi_pass adminer:8080`
