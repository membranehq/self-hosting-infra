# Service Deployment

This guide covers deploying and configuring all Membrane services. For platform-specific deployment instructions, see:
- [Kubernetes Deployment](kubernetes.md)
- [Container Services Deployment](container-services.md) (ECS, Azure Container Apps, etc.)
- [Helm Deployment](helm.md)

## Services Overview

Membrane consists of four Docker images that run in different modes:

| Service | Image | Purpose | Scaling |
|---------|-------|---------|---------|
| API | `core/api` (API mode) | HTTP API endpoints | Horizontal |
| Instant Tasks Worker | `core/api` (Worker mode) | Semi-instant async tasks | Horizontal |
| Queued Tasks Worker | `core/api` (Worker mode) | Long-running tasks | Horizontal |
| Orchestrator | `core/api` (Orchestrator mode) | Schedules, syncs, cleanup | Horizontal |
| UI | `core/ui` | Pre-built integration UI | Horizontal |
| Console | `core/console` | Admin interface | Horizontal |
| Custom Code Runner | `core/custom-code-runner` | Isolated code execution | Horizontal |

## 1. API Service

Main backend service handling HTTP requests and business logic.

### Docker Image
```
harbor.integration.app/core/api:<version>
```

### Mode Configuration
```bash
IS_API=1
```

### Environment Variables

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode | `production` |
| `BASE_URI` | API service deployment URL | `https://api.yourdomain.com` |
| `CUSTOM_CODE_RUNNER_URI` | Custom Code Runner service URL | `https://custom-code-runner.yourdomain.com` |
| `PORT` | Container listening port | `5000` |
| `SECRET` | JWT token signing secret | `<random-32-char-string>` |
| `ENCRYPTION_SECRET` | Credentials encryption secret | `<random-32-char-string>` |
| `MONGO_URI` | MongoDB connection string | `mongodb+srv://user:pass@cluster.mongodb.net/db` |
| `REDIS_URI` | Redis connection string (single instance) | `redis://user:password@redis:6379` |
| `TMP_STORAGE_BUCKET` | Temporary storage bucket name | `integration-app-tmp` |
| `CONNECTORS_STORAGE_BUCKET` | Connectors storage bucket name | `integration-app-connectors` |
| `STATIC_STORAGE_BUCKET` | Static files storage bucket name | `integration-app-static` |
| `BASE_STATIC_URI` | Static content base URL | `https://static.yourdomain.com` |
| `STORAGE_PROVIDER` | Storage provider type | `s3`, `abs`, or `gcs` |

#### Authentication Variables

**For Auth0:**
```bash
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
```

**For Username/Password:**
```bash
# Omit Auth0 variables
# Configure SMTP for email:
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=noreply@yourdomain.com
SMTP_PASSWORD=smtp_password
EMAIL_FROM=noreply@yourdomain.com
```

#### Cloud Storage Variables

**AWS S3:**
```bash
STORAGE_PROVIDER=s3
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=<key>  # Omit if using IAM roles
AWS_SECRET_ACCESS_KEY=<secret>  # Omit if using IAM roles
```

**Azure Blob Storage:**
```bash
STORAGE_PROVIDER=abs
AZURE_STORAGE_CONNECTION_STRING=<connection-string>
# OR
AZURE_STORAGE_ACCOUNT_NAME=<account-name>
AZURE_STORAGE_ACCOUNT_KEY=<account-key>
```

**Google Cloud Storage:**
```bash
STORAGE_PROVIDER=gcs
GOOGLE_CLOUD_PROJECT_ID=<project-id>
GOOGLE_CLOUD_KEYFILE=/path/to/keyfile.json  # Omit if using Workload Identity
```

#### Redis Cluster Variables

For Redis clusters, use multiple URIs instead of `REDIS_URI`:
```bash
REDIS_CLUSTER_URI_1=redis://user:pass@node1:6379
REDIS_CLUSTER_URI_2=redis://user:pass@node2:6379
REDIS_CLUSTER_URI_3=redis://user:pass@node3:6379
```

#### Optional Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `HEADERS_TIMEOUT_MS` | Max time to receive request headers | `61000` | `61000` |
| `KEEPALIVE_TIMEOUT_MS` | Max time to keep idle connections | `61000` | `61000` |
| `ENABLE_LIMITS` | Enable workspace resource limits | `false` | `true` |
| `MAX_NODE_RUN_OUTPUT_SIZE_MB` | Max size for node run outputs | `20` | `50` |
| `CONNECTION_CREDENTIALS_STORAGE_TYPE` | Credentials storage type | `database` | `external_api` |
| `CONNECTION_CREDENTIALS_EXTERNAL_API_ENDPOINT_URL` | External credentials API URL | - | `https://api.example.com` |

