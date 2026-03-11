# User Documentation — Inception

This document explains how to use the Inception infrastructure as an end user or site administrator.

## Services Overview

The stack provides the following services:

- **WordPress Website** — A fully functional blog/CMS accessible via HTTPS.
- **WordPress Admin Panel** — A dashboard for managing content, users, themes, and plugins.
- **Adminer** — A web-based tool for browsing and managing the MariaDB database.
- **Redis Cache** — Runs in the background to speed up WordPress by caching frequently accessed data. No user interaction is needed.
- **Prometheus** — Runs in the background to collect system metrics. No user interaction is needed.

## Starting and Stopping the Project

All commands must be run from the project root directory (`samatsum-Inception-42Tokyo/`).

To start the infrastructure:

    sudo make up

To stop the infrastructure (containers are removed):

    sudo make down

To stop containers without removing them:

    sudo make stop

To restart stopped containers:

    sudo make start

To view real-time logs from all services:

    sudo make logs

To check which containers are running:

    make status

To fully clean everything and rebuild from scratch:

    sudo make re

## Accessing the Website

Open a browser inside the VM and navigate to:

    https://samatsum.42.fr

A certificate warning will appear because the site uses a self-signed TLS certificate. This is expected. In Firefox, click "Advanced..." and then "Accept the Risk and Continue."

## Accessing the Admin Panel

Navigate to:

    https://samatsum.42.fr/wp-admin

Log in with the administrator credentials. The admin username and password are stored in the secrets files (see "Credentials" section below).

## Accessing Adminer (Database Management)

Navigate to:

    https://samatsum.42.fr/adminer

Fill in the login form:

- **System**: MySQL
- **Server**: `mariadb`
- **Username**: The value of `MYSQL_USER` in `srcs/.env`
- **Password**: The content of `secrets/db_password.txt`
- **Database**: The value of `MYSQL_DATABASE` in `srcs/.env`

## Credentials

Credentials are stored in two locations:

**Environment variables** (`srcs/.env`) — Contains non-sensitive configuration such as domain name, database name, and usernames. This file is not tracked by Git.

**Docker secrets** (`secrets/` directory) — Contains sensitive passwords:

- `secrets/credentials.txt` — WordPress administrator password
- `secrets/db_password.txt` — MariaDB user password
- `secrets/db_root_password.txt` — MariaDB root password
- `secrets/wp_normal_password.txt` — WordPress normal user password

These files are not tracked by Git (excluded via `.gitignore`). If you need to change a password, edit the corresponding file and run `sudo make re` to rebuild.

## Verifying Services Are Working

To confirm all services are running:

    docker ps -a

All containers should show `Up` in the STATUS column. The expected containers are: `nginx`, `wp-php`, `mariadb`, `redis`, `adminer`, and `prometheus`.

To verify WordPress is accessible, open `https://samatsum.42.fr` in the browser — you should see the WordPress front page.

To verify the database is accessible, open `https://samatsum.42.fr/adminer` and log in with the database credentials described above.

To verify Redis is connected, log in to the WordPress admin panel, navigate to the "Object Cache" section in the sidebar, and confirm the status shows as connected.

To check container logs for errors:

    sudo make logs
