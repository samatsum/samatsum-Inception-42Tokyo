```markdown
# DEV_DOC - Developer Setup Guide

This document provides the exact procedural steps for developers to clone, set up, and manage the Inception infrastructure in a local environment.

---

## 1. Prerequisites

Before starting, ensure your host machine (Linux VM) meets the following requirements. This stack runs 9 concurrent containers and requires adequate resources.

### 1.1 Hardware & OS Requirements
- **OS**: Ubuntu 22.04 LTS (Jammy Jellyfish) [Kernel 6.8.0+]
- **Architecture**: x86_64
- **CPU**: Multi-core processor (Tested on 5 cores)
- **Memory (RAM)**: Minimum 4GB, **8GB recommended** (Tested with 8.4GB). Essential for stable operation of in-memory caches and MariaDB.
- **Storage**: At least 15-20GB of free disk space.

### 1.2 Software Requirements
- **Git**: For cloning the repository.
- **Docker Engine & Docker Compose (V2)**
- **Make**: For automating setup tasks.
- **Sudo/Root Privileges**: Required to edit `/etc/hosts`, restart the Docker daemon, and manage local volume directories.

---

## 2. Setup Procedure

### Step 2.1: Clone the Repository
Clone the project to your local machine and navigate into the root directory.
```bash
git clone <your_repository_url> samatsum-inception
cd samatsum-inception

```

### Step 2.2: Host Resolution

To allow local testing via the browser with TLS certificates, map the project domain to the local loopback address.

```bash
# Append to /etc/hosts (requires sudo)
127.0.0.1   samatsum.42.fr

```

### Step 2.3: Configuration Files (`.env`)

Generate the `.env` file in the `srcs/` directory to hold non-sensitive configuration variables.

```bash
mkdir -p srcs
cat << 'EOF' > srcs/.env
DOMAIN_NAME=samatsum.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
WP_TITLE=inception
WP_ADMIN_USER=supervisor
WP_ADMIN_EMAIL=zunandkun@gmail.com
WP_EDITER_USER=editer
WP_EDITER_EMAIL=matsumotosanshiro@gmail.com
FTP_USER=ftpuser
GRAFANA_ADMIN_USER=admin
EOF
chmod 400 srcs/.env

```

### Step 2.4: Secrets Management

Passwords must **not** be stored in `.env`. Store them in the `secrets/` directory (which is ignored by Git). These will be mounted securely into the containers at runtime.

```bash
mkdir -p secrets
echo -n "db_pass_here" > secrets/db_password.txt
echo -n "db_root_pass_here" > secrets/db_root_password.txt
echo -n "wp_admin_pass_here" > secrets/credentials.txt
echo -n "wp_editer_pass_here" > secrets/wp_editer_password.txt
echo -n "ftp_pass_here" > secrets/ftp_password.txt
echo -n "grafana_pass_here" > secrets/grafana_password.txt
chmod 400 secrets/*.txt

```

---

## 3. Makefile Usage

The `Makefile` at the root directory abstracts complex setup and teardown operations.

| Target | Action |
| --- | --- |
| `make up` | Creates host volume directories with `chmod 755`, builds images, and starts all containers. |
| `make down` | Stops containers and destroys the L3 virtual network. (Host data is preserved). |
| `make stop` | Gracefully stops container processes (SIGTERM) without destroying the network. |
| `make start` | Wakes up containers from the `stop` state. |
| `make logs` | Displays real-time `stdout`/`stderr` logs for all containers. |
| `make status` | Lists all containers and their current state (`docker container ls -a`). |
| `make clean` | Removes project containers, images, and orphaned networks safely (`--remove-orphans`). |
| `make fclean` | Executes `clean`, prunes the docker system, removes named volumes, and wipes physical host data (`/home/samatsum/data`). |
| `make emergency` | **[Ultimate Reset]** Restarts Docker daemon (`systemctl`), forcefully removes all global containers, prunes system, and wipes physical host data. |
| `make re` | Executes `fclean` followed by `up` for a complete reset. |

**To launch the infrastructure for the first time, simply run:**

```bash
make up

```

---

## 4. Docker Compose Commands

If you need to bypass the Makefile for debugging, you can use the raw `docker compose` commands against the configuration file located at `srcs/docker-compose.yml`.

* **Build and Run (Detached)**: `docker compose -f srcs/docker-compose.yml up --build -d`
* **Stop and remove containers**: `docker compose -f srcs/docker-compose.yml down`
* **Remove everything including volumes**: `docker compose -f srcs/docker-compose.yml down -v`
* **View logs for a specific container**: `docker compose -f srcs/docker-compose.yml logs -f wordpress`

---

## 5. Data Persistence

To ensure data survives container destruction (`make down`), this project uses Docker Named Volumes backed by **Host Bind Mounts**.

Data is strictly separated into three distinct host directories under `/home/samatsum/data/`:

1. **`/home/samatsum/data/mariadb`**: Stores the relational database files.
2. **`/home/samatsum/data/wordpress`**: Stores WordPress core files, themes, and uploaded media. Shared with the FTP container.
3. **`/home/samatsum/data/prometheus`**: Stores time-series metric data for Grafana dashboards.

*Note: The `make up` command automatically executes `mkdir -p` and `chmod 755` on these host directories before Docker attempts to bind them. This prevents permission errors caused by Docker creating directories as `root`.*

---

## Next Steps

Once `make up` has completed successfully, the environment is fully operational.
Please refer to **`USER_DOC.md`** for instructions on how to access the services, log into the dashboards, and verify the health of the infrastructure.
