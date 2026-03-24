*This project has been created as part of the 42 curriculum by samatsum.*

# Inception

## Description

Inception is a system administration project that uses Docker to build a small infrastructure composed of multiple services. The goal is to deepen understanding of containerization, networking, and service orchestration by setting up a complete WordPress website with its supporting services — all running inside Docker containers on a virtual machine.

The infrastructure consists of three core services (NGINX, WordPress + PHP-FPM, and MariaDB) connected through a Docker network, with persistent data stored via named volumes. NGINX serves as the sole entry point on port 443 with TLS encryption. Six bonus services extend the stack with caching, monitoring, database management, a static site, an FTP server, and a visualization dashboard.

## Instructions

### Prerequisites

- A virtual machine running Ubuntu (tested on Ubuntu 22.04 LTS)
- Docker (version 20.10 or later) and Docker Compose v2 installed
- `make` and `git` installed
- Domain `samatsum.42.fr` pointing to `127.0.0.1` in `/etc/hosts`

### Setup

1. Clone the repository:

       git clone <repository-url>
       cd samatsum-Inception-42Tokyo

2. Create the secrets directory and files (these are not tracked by Git):

       mkdir -p secrets
       echo "your_db_password" > secrets/db_password.txt
       echo "your_db_root_password" > secrets/db_root_password.txt
       echo "your_wp_admin_password" > secrets/credentials.txt
       echo "your_wp_normal_password" > secrets/wp_normal_password.txt
       echo "your_ftp_password" > secrets/ftp_password.txt

3. Create the environment file at `srcs/.env`:

       DOMAIN_NAME=samatsum.42.fr
       MYSQL_DATABASE=wordpress
       MYSQL_USER=wpuser
       WP_TITLE=inception
       WP_ADMIN_USER=supervisor
       WP_ADMIN_EMAIL=admin@example.com
       WP_NORMAL_USER=viewer
       WP_NORMAL_EMAIL=viewer@example.com

4. Add the domain to your hosts file:

       echo "127.0.0.1 samatsum.42.fr" | sudo tee -a /etc/hosts

5. Build and start all services:

       sudo make up

6. Access the site at `https://samatsum.42.fr` (accept the self-signed certificate warning).

### Available Commands

| Command | Description |
|---|---|
| `make up` | Build and start all services |
| `make down` | Stop and remove containers |
| `make stop` | Stop containers without removing them |
| `make start` | Start stopped containers |
| `make logs` | View real-time logs from all services |
| `make status` | Show running containers |
| `make clean` | Remove containers, volumes, and images |
| `make fclean` | Full clean including system prune and host data |
| `make re` | Full clean and rebuild from scratch |

## Project Description

### How Docker Is Used

Every service runs in its own dedicated container, built from a custom Dockerfile based on `debian:bookworm`. No pre-built images are pulled from DockerHub — each image is built locally by Docker Compose via the Makefile. The `docker-compose.yml` file defines all services, their dependencies, networks, volumes, and secrets. The Makefile at the project root serves as the single entry point: `make up` creates the necessary host directories and then invokes `docker compose up --build`.

### Source Structure

The project follows the directory layout specified by the subject. All configuration lives under `srcs/`. Each service has its own directory containing a Dockerfile, a configuration file, and an entrypoint script. Secrets are stored outside the repository in `secrets/` and excluded via `.gitignore`. Environment variables are stored in `srcs/.env`, also excluded from Git.

    .
    ├── Makefile
    ├── README.md / USER_DOC.md / DEV_DOC.md
    ├── secrets/                        # Git-ignored
    └── srcs/
        ├── .env                        # Git-ignored
        ├── docker-compose.yml
        └── requirements/
            ├── nginx/                  # NGINX + TLS
            ├── wordpress/              # WordPress + PHP-FPM
            ├── mariadb/                # MariaDB
            └── bonus/
                ├── redis/              # Redis cache
                ├── adminer/            # Database management UI
                ├── prometheus/         # Metrics collection
                ├── grafana/            # Monitoring dashboard
                ├── static-site/        # Python/Flask static site
                └── ftp/                # vsftpd FTP server

### Key Design Choices

**Entrypoint scripts and PID 1.** Each container uses an entrypoint shell script that ends with `exec <daemon>`, replacing the shell process with the actual service. This ensures the daemon runs as PID 1 and receives signals correctly, avoiding the need for hacks like `tail -f` or `sleep infinity`.

**Initialization idempotency.** Both MariaDB and WordPress check whether initialization has already been performed before running setup steps. MariaDB checks for the existence of `/var/lib/mysql/mysql`; WordPress checks for `wp-config.php`. This allows containers to restart without re-initializing data.

**Race condition handling.** WordPress's `wp config create` uses the `--skip-check` flag so it does not attempt to connect to MariaDB before the database is ready. The actual database readiness check happens later in a retry loop using `wp db check`.

