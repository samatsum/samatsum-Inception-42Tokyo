*This project has been created as part of the 42 curriculum by samatsum.*

## Description

Inception is a system administration project that virtualizes a multi-service infrastructure using Docker Compose. The architecture follows a strict microservices approach, ensuring isolation, security (TLS v1.2/v1.3), and high availability.

### Architecture (Mandatory)

```text
┌─────────────────────────────────────────────────────────────┐
│                        VM (Host)                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Docker Compose                      │  │
│  │  ┌─────────┐    ┌─────────────┐    ┌─────────────┐    │  │
│  │  │  NGINX  │◀───│  WordPress  │◀───│   MariaDB   │    │  │
│  │  │ :443    │    │  php-fpm    │    │   :3306     │    │  │
│  │  │ TLS 1.2+│    │  wp-cli     │    │             │    │  │
│  │  └────┬────┘    └──────┬──────┘    └──────┬──────┘    │  │
│  │       │                │                  │           │  │
│  │       └────────────────┴──────────────────┘           │  │
│  │                 inception-network (bridge)            │  │
│  │                                                       │  │
│  │       [volumes: wordpress, mariadb]                   │  │
│  └──────────────── │  ───────────────────────────────────┘  │
│                    │                                        │ 
│                Bind (o: bind)                               │ 
│                    │                                        │
│          [device volumes]                                   │
│            /home/samatsum/data/wordpress                    │
│            /home/samatsum/data/mariadb                      │
└─────────────────────────────────────────────────────────────┘
```

### Request Flow
```text
Browser --[HTTPS]--> NGINX --[FastCGI]--> PHP-FPM --[SQL]--> MariaDB
                (443)               (9000)              (3306)
```

---

## Instructions

### Prerequisites
- Docker Engine and Docker Compose are installed.
- Domain `samatsum.42.fr` is mapped to `127.0.0.1` in `/etc/hosts`.
- `.env` file is prepared in `srcs/.env`.
- Secrets files are prepared in `secrets/` directory.

### Build and Run

Execute the following command from the root directory:
```bash
make up
```

### Common Operations (Makefile)

| Target | Description |
|--------|-------------|
| `make up` | Build and start all containers, creating volumes locally |
| `make down` | Stop and remove containers, and destroy the network |
| `make stop` | Stop containers cleanly without destroying the network |
| `make start` | Start stopped containers |
| `make logs` | Track stdout/stderr of all containers |
| `make status` | List all containers and their status |
| `make clean` | Remove containers and volumes |
| `make fclean` | Deep clean including Docker images, volumes, and networks |
| `make re` | Deep clean and restart from scratch (`fclean` -> `up`) |

---

## Design Choices & Comparisons

### 1. Virtual Machines vs Docker
Virtual Machines (VMs) virtualize the hardware layer, requiring a complete Guest OS per instance, increasing spatial and temporal costs. Docker virtualizes at the OS kernel level using namespaces and cgroups, minimizing resource consumption and achieving near-instantaneous startup (O(1) process creation).

### 2. Secrets vs Environment Variables
Standard environment variables are visible via `docker inspect`. We use Docker Secrets, mounted into a memory-resident filesystem (`tmpfs`) at `/run/secrets/`, ensuring sensitive data (passwords) never touches the container's disk, maintaining high security.

### 3. Docker Network vs Host Network
Using the host network removes isolation between the container and the host OS. We implement a dedicated Docker Bridge Network (`inception-network`) to ensure L3 isolation. Containers only communicate via internal DNS (service names), and external exposure is strictly limited to NGINX on port 443.

### 4. Docker Volumes vs Bind Mounts
Bind mounts depend on specific host paths, leading to fragile portability. We use Named Volumes with the `local` driver and `o: bind` options to persist data in the specified path (`/home/samatsum/data`) while maintaining Docker-managed abstraction and lifecycle.

---

