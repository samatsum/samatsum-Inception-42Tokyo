# Developer Documentation - Inception Infrastructure

This document provides technical details on the infrastructure's architecture, implementation choices, and maintenance procedures for developers.

## 1. Technical Architecture & Service Map

The infrastructure follows a strict microservices approach, ensuring each service runs in an isolated container with its own lifecycle.

### Core Services
* **NGINX**: Acts as the L7 entry point and reverse proxy. It handles TLS v1.2/v1.3 termination and routes traffic to WordPress, Adminer, Static-Site, and Grafana via URL paths.
* **WordPress**: Runs PHP-FPM 8.2 to process application logic. It depends on MariaDB and connects via internal Docker DNS.
* **MariaDB**: The relational database. It is configured to accept connections only from within the internal bridge network.

### Bonus Services
* **Redis**: In-memory cache for WordPress to reduce DB read time complexity to O(1).
* **Adminer**: GUI for MariaDB management.
* **Prometheus**: Time-series database (TSDB) for metrics collection.
* **Grafana**: Dashboard for Prometheus data visualization.
* **Static-Site**: Python/Flask based stateless web application.
* **FTP Server**: `vsftpd` for direct file manipulation on the WordPress volume.

## 2. Implementation Details

### PID 1 and Signal Handling
To ensure graceful shutdowns (exit code 0), all entrypoint scripts utilize the `exec` command to replace the shell process with the service daemon. This allows the daemon to receive SIGTERM directly from the Docker engine.

### Initialization Idempotency
Service scripts verify the current state before initializing:
* **MariaDB**: Checks if `/var/lib/mysql/mysql` exists before running `mysql_install_db`.
* **WordPress**: Checks for `wp-config.php` before executing setup commands.

### Race Condition Handling
The WordPress initialization script performs a L7 health check on MariaDB using `wp db check` in a retry loop. This ensures the database is fully ready to accept queries before WordPress attempts installation.

## 3. Storage & Persistence

We use **Docker Named Volumes** mapped to specific host paths to comply with the subject requirements:
* **Database**: `/home/samatsum/data/mariadb`
* **WordPress**: `/home/samatsum/data/wordpress`

The `Makefile` ensures these directories exist with correct permissions (`755`) before the containers start, preventing Docker from auto-creating them as root-owned directories.

## 4. Security

* **Secrets**: All passwords (DB, WP Admin, FTP) are managed via Docker Secrets and mounted as read-only files in `/run/secrets/`.
* **Log Protection**: Shell scripts use `set +x` before expanding secret variables to prevent passwords from leaking into stderr/stdout logs during debug sessions.