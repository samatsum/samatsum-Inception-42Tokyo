```markdown
# USER_DOC - User Operation Guide

This guide provides essential information for end-users and administrators to interact with the Inception infrastructure and verify its services.

---

## 1. Service Access Points

All web services are securely routed through NGINX via HTTPS (Port 443).

| Service | Access URL / Protocol | Description |
| :--- | :--- | :--- |
| **WordPress** | [https://samatsum.42.fr](https://samatsum.42.fr) | Main website and content management. |
| **Adminer** | [https://samatsum.42.fr/adminer](https://samatsum.42.fr/adminer) | Database management interface. |
| **Static Site** | [https://samatsum.42.fr/site/](https://samatsum.42.fr/site/) | Independent Flask-based portfolio site. |
| **Grafana** | [https://samatsum.42.fr/grafana/](https://samatsum.42.fr/grafana/) | Real-time monitoring dashboard. |
| **Prometheus** | [https://samatsum.42.fr/prometheus](https://samatsum.42.fr/prometheus) | Raw metrics and monitoring status. |
| **FTP** | `ftp://samatsum.42.fr` (Port 21) | Direct file access to the WordPress volume. |

*Note: Since the infrastructure uses self-signed certificates, you must click "Advanced" -> "Proceed" in your browser.*

---

## 2. Credentials Management

For maximum security, passwords are not stored in the environment configuration. They are located in the `secrets/` directory on the host machine.

| Credential | Key | Password File Location |
| :--- | :--- | :--- |
| **WP Admin** | `WP_ADMIN_USER` | `secrets/credentials.txt` |
| **WP User** | `WP_NORMAL_USER` | `secrets/wp_normal_password.txt` |
| **Database** | `MYSQL_USER` | `secrets/db_password.txt` |
| **Grafana** | `GRAFANA_ADMIN_USER` | `grafana_password.txt` |
| **FTP** | `ftpuser` | `secrets/ftp_password.txt` |


---

## 3. Basic Operations

Use the `Makefile` at the root of the project to manage the stack lifecycle.

- **Start Infrastructure**: `make up`
- **Graceful Stop**: `make stop` (Keeps network/IPs intact)
- **Check Status**: `make status` (Verifies all 9 containers are `Up`)
- **View Logs**: `make logs` (Monitor real-time application behavior)

---

## 4. Service Verification (Health Check)

To ensure the infrastructure is functioning beyond just "running," perform the following checks:

### 4.1 WordPress & Redis (L7 Integration)
Verify that the Object Cache is correctly talking to the Redis container:
```bash
docker exec -it wordpress wp redis status --path=/var/www/html --allow-root

```

**Success Indicator**: Output should state `Status: Connected`.

### 4.2 FTP (Volume Sharing)

Verify that the FTP server can see and modify the WordPress filesystem:

1. Connect via CLI: `ftp -p samatsum.42.fr` (Use Passive mode).
2. Login with `ftpuser` and the secret password.
3. Run `ls`. You should see `wp-config.php` and other WordPress core files.

### 4.3 Monitoring (Data Pipeline)

Verify that Prometheus is scraping metrics:

1. Access [https://samatsum.42.fr/prometheus/targets](https://www.google.com/search?q=https://samatsum.42.fr/prometheus/targets).
2. Ensure the `prometheus` endpoint is green and marked as **UP**.

### 4.4 Static Site (Flask)

Access [https://samatsum.42.fr/site/](https://samatsum.42.fr/site/) and verify the page loads. This confirms the NGINX L7 proxy is correctly stripping the `/site/` path and forwarding requests to the Python backend.

