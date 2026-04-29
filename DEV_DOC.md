# Developer Documentation - Inception Infrastructure

This document provides technical details on the infrastructure's architecture and maintenance.

## 1. Technical Architecture & Service Map
The infrastructure follows a strict microservices approach.
- **NGINX**: L7 entry point, TLS v1.2/v1.3 termination.
- **WordPress**: Runs PHP-FPM 8.2.
- **MariaDB**: Relational database.

## 2. Environment Setup (From Scratch)
1. **Host Configuration**: Map the domain name specified in `.env` to `127.0.0.1` in `/etc/hosts`.
2. **Environment Variables**: Create `srcs/.env` and define variables: `DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`, `WP_ADMIN_USER`, etc.
3. **Secrets**: Create a `secrets/` folder at the root and provide the following files: `credentials.txt`, `db_password.txt`, `db_root_password.txt`, `ftp_password.txt`, `wp_normal_password.txt`.

## 3. Management Commands
- `make up`: Build and launch the infrastructure.
- `make status`: Check container health.
- `make logs`: View service logs.
- `make fclean`: Perform a deep clean of all Docker resources.

## 4. Storage & Persistence
We use Docker Named Volumes mapped to specific host paths:
- **Database**: `/home/${USER}/data/mariadb`
- **WordPress**: `/home/${USER}/data/wordpress`
- **Prometheus**: `/home/${USER}/data/prometheus`

## 5. Security Implementation
- **Secrets**: Passwords are managed via Docker Secrets and mounted as read-only files in `/run/secrets/`.
- **Process Management**: Entrypoint scripts utilize `exec` to ensure the service daemon becomes PID 1 and handles SIGTERM correctly.