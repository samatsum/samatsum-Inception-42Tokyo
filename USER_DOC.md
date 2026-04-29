# USER_DOC - User Operation Guide

This document provides essential information for end-users and administrators to interact with the Inception infrastructure.

## 1. Service Overview

The stack provides a full-featured WordPress environment with additional management and optimization tools.

| Service | Role | Access / Protocol |
| :--- | :--- | :--- |
| **NGINX** | Secure Gateway (TLS 1.2/1.3) | `https://samatsum.42.fr` |
| **WordPress** | Content Management System | Via NGINX |
| **Adminer** | Database Management Tool | `https://samatsum.42.fr/adminer` |
| **MariaDB** | Relational Database | Internal only |
| **Redis** | Object Cache (Speed Optimization) | Internal only |
| **FTP (vsftpd)** | File Transfer Service | `ftp://samatsum.42.fr` (Port 21) |

---

## 2. Starting and Stopping the Project

All operations are managed through the `Makefile` located in the project root.

### Start the Infrastructure
```bash
make up
```
*Note: On the first run, the system will automatically build images and initialize the database. This may take a minute.*

### Stop the Infrastructure
```bash
# To stop containers while preserving data
make down

# To completely remove containers, networks, and all persistent data
make fclean
```

---

## 3. Accessing the Platform

### 3.1 WordPress Website
- **Main Site**: [https://samatsum.42.fr](https://samatsum.42.fr)
- **Admin Dashboard**: [https://samatsum.42.fr/wp-admin](https://samatsum.42.fr/wp-admin)

### 3.2 Database Management (Adminer)
Adminer allows you to manage the MariaDB database via a web interface.
- **URL**: [https://samatsum.42.fr/adminer](https://samatsum.42.fr/adminer)
- **Server**: `mariadb`
- **Username/Password**: See Section 4.

### 3.3 FTP Access
Use an FTP client (like FileZilla) to manage WordPress files.
- **Host**: `samatsum.42.fr`
- **Port**: `21`

---

## 4. Credentials Management

For security, passwords are NOT stored in the `.env` file. They are stored in plain text files within the `srcs/secrets/` directory.

| Credential | Location |
| :--- | :--- |
| **WP Admin Password** | `srcs/secrets/credentials.txt` |
| **DB User Password** | `srcs/secrets/db_password.txt` |
| **FTP User Password** | `srcs/secrets/ftp_password.txt` |

*Note: Access to the `srcs/secrets/` directory is restricted to the host user.*

---

## 5. Verifying Service Health

To ensure all services are running correctly, use the following methods:

### 5.1 Check Container Status
Run the following command to see the status of all services:
```bash
docker ps
```
All services should have a status of `Up` (or `Up (healthy)` if health checks are implemented).

### 5.2 Monitor Real-time Logs
If a service (like WordPress) is not responding, check the logs for errors:
```bash
make logs
```

### 5.3 Verify SSL/TLS
You can verify that NGINX is correctly serving over HTTPS using `curl`:
```bash
curl -I https://samatsum.42.fr
```