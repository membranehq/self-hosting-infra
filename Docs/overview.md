# Overview

Membrane is a self-hosted integration platform distributed as Docker containers. This guide covers everything you need to deploy and manage Membrane in your infrastructure.

## Architecture

Membrane consists of four core services that work together to provide a complete integration platform:

### Core Services

#### 1. API Service
The primary backend engine that stores and executes integrations. Runs in four distinct modes:

- **API Mode** - Handles incoming HTTP traffic and API requests
- **Instant Tasks Worker** - Processes semi-instant asynchronous tasks
- **Queued Tasks Worker** - Handles long-running tasks (flows, event pulls, external events)
- **Orchestrator** - Manages schedule triggers, data source syncs, and cleanup tasks

#### 2. UI Service
Pre-built integration user interfaces for end users to connect and manage their integrations.

#### 3. Console Service
Administrative interface for managing integrations, connectors, and platform configuration.

#### 4. Custom Code Runner
Isolated environment for executing custom code in connectors and middleware. Should only be accessible internally from other services.

All services scale horizontally and can be deployed across multiple instances.

## Registry Access

To deploy Membrane, you'll need access credentials to our Docker registry.

### Docker Registry

Contact our support team to receive Docker registry credentials:

**Registry URL:** `harbor.integration.app`

**Username format:** `robot$core+<your-company-name>`

You'll receive a unique password for authentication.

#### Login to Docker Registry

```bash
docker login harbor.integration.app
```

When prompted, enter your credentials.

#### Image Naming Convention

All Docker images follow this pattern:

```
harbor.integration.app/core/<service-name>:<tag>
```

**Available services:**
- `harbor.integration.app/core/api`
- `harbor.integration.app/core/ui`
- `harbor.integration.app/core/console`
- `harbor.integration.app/core/custom-code-runner`

#### Image Versioning

Images are tagged with:
- `:latest` - Most recent build (not recommended for production)
- Date-based immutable tags - e.g., `:2025-09-19` (recommended for production)

**Production recommendation:** Always use immutable date-based tags:

```
harbor.integration.app/core/api:2025-09-19
```

### Helm Registry

If you plan to use Helm for Kubernetes deployment, you'll also need Helm registry credentials:

**Registry URL:** `harbor.integration.app/helm`

**Username format:** `robot$helm+<your-company-name>`

#### Login to Helm Registry

```bash
helm registry login harbor.integration.app \
  --username <helm-username> \
  --password <helm-password>
```

#### Pull Helm Charts

```bash
helm pull oci://harbor.integration.app/helm/integration-app --version <version> --untar
```

See [Helm Deployment](deployment/helm.md) for detailed Helm installation instructions.

## Infrastructure Requirements

Before deploying Membrane, you'll need to provision these cloud resources:

### Required Components

1. **Cloud Storage** - For storing temporary files, connectors, and static assets
   - AWS S3
   - Azure Blob Storage
   - Google Cloud Storage

2. **MongoDB** - Primary database (MongoDB Atlas recommended)
   - Version 4.4 or higher
   - Replica set configuration recommended for production

3. **Redis** - Cache and job queue
   - Version 6.0 or higher
   - Redis Cluster supported

4. **Authentication Provider**
   - Auth0 (recommended, free tier sufficient)
   - Username/Password provider (built-in alternative)

### See Also

- [Cloud Resources Setup](cloud-resources/index.md) - Detailed infrastructure setup
- [Authentication Configuration](authentication/auth0.md) - Auth provider setup
- [Deployment Guide](deployment/services.md) - Service deployment and configuration

## Deployment Overview

Membrane can be deployed on various platforms:

- **Kubernetes** - Recommended for production (see [Kubernetes Deployment](deployment/kubernetes.md))
- **Helm** - Simplified Kubernetes deployment (see [Helm Charts](deployment/helm.md))
- **Container Services** - ECS, Azure Container Apps, Cloud Run (see [Container Services](deployment/container-services.md))
- **Docker Compose** - Development and testing

## Next Steps

1. [Set up cloud resources](cloud-resources/index.md) - Provision MongoDB, Redis, and cloud storage
2. [Configure authentication](authentication/auth0.md) - Set up Auth0 or username/password auth
3. [Deploy services](deployment/services.md) - Deploy and configure Membrane services
4. [Configure autoscaling](autoscaling.md) - Set up production autoscaling (optional)

## Support

For registry access, technical questions, or issues:
- Contact your designated support channel
- Check the [FAQ](faq.md) for common solutions
