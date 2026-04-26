*This project has been created as part of the 42 curriculum by samatsum.*

# Inception

## Description
Inception is a system administration project that virtualizes a multi-service infrastructure using Docker Compose. The architecture follows a strict microservices approach, ensuring isolation, security (TLS v1.2/v1.3), and high availability through self-healing configurations.

## High-Level Setup
To deploy the infrastructure, follow these steps (refer to `DEV_DOC.md` for detailed environment preparation):
1. Prepare the `secrets/` directory and `.env` file.
2. Map `samatsum.42.fr` to `127.0.0.1` in your hosts file.
3. Execute `make up` from the root directory.
For service interaction and management commands, please see `USER_DOC.md`.

## Design Choices & Comparisons

### 1. Virtual Machines vs Docker
Virtual Machines (VMs) virtualize the hardware layer, requiring a complete Guest OS per instance. This results in significant overhead in both space complexity (GBs per OS) and time complexity (minutes to boot). 
Docker virtualizes at the OS kernel level using namespaces and cgroups. By sharing the host kernel, containers minimize resource consumption and achieve near-instantaneous startup (O(1) process spawning), while maintaining sufficient isolation for cooperative microservices.

### 2. Secrets vs Environment Variables
Standard environment variables are visible via `docker inspect` and can persist in shell history or logs. 
We utilize Docker Secrets, which are mounted into a memory-resident filesystem (tmpfs) at `/run/secrets/`. This ensures sensitive data (passwords) never touches the container's disk and is inaccessible to child processes or external inspection, significantly hardening the infrastructure's security layer.

### 3. Docker Network vs Host Network
Using the host network removes all isolation between the container and the host OS, increasing the attack surface. 
We implement a dedicated Docker Bridge Network. This ensures L3 isolation where containers only communicate via internal DNS (service names). Exposure is strictly limited to NGINX on port 443, adhering to the Principle of Least Privilege.

### 4. Docker Volumes vs Bind Mounts
Bind mounts depend on specific host paths, leading to fragile portability. 
We use Named Volumes with the `local` driver and `o: bind` options. This allows Docker to manage the storage lifecycle (metadata and status) while strictly adhering to the requirement of persisting data in `/home/samatsum/data`. This design bridges the gap between Docker-managed abstraction and host-level persistence.

## Resources
- [Official Docker Documentation](https://docs.docker.com/)
- [Debian/Alpine Package Repositories]
- **AI Usage:** AI (Claude) was utilized as a technical mentor to audit infrastructure architecture, debug L7 protocol mismatches (Prometheus/NGINX), and optimize PID 1 signal propagation (exec patterns). All logic was manually verified and tested.