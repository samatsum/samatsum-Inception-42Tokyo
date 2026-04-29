# User Documentation - Inception Infrastructure

This guide explains how to access and manage the services provided by the Inception infrastructure.

## 1. Accessing Services
All services are routed through NGINX on port 443 via TLS.

| Service | URL | Description |
| :--- | :--- | :--- |
| **WordPress** | `https://${DOMAIN_NAME}` | Main blog platform. |
| **Adminer** | `https://${DOMAIN_NAME}/adminer` | DB management tool. |
| **Static Site** | `https://${DOMAIN_NAME}/static` | Portfolio site. |
| **Grafana** | `https://${DOMAIN_NAME}/grafana` | Monitoring dashboard. |

## 2. Credentials & Login

### WordPress Admin Panel
- **URL**: `https://${DOMAIN_NAME}/wp-admin`
- **Username**: Defined by `WP_ADMIN_USER` in your `.env` file.
- **Password**: Found in `secrets/credentials.txt`.

### Adminer (Database Login)
- **URL**: `https://${DOMAIN_NAME}/adminer`
- **System**: `MySQL`
- **Server**: `mariadb` (Internal Docker DNS)
- **Username**: Defined by `MYSQL_USER` in your `.env` file.
- **Password**: Found in `secrets/db_password.txt`.
- **Database**: Defined by `MYSQL_DATABASE` in your `.env` file.

## 3. Daily Operations (Makefile)
- **Start**: `sudo make up`.
- **Check Status**: `make status`.
- **Stop**: `make stop`.

## 4. Health Check
To verify the system is running correctly, run `make status`. All containers should show `Up`. You can also run `make logs` to see real-time output.