*This project has been created as part of the 42 curriculum by samatsum.*

# Inception

## Description
Inception is a system administration project that virtualizes a multi-service infrastructure using Docker Compose. The architecture follows a strict microservices approach, ensuring isolation, security (TLS v1.2/v1.3), and high availability.

## Instructions
To deploy the infrastructure, follow these steps:
1. **Prepare Environment**: Create the `secrets/` directory and `.env` file as described in `DEV_DOC.md`.
2. **Setup Domain**: Map your `DOMAIN_NAME` (defined in `.env`) to `127.0.0.1` in your `/etc/hosts` file.
3. **Execution**: Execute `sudo make up` from the root directory to build and launch all services.

## Design Choices & Comparisons

### 1. Virtual Machines vs Docker
Virtual Machines (VMs) virtualize the hardware layer, requiring a complete Guest OS per instance. Docker virtualizes at the OS kernel level using namespaces and cgroups, minimizing resource consumption and achieving near-instantaneous startup.

### 2. Secrets vs Environment Variables
Standard environment variables are visible via `docker inspect`. We use Docker Secrets, mounted into a memory-resident filesystem (tmpfs) at `/run/secrets/`, ensuring sensitive data (passwords) never touches the container's disk.

### 3. Docker Network vs Host Network
Using the host network removes isolation between the container and the host OS. We implement a dedicated Docker Bridge Network to ensure L3 isolation where containers only communicate via internal DNS.

### 4. Docker Volumes vs Bind Mounts
Bind mounts depend on specific host paths, leading to fragile portability. We use Named Volumes with the `local` driver and `o: bind` options to persist data in the path defined in your configuration while maintaining Docker-managed abstraction.

## Resources
- [Official Docker Documentation](https://docs.docker.com/)
- **AI Usage:** AI was utilized as a technical mentor to audit infrastructure architecture and optimize process management. All logic was manually verified and tested.
## Resources
- [Official Docker Documentation](https://docs.docker.com/)
- [cite_start]**AI Usage:** AI (Gemini) was utilized as a technical mentor to audit infrastructure architecture, debug L7 protocol mismatches (Prometheus/NGINX), and optimize PID 1 signal propagation (exec patterns)[cite: 255]. All logic was manually verified.