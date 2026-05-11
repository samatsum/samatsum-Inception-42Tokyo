*This project has been created as part of the 42 curriculum by samatsum.*

## Description

Inception is a system administration project that virtualizes a multi-service infrastructure using Docker Compose. The architecture follows a strict microservices approach, ensuring isolation, security (TLS v1.2/v1.3), and high availability.

### Architecture

```text
                                    [ Internet ]
                                          │
                            HTTPS (Port 443) / FTP (Port 21)
                                          │
┌─────────────────────────────────────────▼─────────────────────────────────────────┐
│                                     VM (Host)                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │                               Docker Compose                                │  │
│  │                                                                             │  │
│  │   ┌──────────────────────────────────────────────────────────────────┐      │  │
│  │   │                    NGINX (TLS 1.2/1.3 Gateway)                   │      │  │
│  │   └─┬──────────────┬───────────────┬───────────────┬───────────────┬─┘      │  │
│  │     │              │               │               │               │        │  │
│  │     │       ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ │  │
│  │     │       │ Static Site │ │ Prometheus  │ │   Grafana   │ │   Adminer   │ │  │
│  │     │       │   (Flask)   │ │  (Metrics)  │ │ (Dashboard) │ │  (DB GUI)   │ │  │
│  │     │       └─────────────┘ └──────┬──────┘ └──────▲──────┘ └──────┬──────┘ │  │
│  │     │                              │               │               │        │  │
│  │     │                              └───────┬───────┘        ┌──────▼──────┐ │  │
│  │     │              [L7 Routing]            │                │   MariaDB   │ │  │
│  │     └─────────────┬────────────────────────┤                │  (Database) │ │  │
│  │                   │                        │                └──────▲──────┘ │  │
│  │           ┌───────▼───────┐        [Data Scraping]                 │        │  │
│  │           │   WordPress   │◀───────────────────────────────────────┘        │  │
│  │           │   (PHP-FPM)   │─────────[ SQL Query ]──────────────────┐        │  │
│  │           └───────┬───────┘                                        │        │  │
│  │                   │                                                │        │  │
│  │           [Object Caching]                                         │        │  │
│  │                   │                                                │        │  │
│  │           ┌───────▼───────┐        ┌───────────────────────┐       │        │  │
│  │           │  Redis Cache  │        │   Shared WP Volume    │◀──────┘        │  │
│  │           │ (In-memory)   │        │   (wordpress_data)    │                │  │
│  │           └───────────────┘        └───────▲───────────────┘                │  │
│  │                                            │                                │  |
│  │   ┌───────────────┐                        │                                │  |
│  │   │  FTP Server   │────────[ File Sync ]───┘                                │  |
│  │   │   (vsftpd)    │                                                         │  |
│  │   └───────────────┘                                                         │  |
│  │                                                                             │``|
│  │  ══════════════════════════════════╧══════════════════════════════════════  │  │
│  │                         inception-network (bridge)                          │  │
│  │                                                                             │  │
│  └────────────────────────────────────┬────────────────────────────────────────┘  │
│                                       │                                           │
│                              Bind Mounts (Persistence)                            │
│                                       ▼                                           │
│                 /home/samatsum/data/{wordpress, mariadb, prometheus}              │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Request Flow(MAndatory)
```text
Browser --[HTTPS]--> NGINX --[FastCGI]--> PHP-FPM --[SQL]--> MariaDB
                (443)               (9000)              (3306)
```

## Service Overview (9 Containers)

| Container | Category | Role | Key Principle & Architecture |
| --- | --- | --- | --- |
| **NGINX** | Mandatory | TLS Gateway & Reverse Proxy | The sole entry point from the outside. Handles TLS termination to reduce backend load. |
| **WordPress** | Mandatory | CMS (Application Layer) | Executes dynamic PHP scripts via PHP-FPM. |
| **MariaDB** | Mandatory | RDBMS (Persistence Layer) | Manages persistent data securely using Docker Secrets for authentication. |
| **Redis** | Bonus | In-memory Object Cache | Bypasses heavy DB queries with **O(1)** time complexity lookups, vastly improving L7 response times. |
| **Adminer** | Bonus | Database Management GUI | Provides a visual interface to manage MariaDB state via the browser. |
| **FTP** | Bonus | File Transfer Protocol | Allows developers to directly manipulate the shared WordPress volume. |
| **Static Site** | Bonus | Python (Flask) Website | A standalone static portfolio site operating independently of the PHP stack. |
| **Prometheus** | Bonus | Time-series Metrics Server | Actively scrapes infrastructure metrics (CPU, Memory, Requests) across services. |
| **Grafana** | Bonus | Visualization Dashboard | Translates raw Prometheus data into interactive, human-readable monitoring dashboards. |

## Instructions

### Quick Start

1. Map the domain locally by adding `127.0.0.1 samatsum.42.fr` to your `/etc/hosts`.
2. Ensure the `.env` file and `secrets/` directory are properly set up (refer to `DEV_DOC.md` for generation scripts).
3. Build and launch the infrastructure:
```bash
make up

```



*For day-to-day operations and service access URLs, please refer to `USER_DOC.md`. For a deep dive into technical specifications and Makefile targets, see `DEV_DOC.md`.*

## Resources

### 1. Design Choices (Deep Dive)

* **PID 1 & Signal Handling**: To prevent zombie processes and ensure `SIGTERM` signals are caught gracefully, entrypoint scripts use `exec` for process replacement. Bonus containers utilize `tini` as a lightweight init system to forward signals properly.
* **Volume Strategy**: By using `bind mounts` mapped to `/home/samatsum/data/`, the architecture guarantees data persistence even when containers are destroyed (`make down`), while also keeping files accessible for host-side FTP operations.
* **Robustness (Fail-Fast)**: All shell scripts begin with `set -uo pipefail`. This ensures that references to undefined variables or failures within command pipelines immediately crash the script, preventing the system from running in an unstable state.

### 2. AI Usage

During the development of this project, AI was utilized as a technical pair-programming mentor to guide architectural decisions and verify logic. Specifically:

* **Architecture Auditing**: Identifying and resolving L7 routing conflicts (Trailing slash issues) between NGINX and the Prometheus sub-path.
* **Debugging**: Resolving filesystem permission collisions (`www-data` vs `root`) during the Redis object cache drop-in installation.
* **Optimization**: Implementing a robust polling mechanism (L4 connection standby) in the `wp-cli` auto-installation script to prevent race conditions during cold starts between MariaDB and WordPress.

*Note: All generated logic, concepts, and configurations were manually tested, verified, and deeply understood by the developer prior to implementation.*

```