## Resources
- [Official Docker Documentation](https://docs.docker.com/)
- **AI Usage:** AI was utilized as a technical mentor to audit infrastructure architecture, optimize PID 1 signal propagation, and ensure strict fail-fast implementation within bash scripts. All logic was manually verified and tested.

---

### 2. `DEV_DOC.md`


# DEV_DOC - Technical Documentation for Developers

This document details the environment setup, architecture decisions, and operational commands for developers maintaining the Inception infrastructure.

## Environment Setup

### 1. Host Resolution
Map the domain to the local loopback address.
```bash
# Append to /etc/hosts (requires sudo)
127.0.0.1   samatsum.42.fr
```

### 2. Prepare `.env` File
Create `srcs/.env` with the following variables:
```env
cat << 'EOF' > srcs/.env
DOMAIN_NAME=samatsum.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=db_pass_here
MYSQL_ROOT_PASSWORD=root_pass_here
WP_ADMIN_USER=boss42
WP_ADMIN_EMAIL=admin@samatsum.42.fr
WP_NORMAL_USER=normaluser
WP_NORMAL_EMAIL=user@samatsum.42.fr
WP_TITLE=Inception_42Tokyo
EOF
```

### 3. Generate Secrets
Passwords must be securely stored in the `secrets/` directory at the project root. This directory is ignored by Git (`.gitignore`).
```bash
mkdir -p secrets

echo -n "db_pass_here" > secrets/db_password.txt
echo -n "db_root_pass_here" > secrets/db_root_password.txt
echo -n "wp_admin_pass_here" > secrets/credentials.txt
echo -n "wp_normal_pass_here" > secrets/wp_normal_password.txt
echo -n "ftp_pass_here" > secrets/ftp_password.txt
```

---

## Container Lifecycle & Management

### Build and Start
```bash
make up
```
*Note: The `Makefile` automatically ensures the correct host directories (`/home/samatsum/data/*`) are created with `755` permissions before Docker binds them, preventing root ownership conflicts.*

### Deep Clean (Reset Everything)
To completely wipe all containers, images, and data volumes:
```bash
make fclean
```

---

## Architectural Details

### PID 1 and Signal Handling (Graceful Shutdown)
To ensure a graceful shutdown (exit code 0) and eliminate `SIGKILL` (exit code 137), we handle PID 1 dynamically:
- **Core Services (MariaDB, NGINX, WordPress)**: The `exec` command is used at the end of `script.sh` to replace the shell process with the service daemon, allowing it to receive `SIGTERM` directly.
- **Bonus Services (Static-site, FTP)**: Since simple Python servers or `vsftpd` are not designed to run as PID 1, `tini` is installed in the `Dockerfile` and used as the entrypoint (`ENTRYPOINT ["/usr/bin/tini", "--", "/script.sh"]`) to forward signals and reap zombie processes correctly.

### Script Safety (Fail-Fast)
All entrypoint scripts utilize strict bash settings:
```bash
set -uo pipefail
```
This guarantees that if any command fails or an undefined variable is accessed (e.g., missing secrets mount), the script crashes immediately rather than proceeding with an unstable state.

### Race Condition Prevention
The `wordpress` initialization script implements a robust polling mechanism. It utilizes `wp db check` in a retry loop to verify L7 connectivity with `mariadb` before attempting to execute installation commands, preventing race conditions during parallel container startup.

---

### 3. `USER_DOC.md`

# USER_DOC - User Operation Guide

## Service Overview

This infrastructure hosts a secure WordPress blog alongside various administrative and monitoring bonus services. All external access is strictly routed through NGINX via HTTPS (port 443).

| Service | URL | Role |
|---------|-----|------|
| **WordPress** | `https://samatsum.42.fr` | Main blog platform |
| **Adminer** | `https://samatsum.42.fr/adminer` | DB GUI management tool |
| **Static Site** | `https://samatsum.42.fr/site/` | Lightweight portfolio |
| **Grafana** | `https://samatsum.42.fr/grafana/` | Monitoring dashboard |
| **Prometheus** | `https://samatsum.42.fr/prometheus/` | Metrics collection |

*Note: As the project uses a self-signed TLS certificate, your browser will display a security warning. You must click "Advanced" and "Proceed to samatsum.42.fr" to access the services.*

---

## Start / Stop Commands

You can manage the infrastructure using the provided `Makefile` at the root of the project.

| Action | Command |
|--------|---------|
| **Start Infrastructure** | `make up` |
| **Stop Safely** | `make stop` |
| **Resume Services** | `make start` |
| **Check Health** | `make status` |
| **View Live Logs** | `make logs` |

---

## Credentials & Access

For security, passwords are not hardcoded. They are read from the `secrets/` folder managed by the administrator.

### WordPress Access
- **Admin Panel URL**: `https://samatsum.42.fr/wp-admin`
- **Username**: Defined in `.env` (`WP_ADMIN_USER`)
- **Password**: Found in `secrets/credentials.txt`

### Database Management (Adminer)
- **URL**: `https://samatsum.42.fr/adminer`
- **System**: `MySQL`
- **Server**: `mariadb` *(Internal Docker DNS name)*
- **Username**: Defined in `.env` (`MYSQL_USER`)
- **Password**: Found in `secrets/db_password.txt`
- **Database**: Defined in `.env` (`MYSQL_DATABASE`)

### File Transfer (FTP)
You can directly upload or modify WordPress files via FTP.
- **Host**: `samatsum.42.fr`
- **Port**: `21`
- **Username**: Defined in `.env` (or default `ftpuser`)
- **Password**: Found in `secrets/ftp_password.txt`

---

## Troubleshooting

### 1. Changes aren't updating (Caching)
If your WordPress changes are not appearing instantly, it may be due to the Redis object cache. Wait a few moments, or flush the cache via the WordPress admin panel.

### 2. 502 Bad Gateway
If you see a `502 Bad Gateway` when accessing WordPress or Adminer, the PHP-FPM container is likely still initializing. Wait approximately 10-15 seconds and refresh the page. You can track the progress by running `make logs`.

### 3. Complete Reset
If the system state is corrupted or you forgot the database credentials, you can completely destroy the infrastructure and its data to start fresh:
```bash
make fclean
make up
```
*(Warning: `make fclean` permanently deletes all database entries and WordPress posts).*
