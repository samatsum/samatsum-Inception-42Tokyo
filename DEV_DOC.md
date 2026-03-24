# Developer Documentation — Inception

This document explains how to set up the development environment from scratch, build and run the project, and manage containers and data.

## Prerequisites

The following must be installed on the virtual machine:

| Tool | Version | Purpose |
|---|---|---|
| Docker | 20.10+ | Container runtime |
| Docker Compose | v2 | Service orchestration |
| make | any | Build automation |
| git | any | Version control |

To install on Ubuntu:

    sudo apt update
    sudo apt install -y docker.io docker-compose-v2 make git
    sudo systemctl enable docker
    sudo systemctl start docker

To allow your user to run Docker without `sudo`:

    sudo usermod -aG docker $USER

Log out and back in for the group change to take effect.

## Building the Environment from Scratch

### 1. Clone the Repository

    git clone <repository-url>
    cd samatsum-Inception-42Tokyo

### 2. Configure the Domain

    echo "127.0.0.1 samatsum.42.fr" | sudo tee -a /etc/hosts

### 3. Create the Environment File

Create `srcs/.env` with the following content:

    DOMAIN_NAME=samatsum.42.fr
    MYSQL_DATABASE=wordpress
    MYSQL_USER=wpuser
    WP_TITLE=inception
    WP_ADMIN_USER=supervisor
    WP_ADMIN_EMAIL=admin@example.com
    WP_NORMAL_USER=viewer
    WP_NORMAL_EMAIL=viewer@example.com

Important: `WP_ADMIN_EMAIL` and `WP_NORMAL_EMAIL` must be different addresses. The admin username must not contain "admin" or "administrator" (subject requirement).

### 4. Create the Secrets Files

    mkdir -p secrets
    echo "your_db_password" > secrets/db_password.txt
    echo "your_db_root_password" > secrets/db_root_password.txt
    echo "your_wp_admin_password" > secrets/credentials.txt
    echo "your_wp_normal_password" > secrets/wp_normal_password.txt
    echo "your_ftp_password" > secrets/ftp_password.txt

These files are excluded from Git via `.gitignore`. Never commit them.

### 5. Build and Start

    sudo make up

This creates host data directories, builds all Docker images, and starts all containers.

## Makefile Targets

| Target | What it does |
|---|---|
| `make up` | `mkdir -p` for data dirs, then `docker compose up --build` |
| `make down` | `docker compose down` (removes containers, keeps volumes) |
| `make stop` | `docker compose stop` (stops without removing) |
| `make start` | `docker compose start` (restarts stopped containers) |
| `make logs` | `docker compose logs -f` (follow all logs) |
| `make status` | `docker ps` |
| `make clean` | `docker compose down -v --rmi all --remove-orphans` + delete host data |
| `make fclean` | `clean` + `docker system prune -af` |
| `make re` | `fclean` + `up` |

Important: Always use `make` targets instead of calling `docker compose` directly. The Makefile's `up` target creates host data directories (`/home/samatsum/data/{mariadb,wordpress,prometheus}`) that are required for volume mounts. Skipping this step causes mount failures.

## Container Management

### View running containers

    docker ps -a

### View logs for a specific container

    docker logs <container-name>
    docker logs -f wp-php          # follow WordPress logs
    docker logs --tail 50 mariadb  # last 50 lines

### Enter a container shell

    docker exec -it <container-name> bash

### Execute commands inside containers

    docker exec wp-php wp user list --path=/var/www/html --allow-root
    docker exec mariadb mysqladmin ping -u root -p"$(cat secrets/db_root_password.txt)"
    docker exec redis redis-cli ping

### Manage volumes

    docker volume ls                    # list all volumes
    docker volume inspect mariadb       # inspect a specific volume

## Network Architecture

All containers are connected to a single bridge network (`inception-network`). Only NGINX exposes a port to the host.

| Source | Destination | Protocol | Port |
|---|---|---|---|
| Host / Browser | NGINX | HTTPS | 443 |
| NGINX | WordPress (wp-php) | FastCGI | 9000 |
| NGINX | Adminer | FastCGI | 8080 |
| NGINX | Grafana | HTTP proxy | 3000 |
| NGINX | Prometheus | HTTP proxy | 9090 |
| NGINX | Static Site | HTTP proxy | 5000 |
| WordPress | MariaDB | MySQL | 3306 |
| WordPress | Redis | Redis | 6379 |
| Grafana | Prometheus | HTTP | 9090 |
| Host | FTP (ftp) | FTP | 21, 21100-21110 |

