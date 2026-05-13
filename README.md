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

### Request Flow (Mandatory)

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
| **Redis** | Bonus | In-memory Object Cache | Vastly improves L7 response times by caching queries. |
| **Adminer** | Bonus | DB Management GUI | Provides a visual interface to manage MariaDB state via the browser. |
| **FTP** | Bonus | File Transfer Protocol | Allows developers to directly manipulate the shared WordPress volume. |
| **Static Site** | Bonus | Python (Flask) Site | A standalone static portfolio site operating independently of the PHP stack. |
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

## Architectural Comparisons (Design Choices)

### 1. Virtual Machine vs Docker

| Aspect | Virtual Machine | Docker Container |
| --- | --- | --- |
| Virtualization Layer | **Hardware level** (Hypervisor) | **OS level** (Container Runtime) |
| OS | Full OS kernel per VM | Shares host OS kernel |
| Boot Time | Tens of seconds to minutes | Milliseconds to seconds |
| Resource Efficiency | Low (Emulates entire OS) | High (Process isolation only) |
| Isolation Level | Strong (Full virtualization) | Medium (Namespaces + cgroups) |

**Decision in this project**: Docker containers run inside a VM. Since the project requirements specify the use of a VM, the infrastructure follows a 3-layer architecture: Host OS → VM → Docker.

