# Frequently Asked Questions

Common questions and troubleshooting for self-hosted Membrane deployments.

## General Questions

### What are the minimum infrastructure requirements?

**For development/testing:**
- 2 vCPUs, 8GB RAM total across all services
- MongoDB (can be shared dev instance)
- Redis (can be minimal instance)
- Cloud storage bucket

**For production:**
- 8-16 vCPUs, 32-64GB RAM (with autoscaling)
- MongoDB Atlas M10+ cluster (3-node replica set)
- Redis with high availability
- Cloud storage with CDN
- Load balancers for public services

See [Services Overview](deployment/services.md) for detailed requirements.

### Which MongoDB versions are supported?

MongoDB 4.4 or higher. We recommend MongoDB Atlas for managed service.

**Not supported:**
- AWS DocumentDB (compatibility issues)
- Azure Cosmos DB with MongoDB API (compatibility issues)

### Can I use Redis Serverless?

No. AWS ElastiCache Serverless for Redis is not compatible. Use standard ElastiCache or cluster mode.

### How much does it cost to run Membrane self-hosted?

Costs vary by cloud provider and usage. Typical production costs:

**AWS (example):**
- EKS cluster: ~$75/month
- MongoDB Atlas M10: ~$60/month
- Redis: ~$50/month
- S3 + CloudFront: ~$20-100/month
- EC2/Fargate: ~$200-500/month
- **Total: ~$405-785/month**

**Azure/GCP:** Similar costs, varies by region and services chosen.

## Authentication

### Can I use my own authentication instead of Auth0?

Yes. Membrane includes a built-in username/password authentication provider. See [Username/Password Authentication](authentication/username-password.md).

### How do I migrate users from Auth0 to username/password?

1. Export users from Auth0
2. Remove Auth0 environment variables from Membrane services
3. Restart services
4. Import users or trigger password reset emails

### Can I use SSO/SAML?

SSO/SAML is supported through Auth0. The built-in username/password provider does not support SSO.

## Deployment

### Which deployment platform should I choose?

**Kubernetes (recommended):**
- Best for production
- Full autoscaling capabilities
- Most flexibility
- Use Helm for easiest deployment

**Container Services (ECS, Container Apps):**
- Good for production
- Managed infrastructure
- Some autoscaling limitations
- Simpler than Kubernetes

**Docker Compose:**
- Development/testing only
- Not recommended for production

### How do I update Membrane to a new version?

1. Pull new Docker images with updated tags
2. Update deployment configurations with new image tags
3. Deploy using rolling update strategy (deploy workers first, then API)
4. Verify health checks pass

**Kubernetes:**
```bash
kubectl set image deployment/api api=harbor.integration.app/core/api:NEW_VERSION -n membrane
kubectl rollout status deployment/api -n membrane
```

**Helm:**
```bash
helm upgrade membrane ./integration-app-chart --namespace membrane
```

### Can I run everything on a single server?

For development/testing, yes. For production, we strongly recommend:
- Multiple instances of each service
- Separate managed MongoDB and Redis
- Load balancers for public-facing services
- Autoscaling for worker services

## Storage

### Can I use different storage providers for different buckets?

No. All three buckets (tmp, connectors, static) must use the same storage provider (S3, Azure Blob, or GCS).

### How much storage do I need?

**Typical usage:**
- Temporary bucket: 10-50GB (auto-deleted after 7 days)
- Connectors bucket: 1-5GB
- Static bucket: Variable (depends on user uploads)

### Do I need CloudFront/CDN for static files?

**Development:** No, you can serve directly from storage bucket.

**Production:** Yes, recommended for:
- Better performance
- Lower storage costs
- HTTPS/custom domain support
- Caching

## Networking

### Which services need to be publicly accessible?

**Public (via load balancer + HTTPS):**
- API service
- UI service
- Console service

**Internal only:**
- Custom Code Runner
- Instant Tasks Worker
- Queued Tasks Worker
- Orchestrator

### What ports do services use?

All services listen on port 5000 by default (configurable via `PORT` environment variable).

### Do I need a VPN for MongoDB/Redis access?

**Recommended for production:**
- Use private networking (VPC peering, private endpoints)
- Whitelist Membrane service IPs in MongoDB Atlas
- Use Redis in private subnet with VPC access

**Alternative:**
- Use connection strings with TLS/SSL
- Firewall rules limiting access
- VPN not strictly required but adds security

## Performance

### How many requests can Membrane handle?

Depends on your infrastructure and autoscaling configuration. With proper autoscaling:
- API: 1000s of requests/second
- Workers: Processes jobs concurrently based on replica count
- Limited by MongoDB and Redis performance

### Why are my integrations running slowly?

**Common causes:**
- Insufficient worker replicas (scale up workers)
- MongoDB performance issues (upgrade instance)
- Redis connection issues (check connectivity)
- Custom Code Runner capacity (scale up)
- Network latency (collocate services in same region)

**Check:**
- Prometheus metrics for queue lengths
- Worker busy rates
- Custom Code Runner capacity

### How do I optimize for large workloads?

1. Enable autoscaling (see [Autoscaling Guide](autoscaling.md))
2. Increase worker memory limits
3. Scale MongoDB (larger instance or read replicas)
4. Use Redis cluster for high throughput
5. Monitor and tune based on metrics

## Troubleshooting

### Services won't start - CrashLoopBackOff

**Check:**
1. Environment variables are set correctly
2. MongoDB connection string is valid and accessible
3. Redis connection string is valid and accessible
4. Storage bucket names and credentials are correct
5. Container logs for specific error messages

```bash
kubectl logs <pod-name> -n membrane
```

### "Cannot connect to MongoDB" error

