# User Documentation — Inception

This document explains how to use the Inception infrastructure as an end user or site administrator.

## Services Overview

The stack provides the following services:

**Interactive services** (accessible via browser or client):

| Service | Access | Purpose |
|---|---|---|
| WordPress | `https://samatsum.42.fr` | Blog / CMS website |
| WordPress Admin | `https://samatsum.42.fr/wp-admin` | Content and user management |
| Adminer | `https://samatsum.42.fr/adminer` | Web-based database management |
| Grafana | `https://samatsum.42.fr/grafana/` | Monitoring dashboard |
| Prometheus | `https://samatsum.42.fr/prometheus/` | Metrics explorer |
| Static Site | `https://samatsum.42.fr/site/` | Personal profile page |
| FTP | `ftp localhost` (port 21) | File transfer to WordPress volume |

**Background services** (no direct user interaction needed):

| Service | Purpose |
|---|---|
| Redis | In-memory cache for WordPress, reducing database queries |
| MariaDB | Relational database storing all WordPress data |
| NGINX | Reverse proxy and TLS termination (sole entry point) |

## Starting and Stopping

All commands must be run from the project root directory.

**Start the infrastructure:**

    sudo make up

This builds all Docker images and starts all containers. Logs are displayed in the terminal. On first run, MariaDB is initialized and WordPress is installed automatically.

**Stop the infrastructure:**

    sudo make down

Containers are removed but data persists in the volumes. The next `make up` will reuse existing data without re-initializing.

**Stop without removing containers:**

    sudo make stop

**Restart stopped containers:**

    sudo make start

**View real-time logs:**

    sudo make logs

**Check which containers are running:**

    make status

**Full clean and rebuild from scratch:**

    sudo make re

This deletes all containers, volumes, images, and host data, then rebuilds everything. All WordPress content and database data will be lost.

## Accessing the Website

Open a browser inside the VM and navigate to:

    https://samatsum.42.fr

A certificate warning will appear because the site uses a self-signed TLS certificate. This is expected and normal for this project.

In Firefox: click "Advanced..." then "Accept the Risk and Continue."
In Chrome: type `thisisunsafe` on the warning page.

## Accessing the Admin Panel

Navigate to:

    https://samatsum.42.fr/wp-admin

Log in with the administrator credentials (see "Credentials" section below). From the admin panel you can create posts, manage users, configure plugins, and change site settings.

## Accessing Adminer

Navigate to:

    https://samatsum.42.fr/adminer

Fill in the login form with these values:

| Field | Value |
|---|---|
| System | MySQL |
| Server | `mariadb` |
| Username | Value of `MYSQL_USER` in `srcs/.env` |
| Password | Content of `secrets/db_password.txt` |
| Database | Value of `MYSQL_DATABASE` in `srcs/.env` |

## Accessing Grafana

Navigate to:

    https://samatsum.42.fr/grafana/

Default login: username `admin`, password `password`. Grafana is pre-configured with Prometheus as a data source and includes a basic WordPress monitoring dashboard.

## Accessing the FTP Server

From the VM terminal:

    ftp localhost

Login with username defined by `FTP_USER` in `srcs/.env` (default: `ftpuser`) and the password stored in `secrets/ftp_password.txt`. The FTP root is the WordPress volume (`/var/www/html`).

## Credentials

Credentials are stored in two locations:

**Environment variables** (`srcs/.env`): Non-sensitive configuration such as domain name, database name, and usernames. Not tracked by Git.

**Docker secrets** (`secrets/` directory): Sensitive passwords mounted as files inside containers at runtime. Not tracked by Git.

| Secret File | Purpose |
|---|---|
| `secrets/credentials.txt` | WordPress administrator password |
| `secrets/db_password.txt` | MariaDB user password |
| `secrets/db_root_password.txt` | MariaDB root password |
| `secrets/wp_normal_password.txt` | WordPress normal user password |
| `secrets/ftp_password.txt` | FTP user password |

To change a password, edit the corresponding file and run `sudo make re` to rebuild all services with the new credentials.

## Verifying Services

To confirm all services are running:

    docker ps -a

All containers should show `Up` in the STATUS column. Expected containers: `nginx`, `wp-php`, `mariadb`, `redis`, `adminer`, `prometheus`, `grafana`, `static-site`, `ftp`.

**Quick verification checklist:**

| Check | How to verify |
|---|---|
| WordPress accessible | Open `https://samatsum.42.fr` — WordPress front page loads |
| Admin panel works | Open `https://samatsum.42.fr/wp-admin` — login succeeds |
| Database accessible | Open `https://samatsum.42.fr/adminer` — login and browse tables |
| Redis connected | In WP admin, check "Object Cache" sidebar — status shows connected |
| Grafana accessible | Open `https://samatsum.42.fr/grafana/` — dashboard loads |
| Static site accessible | Open `https://samatsum.42.fr/site/` — profile page loads |

To check container logs for errors:

    sudo make logs
