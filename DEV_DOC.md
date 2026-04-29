# DEV_DOC - Technical Documentation for Developers

This document describes how to set up, build, manage, and understand the internal architecture of the Inception infrastructure. It is designed for successor engineers and peer-evaluators to facilitate maintenance and extension.

---

## 1. Environment Setup (From Scratch)

### 1.1 Prerequisites
- Docker Engine and Docker Compose are installed.
- `make` utility is available.
- Host machine has the required data directories available.

### 1.2 Host Resolution
Map the project domain to the local loopback address to allow local testing.
```bash
# Append to /etc/hosts (requires sudo)
127.0.0.1   samatsum.42.fr
```

### 1.3 Configuration Files (`.env`)
To ensure idempotency and eliminate manual copy-pasting errors, generate the `.env` file using the following command. This creates the file in the `srcs/` directory with restricted permissions.

```bash
mkdir -p srcs

cat << 'EOF' > srcs/.env
DOMAIN_NAME=samatsum.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
# Note: Passwords are NOT defined here for security reasons.
# They are managed via Docker Secrets (see section 1.4).
WP_ADMIN_USER=boss42
WP_ADMIN_EMAIL=admin@samatsum.42.fr
WP_NORMAL_USER=normaluser
WP_NORMAL_EMAIL=user@samatsum.42.fr
WP_TITLE=Inception_42Tokyo
EOF

chmod 600 srcs/.env
```

### 1.4 Secrets Management
To achieve maximum security, passwords must not be passed as standard environment variables. Instead, they are stored as files in the `secrets/` directory and mounted into the containers at runtime. The applications are configured to read these via `_FILE` environment variables (e.g., `MYSQL_PASSWORD_FILE`).

```bash
mkdir -p secrets

echo -n "db_pass_here" > secrets/db_password.txt
echo -n "db_root_pass_here" > secrets/db_root_password.txt
echo -n "wp_admin_pass_here" > secrets/credentials.txt
echo -n "wp_normal_pass_here" > secrets/wp_normal_password.txt

chmod 600 secrets/*.txt
```

---

## 2. Build and Launch

### 2.1 Makefile Targets

The `Makefile` at the root directory abstracts Docker Compose commands for operational efficiency.

| Target | Description |
|--------|-------------|
| `make up` | Build images (if needed) and start all containers. |
| `make build` | Force rebuild of Docker images without using cache. |
| `make down` | Stop containers and remove the network. |
| `make stop` | Stop containers cleanly without destroying the network. |
| `make start` | Start stopped containers. |
| `make logs` | Track stdout/stderr of all containers. |
| `make fclean`| Deep clean: removes containers, images, networks, and data volumes. |

### 2.2 First Launch
Navigate to the root directory and execute:
```bash
make up
```

---

## 3. Container Lifecycle & Architectural Details

Strict adherence to the "One Process Per Container" and "Foreground Execution" rules is enforced across all services. 

### 3.1 Startup Flow & Background Prohibition
All services must run in the foreground to replace the shell as PID 1. This prevents zombie processes and ensures signals (like `SIGTERM`) are caught correctly for graceful shutdowns.

- **MariaDB**: 
  - `entrypoint.sh` initializes the database if `/var/lib/mysql/mysql` is missing.
  - Final execution: `exec mariadbd --user=mysql` (Foreground).
- **WordPress (PHP-FPM)**: 
  - **Race Condition Prevention**: The script uses `wp db check` in a loop to poll MariaDB until it is fully ready before attempting core installation.
  - Final execution: `exec php-fpm8.3 -F` (Foreground).
- **NGINX**: 
  - Final execution: `nginx -g "daemon off;"` (Foreground).

### 3.2 Strict Port 80 Rejection
To ensure robust security and enforce HTTPS, port 80 (HTTP) is explicitly dropped/rejected in the NGINX configuration, rather than simply being unexposed. Even if a request reaches the server, it is explicitly denied at the server block level, prioritizing strict protocol compliance over slight performance overhead.

### 3.3 Script Safety (Fail-Fast)
All entrypoint scripts (`script.sh` / `entrypoint.sh`) begin with:
```bash
set -uo pipefail
```
This guarantees that any failure (e.g., a missing secret file or a failed DB ping) immediately crashes the script rather than allowing the container to run in an unstable state.

---

## 4. Data Storage and Persistence

Project data must persist across container restarts and VM reboots. This is achieved using Docker Named Volumes backed by host bind mounts.

### 4.1 Volume Design

Data is strictly separated and stored on the host machine at `/home/samatsum/data/`.

```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/samatsum/data/mariadb
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/samatsum/data/wordpress
```
**Why this approach?**

By using `local` volumes with the `bind` option, we retain Docker's volume management abstraction while enforcing exactly where the data lives on the host filesystem. This prevents data loss when using `docker-compose down`.

### 4.2 Complete Reset (fclean)

```bash
make fclean
```