# Self-Hosting Documentation

Welcome to the Membrane self-hosting documentation. This guide will help you deploy and manage Membrane in your own infrastructure.

## Quick Start

1. [**Overview**](overview.md) - Understand Membrane architecture and get registry access
2. [**Cloud Resources**](cloud-resources/index.md) - Set up required cloud infrastructure
3. [**Authentication**](authentication/auth0.md) - Configure authentication provider
4. [**Deployment**](deployment/services.md) - Deploy Membrane services
5. [**Autoscaling**](autoscaling.md) - Configure autoscaling for production workloads

## Documentation Structure

### Getting Started

- [Overview](overview.md) - Product architecture and registry access
- [Cloud Resources](cloud-resources/index.md) - Required infrastructure components
  - [AWS Resources](cloud-resources/aws.md)
  - [Azure Resources](cloud-resources/azure.md)
  - [Google Cloud Resources](cloud-resources/gcp.md)

### Authentication

- [Auth0](authentication/auth0.md) - Auth0 configuration (recommended)
- [Username/Password](authentication/username-password.md) - Built-in authentication provider

### Deployment

- [Services Overview](deployment/services.md) - Core services and configuration
- [Kubernetes Deployment](deployment/kubernetes.md) - Deploy on Kubernetes
- [Container Services](deployment/container-services.md) - Deploy on ECS, Azure Container Apps, etc.
- [Helm Charts](deployment/helm.md) - Simplified Kubernetes deployment with Helm

### Advanced Configuration

- [Autoscaling](autoscaling.md) - Production autoscaling configuration
- [System Webhooks](system-webhooks.md) - Configure platform-level webhooks
- [Connection Credentials Storage](connection-credentials-storage.md) - External credentials storage
- [Connector Management](connector-management.md) - Deploy and manage custom connectors

### Help & Troubleshooting

- [FAQ](faq.md) - Common questions and troubleshooting

## Support

For additional assistance:
- Contact our support team for registry access credentials
- Report issues through your designated support channel
- Check the FAQ for common solutions
