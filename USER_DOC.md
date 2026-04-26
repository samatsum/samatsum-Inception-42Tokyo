# User Documentation - Inception Infrastructure

This guide explains how to access and manage the services provided by the Inception infrastructure.

## 1. Accessing Services

All services are routed through the NGINX reverse proxy on port 443 via TLS. Access them using the domain `samatsum.42.fr` in your browser.

| Service | URL | Description |
| :--- | :--- | :--- |
| **WordPress** | `https://samatsum.42.fr` | The main website and blog platform. |
| **Adminer** | `https://samatsum.42.fr/adminer` | Database management tool for MariaDB. |
| **Static Site** | `https://samatsum.42.fr/static` | A lightweight portfolio/resume site. |
| **Grafana** | `https://samatsum.42.fr/grafana` | Infrastructure monitoring dashboard. |

*Note: Since we use self-signed SSL certificates, your browser will display a security warning. Please select "Advanced" and "Proceed to samatsum.42.fr" to continue.*

## 2. Credentials & Login

Authentication details are strictly managed and are not stored in the repository for security reasons.

- **WordPress Admin**: The primary administrator account (name does not include 'admin'). Check `secrets/credentials.txt` for the password.
- **WordPress User**: A regular user account. Check `secrets/wp_normal_password.txt`.
- **Database (MariaDB)**: Use credentials found in `secrets/db_password.txt` to log in via Adminer.
- **FTP Access**: Use the password in `secrets/ftp_password.txt` to connect via an FTP client on port 21.

## 3. Daily Operations (Makefile)

Standard operations should be performed using the `Makefile` in the root directory.

- **Start Services**: `sudo make up` (Starts all containers in the background).
- **Check Status**: `make status` (Displays a list of running containers and their health).
- **View Logs**: `make logs` (Streams real-time output for troubleshooting).
- **Stop Services**: `make stop` (Safely shuts down processes while keeping data and container states).
- **Restart Services**: `make start` (Resumes services from a stopped state).

## 4. File Transfers (FTP)

To modify or upload files to the WordPress site directly:
1. Open your FTP client (e.g., FileZilla).
2. Host: `samatsum.42.fr` | Port: `21`.
3. Enter the username specified in `.env` and the password from `secrets/ftp_password.txt`.
4. You will have access to the `/var/www/html` directory.