**Verify:**
- Connection string format is correct
- Network connectivity (firewall rules, VPC peering)
- MongoDB IP whitelist includes your services
- Credentials are valid
- MongoDB cluster is running

**Test connection:**
```bash
mongosh "mongodb+srv://user:pass@cluster.mongodb.net/test"
```

### "Cannot connect to Redis" error

**Verify:**
- Redis connection string format
- Redis is running and accessible
- Correct port (6379 standard, 6380 for TLS)
- Password/auth token is correct
- Network connectivity

### Custom code isn't executing

**Check:**
1. Custom Code Runner service is running
2. `CUSTOM_CODE_RUNNER_URI` is set correctly on API/workers
3. Custom Code Runner is accessible from API/worker services
4. Memory limits are sufficient (20GB virtual for AMD64)
5. Custom Code Runner logs for errors

### Storage bucket access denied

**AWS S3:**
- Verify IAM role permissions or access keys
- Check bucket policies
- Ensure bucket names are correct

**Azure Blob:**
- Verify storage account credentials or managed identity
- Check container access level
- Ensure container names are correct

**GCP:**
- Verify service account permissions
- Check bucket IAM policies
- Ensure Workload Identity is configured (GKE)

### Health checks are failing

**Verify:**
- Service is actually running (check logs)
- Port is correct (default 5000)
- Health check path is correct (`/` for most services)
- Startup time is sufficient (increase grace period)
- Service has finished initialization

## Monitoring & Debugging

### How do I enable debug logging?

Add to any service:
```bash
DEBUG_ALL=1
```

This enables verbose logging for troubleshooting.

### What metrics should I monitor?

**Key metrics:**
- Pod CPU and memory utilization
- `instant_tasks_jobs_waiting` - Instant tasks queue depth
- `queued_tasks_workers_required` - Required queued workers
- `custom_code_runner_remaining_job_spaces` - Available capacity
- MongoDB connection pool
- Redis connection status
- HTTP error rates (4xx, 5xx)

### How do I set up monitoring?

1. Install Prometheus and Grafana (see [Kubernetes guide](deployment/kubernetes.md#monitoring))
2. Configure ServiceMonitors for Membrane services
3. Import or create Grafana dashboards
4. Set up alerts for critical metrics

### Where are logs stored?

Services log to stdout/stderr. Configure log aggregation:
- **Kubernetes:** Use kubectl logs or log aggregation (ELK, Loki)
- **AWS ECS:** CloudWatch Logs
- **Azure:** Log Analytics
- **GCP:** Cloud Logging

## Security

### How are credentials encrypted?

Credentials are encrypted at rest using `ENCRYPTION_SECRET` environment variable. Use a strong, random 32+ character string.

### Should I rotate secrets?

**Recommended rotation schedule:**
- `SECRET` (JWT signing): Every 90 days
- `ENCRYPTION_SECRET`: Every 90 days (requires credential re-encryption)
- Database passwords: Every 90 days
- Auth0 client secret: Every 90 days

### How do I backup my data?

**MongoDB:**
- MongoDB Atlas: Automatic continuous backups
- Self-hosted: mongodump or snapshot backups

**Storage buckets:**
- Enable versioning
- Configure cross-region replication (production)
- Regular snapshots

**Redis:**
- Not needed - data is ephemeral and can be rebuilt

### Is traffic encrypted?

**Between services:**
- Use TLS for MongoDB and Redis connections
- Use private networking (VPC) when possible

**Public traffic:**
- Always use HTTPS for API, UI, Console
- Use valid SSL/TLS certificates
- Enforce HTTPS redirects

## Scaling & Cost

### How do I reduce costs?

1. Use autoscaling to scale down during low usage
2. Use spot/preemptible instances for workers (where possible)
3. Right-size instances (don't over-provision)
4. Use managed services (MongoDB Atlas, Redis) instead of self-hosting
5. Enable storage lifecycle policies for temp bucket
6. Use CDN caching effectively

### When should I scale up?

**Indicators:**
- High CPU/memory utilization (>70%)
- Growing job queues
- Increased latency
- Custom Code Runner at capacity

See [Autoscaling](autoscaling.md) for automated scaling.

### Can I run Membrane in multiple regions?

Membrane is designed for single-region deployment. For multi-region:
- Deploy separate Membrane instances per region
- Each instance needs its own MongoDB and Redis
- Shared connectors bucket is possible
- No built-in cross-region sync

## Support

### Where can I get help?

1. Check this FAQ
2. Review relevant documentation sections
3. Contact your designated support channel
4. Include logs and error messages when requesting help

### How do I report a bug?

Provide:
- Membrane version (Docker image tags)
- Deployment platform (EKS, AKS, GKE, ECS, etc.)
- Error messages and logs
- Steps to reproduce
- Environment details (cloud provider, region)

### Can I get help with custom connectors?

Yes, contact support for:
- Connector development guidance
- Debugging connector issues
- Best practices for custom connectors

## Migration

### How do I migrate from Membrane Cloud to self-hosted?

1. Set up cloud infrastructure (see [Cloud Resources](cloud-resources/index.md))
2. Deploy Membrane services
3. Download connectors using Membrane CLI
4. Upload connectors to self-hosted instance
5. Recreate integrations
6. Test thoroughly before switching production traffic

### Can I migrate back to Membrane Cloud?

Migration back to cloud requires coordination with Membrane support team.

### How do I migrate between cloud providers?

1. Set up infrastructure on new cloud provider
2. Deploy Membrane to new environment
3. Export and import MongoDB data
4. Upload connectors
5. Switch DNS to new environment

## Next Steps

- Review specific guides for your deployment platform
- Set up monitoring and alerting
- Configure autoscaling
- Plan backup and disaster recovery strategy
