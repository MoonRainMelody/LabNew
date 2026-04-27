# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **实验一 (Experiment 1): 负载均衡与应用集群** (Load Balancing and Application Clusters) - a lab project demonstrating a containerized multi-tier application with load balancing.

### Architecture

The system consists of four layers orchestrated via Docker Compose:
- **Database Layer**: MySQL 8.0 with `mall_db` containing a `product` table (id, name, price)
- **Application Layer**: Two identical Spring Boot instances serving a REST API at `/api/products`
- **Load Balancer**: Nginx distributing requests across the two app instances using round-robin with configurable weights
- **Response Format**: API responses must include `server_port` or `instance_id` to demonstrate which instance handled the request

### Key Implementation Details

- Each API response from `/api/products` includes `server_port` to identify which backend instance processed the request (critical for demonstrating load balancing)
- Nginx uses weighted round-robin (app1 weight=2, app2 weight=1) with health checks (`max_fails=2 fail_timeout=10s`)
- Services communicate using Docker network names (e.g., `mysql`, `app1`, `app2`)

## Build and Run Commands

### Local Development
```bash
# Build the project
./mvnw clean package

# Run Spring Boot application directly
./mvnw spring-boot:run

# Run tests
./mvnw test
```

### Docker Environment
```bash
# Build and start all services (MySQL, 2x app instances, Nginx)
docker-compose up --build

# Start in detached mode
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Testing the Load Balancer
```bash
# Test the load balancer - watch server_port values change
curl http://localhost/api/products

# Repeated requests to observe distribution
for i in {1..10}; do curl http://localhost/api/products; echo ""; done
```

## Project Structure

- `mysql/init.sql` - Database initialization script (auto-run on MySQL container start)
- `nginx/nginx.conf` - Nginx configuration with upstream backend_servers
- `Dockerfile` - Spring Boot application containerization (multi-stage build)
- `docker-compose.yml` - Orchestrates 4 services: mysql, app1, app2, nginx
- Spring Boot source in `src/main/java/org/example/lab1/`
