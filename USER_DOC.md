失礼いたしました。ユーザー様の意図を正解に把握しました。

`USER_DOC.md` をベースに、評価基準（`message.txt`）で求められている必須項目（起動・停止手順、アクセス方法、認証管理、基本チェック）を網羅し、さらに `Redis.txt` や `memo.md` に記載されていた Adminer や監視ツールの具体的な検証手順を統合して、英語で書き直します。

---

# USER_DOC - User Operation Guide

This guide provides the necessary information for end-users and administrators to manage and verify the Inception infrastructure. It covers basic operations, service access, and health check procedures required for the peer review.

## 1. Service Access Points

All services are routed through NGINX via **HTTPS (Port 443)**. Plain HTTP access (Port 80) is strictly forbidden and will be rejected.

| Service | Access URL / Protocol | Description |
| --- | --- | --- |
| **WordPress** | [https://samatsum.42.fr](https://samatsum.42.fr) | Main CMS website. |
| **Adminer** | [https://samatsum.42.fr/adminer](https://samatsum.42.fr/adminer) | Database management GUI. |
| **Static Site** | [https://samatsum.42.fr/site/](https://samatsum.42.fr/site/) | Independent Flask-based portfolio.

 |
| **Grafana** | [https://samatsum.42.fr/grafana/](https://samatsum.42.fr/grafana/) | Monitoring dashboard.

 |
| **Prometheus** | [https://samatsum.42.fr/prometheus](https://samatsum.42.fr/prometheus) | Metrics collection status. |
| **FTP** | `ftp://samatsum.42.fr` (Port 21) | Direct access to WordPress files.

 |

*Note: Since the infrastructure uses self-signed certificates, you must click "Advanced" and then "Proceed to samatsum.42.fr" in your browser.*

## 2. Credentials Management

For security compliance, no passwords are stored in the git repository or `.env` file. All sensitive credentials are managed via **Docker Secrets** and stored in the `secrets/` directory on the host machine.

| Credential Type | Username | Password File Location |
| --- | --- | --- |
| **WordPress Admin** | `WP_ADMIN_USER` | `secrets/credentials.txt` |
| **WordPress User** | `WP_EDITER_USER` | `secrets/wp_editer_password.txt` |
| **MariaDB User** | `MYSQL_USER` | `secrets/db_password.txt` |
| **Grafana Admin** | `GRAFANA_ADMIN_USER` | `secrets/grafana_password.txt` |
| **FTP User** | `FTP_USER` | `secrets/ftp_password.txt` |

*Note: The WordPress administrator username must not contain "admin" or "Admin".*

## 3. Infrastructure Management (Makefile)

The lifecycle of the stack is managed using the `Makefile` located in the root directory.

* **Build and Start**: `make up` (Creates volumes and starts all 9 containers).
* **Graceful Stop**: `make stop` (Sends SIGTERM to processes; maintains network state).
* **Check Status**: `make status` (Ensures all services are running).
* **Clean Teardown**: `make down` (Stops containers and removes the virtual network).
* **View Logs**: `make logs` (Real-time monitoring of container output).

## 4. Service Verification (Health Checks)

To pass the evaluation, verify the functionality of each service using the following methods:

### 4.1 WordPress & MariaDB Persistence

1. **WordPress**: Access [https://samatsum.42.fr](https://samatsum.42.fr). Log in to the dashboard and edit a page. Verify that changes are reflected on the site.
2. **MariaDB**: Access the database via CLI to prove it is not empty:
```bash
docker exec -it mariadb mariadb -u root -p
# Enter password from secrets/db_root_password.txt
USE wordpress;
SELECT * FROM wp_comments;

```


3. **Reboot Test**: Run `sudo reboot`, then `make up`. Verify that the edited page and comments still exist to prove volume persistence.

### 4-2. Adminer (Database GUI)

Access [https://samatsum.42.fr/adminer](https://samatsum.42.fr/adminer) and log in with the following:

* **System**: `MySQL`
* **Server**: `mariadb`
* **Username**: `wpuser`
* **Password**: (Content of `secrets/db_password.txt`)

### 4.3 Redis (Object Cache)

Verify that WordPress is communicating with the Redis container:

```bash
docker exec -it wordpress wp redis status --path=/var/www/html --allow-root

```

**Success Indicator**: The output must state `Status: Connected`.

### 4.4 FTP (Volume Sharing)

Verify the FTP server can manipulate the shared volume:

1. Connect via CLI: `ftp -p samatsum.42.fr` (Use Passive mode).


2. Log in as `ftpuser` and run `ls`.
3. Confirm you can see `wp-config.php` and other core files.



### 4.5 Monitoring Pipeline (Prometheus & Grafana)

1. **Prometheus**: Access [https://samatsum.42.fr/prometheus/targets](https://samatsum.42.fr/prometheus/targets) and ensure the state is a green **UP**.
2. **Grafana**: Access [https://samatsum.42.fr/grafana/](https://samatsum.42.fr/grafana/). Open the "WordPress Monitoring" dashboard to see real-time graphs of NGINX requests and PHP-FPM processes.



### 4.6 Static Site (Flask)

Access [https://samatsum.42.fr/site/](https://samatsum.42.fr/site/). The display of the portfolio confirms that NGINX is correctly reverse-proxying requests to the Python/Flask container.

---

いかがでしょうか。`message.txt` の要件（Adminer、起動/停止、認証管理、永続性テスト）をすべて盛り込み、英語で構成しました。ピアレビューの際は、このドキュメントに沿って説明を進めることで、評価項目を一つずつクリアできるはずです。