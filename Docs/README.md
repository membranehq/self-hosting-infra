# Membrane Self-Hosting Documentation

Complete documentation for deploying and managing Membrane in your infrastructure.

## Documentation Structure

```
Docs/
├── index.md                          # Documentation hub and navigation
├── overview.md                       # Product overview & registry access
│
├── cloud-resources/                  # Infrastructure setup
│   ├── index.md                      # General info + MongoDB Atlas
│   ├── aws.md                        # AWS-specific resources
│   ├── azure.md                      # Azure-specific resources
│   └── gcp.md                        # GCP-specific resources
│
├── authentication/                   # Auth configuration
│   ├── auth0.md                      # Auth0 setup (recommended)
│   └── username-password.md          # Built-in auth provider
│
├── deployment/                       # Service deployment
│   ├── services.md                   # Core services & config
│   ├── kubernetes.md                 # Kubernetes deployment
│   ├── container-services.md         # ECS, Azure Container Apps, etc.
│   └── helm.md                       # Helm chart deployment
│
├── autoscaling.md                    # Autoscaling configuration
├── system-webhooks.md                # System webhook setup
├── connection-credentials-storage.md # Credentials storage options
├── connector-management.md           # Connector deployment
└── faq.md                            # FAQ & troubleshooting
```

## Quick Start

1. **[Overview](overview.md)** - Understand the architecture and get registry access
2. **[Cloud Resources](cloud-resources/index.md)** - Set up MongoDB, Redis, and storage
3. **[Authentication](authentication/auth0.md)** - Configure Auth0 or username/password auth
4. **[Deployment](deployment/services.md)** - Deploy Membrane services
5. **[Autoscaling](autoscaling.md)** - Configure production autoscaling (optional)

## Key Features

### Comprehensive Coverage
- All cloud providers (AWS, Azure, GCP)
- Multiple deployment options (Kubernetes, Helm, container services)
- Both authentication methods (Auth0 and username/password)
- Production-ready configurations with Terraform examples

### Clear Organization
- Logical hierarchy from general to specific
- Separated concerns (resources, auth, deployment)
- Cloud-specific sections with explicit limitations
- Step-by-step guides with examples

### Production-Ready
- MongoDB Atlas integration with Terraform
- IAM/RBAC configurations for all cloud providers
- Autoscaling strategies with metrics
- Security best practices
- Troubleshooting and FAQ

## What's New

This documentation has been restructured for clarity and ease of use:

- **Separated cloud resources** - Each cloud provider has dedicated, focused documentation
- **Authentication options** - Detailed guides for both Auth0 and username/password
- **Deployment flexibility** - Separate guides for different deployment platforms
- **MongoDB Atlas focus** - Recommended managed database with Terraform examples
- **Explicit limitations** - Clear notes on unsupported services (DocumentDB, CosmosDB, Redis Serverless)
- **Autoscaling extracted** - Dedicated comprehensive autoscaling guide
- **FAQ added** - Common questions and troubleshooting in one place

## Contributing

When updating documentation:
1. Keep the structure organized by topic
2. Include working examples (preferably Terraform)
3. Specify cloud provider limitations explicitly
4. Add to FAQ for common questions
5. Cross-reference related pages

## Support

For help with self-hosting:
- Check the [FAQ](faq.md) first
- Review relevant section-specific documentation
- Contact your designated support channel