### Resource Requirements

**Minimum:**
- CPU: 500 millicores (0.5 CPU)
- Memory: 2GB

**Recommended for production:**
- CPU: 1-2 cores
- Memory: 4GB

### Health Check

```
GET http://api-service:5000/
```

Expected response: HTTP 200 OK

## 2. Instant Tasks Worker

Processes semi-instant asynchronous tasks. Scale to prevent task queuing.

### Docker Image
```
harbor.integration.app/core/api:<version>
```

### Mode Configuration
```bash
IS_INSTANT_TASKS_WORKER=1
```

### Environment Variables

Same as API service, but use `IS_INSTANT_TASKS_WORKER=1` instead of `IS_API=1`.

### Resource Requirements

**Minimum:**
- CPU: 500 millicores
- Memory: 2GB

**Scaling:**
- Each worker processes one background job at a time
- Scale based on job queue length
- See [Autoscaling](../autoscaling.md) for dynamic scaling configuration

### Health Check

```
GET http://instant-worker:5000/
```

## 3. Queued Tasks Worker

Handles long-running tasks (flow runs, event pulls, external events).

### Docker Image
```
harbor.integration.app/core/api:<version>
```

### Mode Configuration
```bash
IS_QUEUED_TASKS_WORKER=1
```

### Environment Variables

Same as API service, plus:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `IS_QUEUED_TASKS_WORKER` | Enable queued tasks worker mode | - | `1` |
| `MAX_QUEUED_TASKS_MEMORY_MB` | Memory limit for task execution | `1024` | `2048` |
| `MAX_QUEUED_TASKS_PROCESS_TIME_SECONDS` | Time limit for task execution | `3000` | `5000` |

### Resource Requirements

**Minimum:**
- CPU: 500 millicores
- Memory: 2GB (adjust based on `MAX_QUEUED_TASKS_MEMORY_MB`)

**Scaling:**
- Each worker processes one job at a time
- When limits enabled, tasks are queued for fair resource distribution
- See [Autoscaling](../autoscaling.md) for dynamic scaling

### Health Check

```
GET http://queued-worker:5000/prometheus/queued-tasks
```

## 4. Orchestrator

Manages schedule triggers, data source syncs, and cleanup tasks.

### Docker Image
```
harbor.integration.app/core/api:<version>
```

### Mode Configuration
```bash
IS_ORCHESTRATOR=1
```

### Environment Variables

Same as API service, but use `IS_ORCHESTRATOR=1` instead of `IS_API=1`.

### Resource Requirements

**Minimum:**
- CPU: 500 millicores
- Memory: 2GB

**Scaling:**
- Runs distributed leader election
- Can scale horizontally (only one instance active at a time)
- Recommended: 2 instances for high availability

### Health Check

```
GET http://orchestrator:5000/
```

## 5. UI Service

Pre-built integration user interfaces for end users.

### Docker Image
```
harbor.integration.app/core/ui:<version>
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_ENGINE_URI` | API service URL | `https://api.yourdomain.com` |
| `PORT` | Container listening port | `5000` |

### Resource Requirements

**Minimum:**
- CPU: 250 millicores
- Memory: 512MB

**Recommended:**
- CPU: 500 millicores
- Memory: 1GB

### Scaling

- Stateless service
- Scale horizontally with load balancer
- Recommended: Minimum 2 instances

### Health Check

```
GET http://ui-service:5000/
```

## 6. Console Service

Administration interface for managing integrations.

### Docker Image
```
harbor.integration.app/core/console:<version>
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_BASE_URI` | Console access URL | `https://console.yourdomain.com` |
| `NEXT_PUBLIC_AUTH0_DOMAIN` | Auth0 domain | `your-tenant.auth0.com` |
| `NEXT_PUBLIC_AUTH0_CLIENT_ID` | Auth0 client ID | `your_client_id` |
| `NEXT_PUBLIC_ENGINE_API_URI` | API service URL | `https://api.yourdomain.com` |
| `NEXT_PUBLIC_ENGINE_UI_URI` | UI service URL | `https://ui.yourdomain.com` |
| `NEXT_PUBLIC_ENABLE_LIMITS` | Enable limits management UI | `true` |
| `PORT` | Container listening port | `5000` |

> **Note:** For username/password authentication, omit `NEXT_PUBLIC_AUTH0_DOMAIN` and `NEXT_PUBLIC_AUTH0_CLIENT_ID`.

