*This project has been created as part of the 42 curriculum by samatsum.*

# Inception

## Description

Inception is a system administration project that uses Docker to build a small infrastructure composed of multiple services. The goal is to deepen understanding of containerization, networking, and service orchestration by setting up a complete WordPress website with its supporting services — all running inside Docker containers on a virtual machine.

The infrastructure consists of three core services (NGINX, WordPress + PHP-FPM, and MariaDB) connected through a Docker network, with persistent data stored via named volumes. NGINX serves as the sole entry point on port 443 with TLS encryption.

## Instructions

### Prerequisites

- A virtual machine running Ubuntu (tested on Ubuntu 22.04)
- Docker and Docker Compose installed on the VM
- `make` installed
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

3. Create the environment file at `srcs/.env` with the required variables (see DEV_DOC.md for details).

4. Add the domain to your hosts file:

       echo "127.0.0.1 samatsum.42.fr" | sudo tee -a /etc/hosts

5. Build and start:

       sudo make up

6. Access the site at `https://samatsum.42.fr` (accept the self-signed certificate warning).

### Available Commands

- `make up` — Build and start all services
- `make down` — Stop all services
- `make stop` — Stop containers without removing them
- `make start` — Start stopped containers
- `make logs` — View logs from all services
- `make status` — Show running containers
- `make clean` — Stop and remove containers, volumes, and images
- `make fclean` — Full clean including system prune
- `make re` — Full clean and rebuild

## Project Description

### Architecture

The project uses Docker Compose to orchestrate the following services, each running in its own dedicated container built from Debian Bookworm:

**Core Services:**

- **NGINX** — Reverse proxy and the only entry point to the infrastructure. Listens on port 443 with TLS (v1.2/v1.3 only). Forwards PHP requests to WordPress via FastCGI.
- **WordPress + PHP-FPM** — Content management system with PHP-FPM processing. Configured with two users (one administrator, one author). Includes Redis cache integration.
- **MariaDB** — Relational database storing all WordPress data. Initialized automatically on first run with the configured database, user, and privileges.

**Bonus Services:**

- **Redis** — In-memory cache for WordPress to reduce database load and improve response times.
- **Adminer** — Lightweight web-based database management tool accessible at `/adminer`.
- **Prometheus** — Metrics collection and monitoring system.

### Virtual Machines vs Docker

A virtual machine emulates an entire operating system including its own kernel, running on a hypervisor. Each VM consumes significant resources (RAM, CPU, disk) because it runs a full OS. Docker containers, on the other hand, share the host kernel and only package the application and its dependencies. This makes containers far more lightweight, faster to start (seconds vs minutes), and more efficient in resource usage. However, VMs provide stronger isolation since each has its own kernel, while containers share the host kernel and rely on Linux namespaces and cgroups for isolation.

### Secrets vs Environment Variables

Environment variables are stored in `.env` files and are accessible to all processes within a container. They are convenient but less secure — they can be exposed through process listings, logs, or debug endpoints. Docker secrets are stored encrypted, mounted as files inside containers at `/run/secrets/`, and are only accessible to the specific containers that need them. In this project, sensitive data like database passwords and WordPress credentials are stored as Docker secrets, while non-sensitive configuration (domain name, database name, usernames) is stored in environment variables.

### Docker Network vs Host Network

Host networking (`network: host`) removes network isolation between the container and the host — the container shares the host's network stack directly. This means containers can conflict with host ports and with each other. Docker bridge networks (used in this project) create an isolated virtual network where containers communicate using container names as hostnames. This provides better security, avoids port conflicts, and follows the principle of least privilege. The project uses a single bridge network (`inception-network`) connecting all services, with only NGINX exposing port 443 to the host.

### Docker Volumes vs Bind Mounts

Bind mounts map a specific host directory into a container, creating a direct dependency on the host's filesystem structure. Docker named volumes are managed by Docker itself, providing better portability and lifecycle management. Named volumes can be easily backed up, migrated, and managed with Docker commands. This project uses named volumes for MariaDB data and WordPress files, with the volume data stored at `/home/samatsum/data/` on the host via the `local` driver with bind options.

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [WordPress CLI Handbook](https://make.wordpress.org/cli/handbook/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/)
- [Redis Documentation](https://redis.io/docs/)
- [Adminer Documentation](https://www.adminer.org/)
- [Prometheus Documentation](https://prometheus.io/docs/)