> Reference Video: [YouTube — VM vs Docker Explanation](https://www.youtube.com/watch?v=-NTdH4Y2veI) 

### 2. Docker Secrets vs Environment Variables

| Aspect | Docker Secrets | Environment Variables |
| --- | --- | --- |
| Purpose | Sensitive data (Passwords, API keys, etc.) | Non-sensitive configs (URLs, Usernames, etc.) |
| Storage Location | `/run/secrets/` (tmpfs, in-memory) | Process environment |
| Visibility | Hidden from `docker inspect` | Visible in `docker inspect` |
| Git Management | Must be excluded via `.gitignore` | Can be managed via `.env` |

**Conclusion**: Environment variables are convenient for passing configuration values (like domain names or ports) but are completely unsuitable for storing sensitive information. By using Docker Secrets, data is held solely in memory (tmpfs), ensuring extremely high robustness and memory safety.

### 3. Docker Network vs Host Network

| Aspect | Docker Network (Bridge) | Host Network |
| --- | --- | --- |
| Isolation | Isolated network across containers | Directly uses host's network namespace |
| DNS | Internal Docker DNS (resolves by container name) | Host's `/etc/resolv.conf` |
| Ports | Explicit mapping (`-p 443:443`) | Container directly occupies host ports |
| Security | High (No direct external access unless mapped) | Low (Equivalent to the host machine) |

**Conclusion**: The Host Network breaks network isolation (Network Namespaces), creating a major security vulnerability. By using a Docker Network (Bridge), safe communication between containers at the L3 layer (internal DNS) and strict access control at the L4 layer (opening only necessary ports to the outside) become possible.

### 4. Docker Volumes vs Bind Mounts

| Aspect | Named Volumes | Bind Mounts |
| --- | --- | --- |
| Management | Managed by Docker (`docker volume ls`) | Direct host file system |
| Path Specification | Logical name (`mariadb_data`) | Absolute path (`/home/user/data`) |
| Portability | High (Movable between Docker environments) | Low (Dependent on host path) |
| Initialization | Empty or copied from image | Host files take precedence |

> Reference Article: [Qiita — P-man_Brown: Named Volumes + driver_opts](https://qiita.com/P-man_Brown/items/6d6e870acc1720f04486) (→ [Cross-reference](https://www.google.com/search?q=%23auxiliary-references))

* `mariadb_data` → `/home/samatsum/data/mariadb`
* `wordpress_data` → `/home/samatsum/data/wordpress`

This project utilizes a hybrid approach: taking advantage of Docker's volume management capabilities while persistently binding them to specific host directories to ensure data survives VM reboots.

**Conclusion**: Bind Mounts are useful in development environments for syncing local code into a container, but they heavily depend on the host environment. By using Docker Volumes (with `driver_opts`), data management is entrusted to Docker, improving system robustness and portability.

Verification commands:

```bash
docker volume ls
docker volume inspect <volume_name>
docker compose config --volumes

```

---

## Resources

### Docker

* [Compose file reference](https://docs.docker.com/reference/compose-file/)
* [Use secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
* [Volumes in Compose](https://docs.docker.com/reference/compose-file/volumes/)
* [Network in Compose](https://docs.docker.com/compose/how-tos/networking/)
* [Docker Compose CLI Reference](https://docs.docker.com/reference/cli/docker/compose/)

### Alpine Linux

* [Alpine Linux Releases](https://alpinelinux.org/releases/)
* [Alpine Wiki - MariaDB](https://wiki.alpinelinux.org/wiki/MariaDB)
* [Alpine Wiki - Nginx](https://wiki.alpinelinux.org/wiki/Nginx)

### NGINX

* [nginx.org Documentation](https://nginx.org/en/docs/)
* [nginx.org Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
* [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
* [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)

### MariaDB

* [mariadb-install-db](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)
* [MariaDB Server Documentation](https://mariadb.com/kb/en/documentation/)
* [mariadb-install-db — User accounts created by default](https://mariadb.com/kb/en/mariadb-install-db/#user-accounts-created-by-default)

### WordPress / PHP

* [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
* [wp core install](https://developer.wordpress.org/cli/commands/core/install/)
* [wp user create](https://developer.wordpress.org/cli/commands/user/create/)
* [wp post list](https://developer.wordpress.org/cli/commands/post/list/)

### TLS / Security

* [RFC 8446 (TLS 1.3)](https://datatracker.ietf.org/doc/html/rfc8446)
* [OpenSSL Documentation](https://www.openssl.org/docs/)

### Makefile

* [GNU Make Manual](https://www.gnu.org/software/make/manual/make.html)

### Environment (VM)

* [VirtualBox User Manual](https://www.virtualbox.org/manual/UserManual.html)

### moby/moby Issues (Restart Policy)

* [#11065 — Non-fatal signals break restart policies](https://github.com/moby/moby/issues/11065)
* [#26464 — Taking stop-signal into account when docker kill](https://github.com/moby/moby/pull/26464)
* [#41302 — Signal breaks unless-stopped restart policy](https://github.com/moby/moby/issues/41302)
* [#47792 — docker kill prevents unless-stopped from starting after reboot](https://github.com/moby/moby/issues/47792)

### Books

* [Docker (Japanese Edition)](https://www.oreilly.com/library/view/docker/9784873117768/) — O'Reilly Japan, August 2016, 384 pages (Referenced in print)

### Auxiliary References

Resources not explicitly specified in the project subject but used to aid in the understanding of primary source materials.

* [Qiita — P-man_Brown: Named Volumes + driver_opts Hybrid Method](https://qiita.com/P-man_Brown/items/6d6e870acc1720f04486) (→ Ref. §4 Volumes)
* [Qiita — etaroid: Docker secrets Supplement 1](https://qiita.com/etaroid/items/b1024c7d200a75b992fc)
* [Qiita — etaroid: Docker secrets Supplement 2](https://qiita.com/etaroid/items/88ec3a0e2d80d7cdf87a)
* [Qiita — etaroid: Docker secrets Supplement 3](https://qiita.com/etaroid/items/40106f13d47bfcbc2572)
* [YouTube — VM vs Docker Explanation](https://www.youtube.com/watch?v=-NTdH4Y2veI) (→ Ref. §1 VM vs Docker)

---

## AI Usage Statement

In this project, AI (Claude/Gemini) was utilized as a **Pair Programming Navigator**.

### Usage Policy (AI-Navigated Pair Programming with Scaffolding)

* **What the AI did**: Provided conceptual explanations, articulated the rationale behind design choices, suggested verification commands, provided code skeletons, and offered review/feedback.
* **What the AI did NOT do**: Direct generation of finalized code or direct editing of the project files.
"""