### Resource Requirements

**Minimum:**
- CPU: 250 millicores
- Memory: 512MB

**Recommended:**
- CPU: 500 millicores
- Memory: 1GB

### Scaling

- Stateless service
- Scale horizontally with load balancer
- Recommended: Minimum 2 instances

### Health Check

```
GET http://console-service:5000/
```

## 7. Custom Code Runner

Isolated environment for executing custom code in connectors or middleware.

### Docker Image
```
harbor.integration.app/core/custom-code-runner:<version>
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PORT` | Container listening port | `5000` |

### Resource Requirements

**Minimum:**
- CPU: 500 millicores
- Memory: 2GB physical (20GB virtual on AMD64 for WebAssembly)

**Important:** On AMD64 architecture (not ARM), the API service must set:
```bash
CUSTOM_CODE_MEMORY_LIMIT=21474836480  # 20GB
```

This ensures sufficient virtual memory for WebAssembly execution.

### Scaling

- Scale horizontally based on job utilization
- Monitor `custom_code_runner_remaining_job_spaces` metric
- See [Autoscaling](../autoscaling.md)

### Network Access

**Important:** Custom Code Runner should only be accessible internally from other Membrane services (API, workers). Do NOT expose to the public internet.

### Health Check

```
GET http://custom-code-runner:5000/api/v2/health
```

## Deployment Checklist

Before deploying, ensure:

- [ ] Cloud resources provisioned (MongoDB, Redis, Storage)
- [ ] Authentication configured (Auth0 or username/password)
- [ ] Docker registry access configured
- [ ] Environment variables prepared
- [ ] SSL certificates obtained for HTTPS
- [ ] DNS records configured
- [ ] Load balancers configured (for API, UI, Console)
- [ ] Health checks configured
- [ ] Monitoring and logging set up

## Complete Environment Variables Example

Here's a complete example for production deployment:

```bash
# Common to all API-based services (API, Workers, Orchestrator)
NODE_ENV=production
BASE_URI=https://api.yourdomain.com
CUSTOM_CODE_RUNNER_URI=http://custom-code-runner:5000
PORT=5000

# Secrets
SECRET=<generate-random-32-char-string>
ENCRYPTION_SECRET=<generate-random-32-char-string>

# Database
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/membrane

# Redis
REDIS_URI=rediss://:password@redis-host:6379

# Storage (AWS example)
STORAGE_PROVIDER=s3
AWS_REGION=us-east-1
TMP_STORAGE_BUCKET=prod-integration-app-tmp
CONNECTORS_STORAGE_BUCKET=prod-integration-app-connectors
STATIC_STORAGE_BUCKET=prod-integration-app-static
BASE_STATIC_URI=https://static.yourdomain.com

# Auth0
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret

# Optional
ENABLE_LIMITS=true
MAX_NODE_RUN_OUTPUT_SIZE_MB=50
```

## Metrics and Monitoring

All services expose Prometheus metrics for monitoring and autoscaling.

### API Service Metrics

Endpoint: `http://api-service:5000/prometheus`

Key metrics:
- `instant_tasks_jobs_active` - Active instant tasks
- `instant_tasks_jobs_waiting` - Queued instant tasks
- `queued_tasks_workers` - Current queued workers count
- `queued_tasks_workers_required` - Required queued workers

### Custom Code Runner Metrics

Endpoint: `http://custom-code-runner:5000/api/v2/prometheus`

Key metrics:
- `custom_code_runner_total_job_spaces` - Total job capacity
- `custom_code_runner_remaining_job_spaces` - Available job slots

### Queued Tasks Worker Metrics

Endpoint: `http://queued-worker:5000/prometheus/queued-tasks`

Key metrics:
- `queued_tasks_worker_busy` - Worker busy status (0 or 1)

See [Autoscaling](../autoscaling.md) for how to use these metrics.

## Debugging

For enhanced debugging output, add to any container:

```bash
DEBUG_ALL=1
```

This enables verbose logging for troubleshooting.

## Next Steps

Choose your deployment platform:

- [Kubernetes Deployment](kubernetes.md) - Deploy on Kubernetes
- [Helm Deployment](helm.md) - Simplified Kubernetes deployment
- [Container Services](container-services.md) - ECS, Azure Container Apps, Cloud Run

After deployment:
- Configure [Autoscaling](../autoscaling.md)
- Set up [System Webhooks](../system-webhooks.md)
- Manage [Connectors](../connector-management.md)