Container names are used as hostnames (Docker's embedded DNS resolves them within the bridge network).

## Data Storage and Persistence

### Named Volumes

| Volume Name | Container Mount | Host Path | Purpose |
|---|---|---|---|
| `mariadb` | `/var/lib/mysql` | `/home/samatsum/data/mariadb` | Database files |
| `wordpress` | `/var/www/html` | `/home/samatsum/data/wordpress` | WordPress site files |
| `prometheus` | `/prometheus` | `/home/samatsum/data/prometheus` | Metrics time-series data |

Volumes use the `local` driver with `type: none` and `o: bind` to map Docker-managed named volumes to specific host directories. This satisfies both the named volume requirement and the host path requirement.

### Persistence Behavior

| Action | Containers | Volumes/Data | Next startup |
|---|---|---|---|
| `make down` | Removed | Preserved | Reuses existing data |
| `make stop` | Stopped | Preserved | Resumes from stopped state |
| `make clean` | Removed | Deleted | Fresh initialization |
| `make fclean` | Removed | Deleted + prune | Fresh initialization |
| Container crash | Auto-restarts | Preserved | Automatic (`restart: unless-stopped`) |

### Initialization Flow

**MariaDB** (`srcs/requirements/mariadb/tools/script.sh`):
First run: `mysql_install_db` → start temporary instance → create database, user, grant privileges → shutdown → start foreground with `exec mysqld_safe`.
Subsequent runs: Skip initialization (checks for `/var/lib/mysql/mysql`), start directly.

**WordPress** (`srcs/requirements/wordpress/tools/script.sh`):
First run: Download wp-cli → download WordPress core → create `wp-config.php` (with `--skip-check`) → wait for MariaDB (`wp db check` loop) → install WordPress → create users → configure Redis → start PHP-FPM.
Subsequent runs: Skip download/install steps, start PHP-FPM directly.

## Troubleshooting

**MariaDB fails to start / "Can't connect to MySQL server"**
Check if the data directory has correct permissions: `ls -la /home/samatsum/data/mariadb/`. The MariaDB entrypoint runs as root. If the directory is empty, MariaDB will initialize on next start. If corrupted, run `sudo make re` for a clean rebuild.

**WordPress shows "Error establishing a database connection"**
MariaDB may not be ready yet. WordPress retries via `wp db check` but if the loop times out, restart: `sudo make down && sudo make up`. Verify MariaDB is healthy: `docker exec mariadb mysqladmin ping -u root -p"$(cat secrets/db_root_password.txt)"`.

**"502 Bad Gateway" from NGINX**
The WordPress PHP-FPM container is not ready or has crashed. Check: `docker logs wp-php`. Ensure the `www.conf` listen directive matches the NGINX `fastcgi_pass` setting (`wp-php:9000`).

**Certificate warning in browser**
Expected behavior with self-signed certificates. Accept the warning to proceed.

**Port 443 already in use**
Another service (e.g., Apache2) may be using port 443. Check: `sudo lsof -i :443`. If Apache2 is running: `sudo systemctl stop apache2 && sudo systemctl disable apache2`.

**Volumes not mounting / "no such file or directory"**
Host data directories may not exist. Always use `make up` (which runs `mkdir -p`), not `docker compose up` directly.

**Grafana shows "%(domain)s" literally in URLs**
Grafana 12.x broke the `%(variable)` syntax in `grafana.ini`. The domain must be hardcoded directly (already fixed in this project).

## Pre-Defense Verification

Run this command to verify all requirements before defense:

    echo "=== Container Status ==="
    docker ps -a
    echo ""
    echo "=== Port Exposure ==="
    docker ps --format "{{.Names}}: {{.Ports}}"
    echo ""
    echo "=== TLS Version ==="
    curl -vk https://samatsum.42.fr 2>&1 | grep -i "tls\|ssl" | head -5
    echo ""
    echo "=== Network ==="
    docker network inspect inception-network --format '{{range .Containers}}{{.Name}} {{end}}'
    echo ""
    echo "=== Volumes ==="
    docker volume ls
    echo ""
    echo "=== Host Data ==="
    ls /home/samatsum/data/mariadb/ | head -5
    ls /home/samatsum/data/wordpress/ | head -5
    echo ""
    echo "=== WP Users ==="
    docker exec wp-php wp user list --path=/var/www/html --allow-root
    echo ""
    echo "=== Password in Dockerfiles ==="
    grep -ri "password" srcs/requirements/*/Dockerfile srcs/requirements/bonus/*/Dockerfile || echo "OK: none found"
    echo ""
    echo "=== Latest Tag ==="
    grep -r "latest" srcs/requirements/*/Dockerfile srcs/requirements/bonus/*/Dockerfile || echo "OK: none found"
    echo ""
    echo "=== Hack Commands ==="
    grep -rE "tail -f|sleep infinity|while true" srcs/requirements/*/tools/script.sh srcs/requirements/bonus/*/tools/script.sh || echo "OK: none found"
    echo ""
    echo "=== Forbidden Network Config ==="
    grep -E "network.*host|links:" srcs/docker-compose.yml || echo "OK: none found"