**Secret management.** Passwords are stored as Docker secrets (files mounted at `/run/secrets/` inside containers). The entrypoint scripts read these files at runtime. This avoids embedding credentials in Dockerfiles, environment variables visible via `docker inspect`, or Git history.

### Virtual Machines vs Docker

A virtual machine runs a complete guest operating system on top of a hypervisor. Each VM has its own kernel, its own init system, and its own memory space. This provides strong isolation — a crash or compromise in one VM does not affect others — but comes at a significant cost: each VM consumes gigabytes of RAM and disk just to run the OS, and boot times are measured in minutes.

Docker containers share the host's Linux kernel. Instead of virtualizing hardware, Docker uses kernel features — namespaces for process and network isolation, cgroups for resource limits, and union filesystems for layered images. A container packages only the application and its dependencies, making it megabytes rather than gigabytes. Startup is nearly instantaneous because there is no kernel to boot.

The trade-off is isolation. A kernel vulnerability on the host can potentially affect all containers, whereas VMs are protected by the hypervisor boundary. In this project, Docker is the right choice because the services are cooperative (they form a single application stack) and the lightweight nature of containers makes it practical to run many services on a single VM.

### Secrets vs Environment Variables

Environment variables defined in `.env` and loaded via `env_file` in Docker Compose are convenient for non-sensitive configuration such as domain names, database names, and usernames. However, they have security weaknesses: they are visible in `docker inspect`, they can leak into child processes, logs, and error reports, and they persist in the container's process environment.

Docker secrets are stored encrypted on disk and mounted as files inside containers at `/run/secrets/<name>`. They are only available to containers that explicitly declare them in `docker-compose.yml`. They do not appear in `docker inspect`, they are not inherited by child processes, and they are stored in a tmpfs mount that is never written to disk inside the container.

In this project, non-sensitive values (domain name, database name, usernames) use environment variables, while all passwords (database root password, database user password, WordPress admin password, WordPress normal user password, FTP password) use Docker secrets.

### Docker Network vs Host Network

With `network: host`, a container shares the host's network stack directly. The container's ports are the host's ports — there is no isolation. If two containers try to bind to the same port, one fails. Any service inside the container is directly reachable from outside the host, which violates the principle of least privilege.

A Docker bridge network creates an isolated virtual network. Containers on the same bridge can communicate using container names as DNS hostnames (Docker's embedded DNS resolves them). Containers on different bridges cannot communicate unless explicitly connected. Port exposure to the host is controlled with `ports:` in the Compose file.

This project uses a single bridge network (`inception-network`). All containers are attached to it and can reach each other by name (e.g., `wp-php:9000`, `mariadb:3306`, `redis:6379`). Only NGINX publishes port 443 to the host. No other service is directly accessible from outside, enforcing the subject's requirement that NGINX is the sole entry point.

### Docker Volumes vs Bind Mounts

A bind mount maps a specific host path into a container using `-v /host/path:/container/path`. The container directly reads and writes to that host directory. This creates a tight coupling to the host's filesystem layout, and Docker has no control over the lifecycle of the data.

A Docker named volume is a storage object managed by Docker. It appears in `docker volume ls`, can be inspected with `docker volume inspect`, and its lifecycle is tied to Docker commands (`docker volume rm`, `docker compose down -v`). Named volumes are more portable and easier to back up.

In this project, named volumes (`mariadb`, `wordpress`, `prometheus`) are defined in `docker-compose.yml` with the `local` driver and bind options pointing to `/home/samatsum/data/`. This satisfies both requirements: the volumes are Docker-managed named volumes (visible via `docker volume ls`), and the data is stored at the subject-required host path. The `local` driver with `type: none` and `o: bind` is the standard Docker method for mapping named volumes to specific host directories.

## Resources

### Documentation

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [WordPress CLI Handbook](https://make.wordpress.org/cli/handbook/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/)
- [Redis Documentation](https://redis.io/docs/)
- [Adminer Documentation](https://www.adminer.org/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [vsftpd Manual](https://security.appspot.com/vsftpd.html)

### AI Usage

AI (Claude by Anthropic) was used in the following areas of this project:

- **Configuration review and debugging**: AI helped identify configuration errors such as incorrect PHP version paths in Dockerfiles (7.4 vs 8.2), nginx symlink issues, and race conditions in WordPress initialization.
- **Documentation writing**: The README, USER_DOC, and DEV_DOC were drafted and refined with AI assistance for structure, clarity, and completeness against the subject requirements.
- **Best practices guidance**: AI provided guidance on Docker entrypoint patterns (PID 1, `exec`), secret management, and TLS configuration.
- **Troubleshooting**: AI assisted in diagnosing issues such as Grafana 12.x's broken variable expansion in `grafana.ini` and the WordPress `wp config create` race condition.

All code was written, tested, and validated by the student. AI was used as a reference and review tool, not as a code generator.
