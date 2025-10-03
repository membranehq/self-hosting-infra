# Container Services Deployment

This guide covers deploying Membrane on managed container services like AWS ECS, Azure Container Apps, and Google Cloud Run.

## AWS ECS (Elastic Container Service)

### Prerequisites

- ECS cluster (Fargate or EC2)
- ECR or access to Harbor registry
- Cloud resources provisioned (see [AWS Resources](../cloud-resources/aws.md))

### Task Definition Example

```json
{
  "family": "membrane-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "taskRoleArn": "arn:aws:iam::ACCOUNT_ID:role/membrane-task-role",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "harbor.integration.app/core/api:2025-09-19",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NODE_ENV", "value": "production"},
        {"name": "IS_API", "value": "1"},
        {"name": "BASE_URI", "value": "https://api.yourdomain.com"},
        {"name": "STORAGE_PROVIDER", "value": "s3"},
        {"name": "AWS_REGION", "value": "us-east-1"}
      ],
      "secrets": [
        {"name": "SECRET", "valueFrom": "arn:aws:secretsmanager:..."},
        {"name": "MONGO_URI", "valueFrom": "arn:aws:secretsmanager:..."}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/membrane",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:5000/ || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      }
    }
  ]
}
```

### Deploy Services

Create similar task definitions for each service:
- `membrane-api` (with `IS_API=1`)
- `membrane-instant-worker` (with `IS_INSTANT_TASKS_WORKER=1`)
- `membrane-queued-worker` (with `IS_QUEUED_TASKS_WORKER=1`)
- `membrane-orchestrator` (with `IS_ORCHESTRATOR=1`)
- `membrane-ui`
- `membrane-console`
- `membrane-custom-code-runner`

### Create Services

```bash
aws ecs create-service \
  --cluster membrane-cluster \
  --service-name api \
  --task-definition membrane-api \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=api,containerPort=5000"
```

### Using IAM Roles

When using task roles (recommended), omit `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from environment variables.

## Azure Container Apps

### Prerequisites

- Azure Container Apps environment
- Access to Harbor registry or Azure Container Registry
- Cloud resources provisioned (see [Azure Resources](../cloud-resources/azure.md))

### Create Container App

```bash
az containerapp create \
  --name membrane-api \
  --resource-group membrane-rg \
  --environment membrane-env \
  --image harbor.integration.app/core/api:2025-09-19 \
  --target-port 5000 \
  --ingress external \
  --min-replicas 2 \
  --max-replicas 10 \
  --cpu 1.0 \
  --memory 2.0Gi \
  --env-vars \
    NODE_ENV=production \
    IS_API=1 \
    BASE_URI=https://api.yourdomain.com \
    STORAGE_PROVIDER=abs \
  --secrets \
    secret=secretvalue \
    mongo-uri=mongodb://... \
  --registry-server harbor.integration.app \
  --registry-username robot\$core+company \
  --registry-password <password>
```

### Using Managed Identity

Enable system-assigned identity:

```bash
az containerapp identity assign \
  --name membrane-api \
  --resource-group membrane-rg \
  --system-assigned
```

Grant storage access and omit `AZURE_STORAGE_CONNECTION_STRING` from environment.

## Google Cloud Run

### Prerequisites

- Google Cloud project
- Cloud Run enabled
- Cloud resources provisioned (see [GCP Resources](../cloud-resources/gcp.md))

### Deploy Service

```bash
gcloud run deploy membrane-api \
  --image harbor.integration.app/core/api:2025-09-19 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --min-instances 2 \
  --max-instances 10 \
  --memory 2Gi \
  --cpu 1 \
  --port 5000 \
  --set-env-vars \
    NODE_ENV=production,\
    IS_API=1,\
    BASE_URI=https://api.yourdomain.com,\
    STORAGE_PROVIDER=gcs \
  --set-secrets \
    SECRET=jwt-secret:latest,\
    MONGO_URI=mongo-uri:latest
```

**Note:** Cloud Run has a request timeout limit (60 minutes max). Long-running workers may need alternative deployment (GKE or GCE).

### Using Workload Identity

```bash
gcloud run services update membrane-api \
  --service-account membrane-sa@PROJECT.iam.gserviceaccount.com
```

## Deployment Strategy

### Service Deployment Order

1. **Custom Code Runner** (internal service)
2. **Orchestrator** (background service)
3. **Queued Tasks Worker** (background service)
4. **Instant Tasks Worker** (background service)
5. **API** (user-facing)
6. **UI** (user-facing)
7. **Console** (user-facing)

### Rolling Updates

For zero-downtime deployments:
- Use blue-green or rolling update strategies
- Deploy workers before API
- Ensure at least 2 instances running during updates

## Load Balancer Configuration

### AWS Application Load Balancer

- **Target group health check:** `GET / HTTP/1.1`
- **Healthy threshold:** 2
- **Unhealthy threshold:** 3
- **Timeout:** 5 seconds
- **Interval:** 30 seconds
- **Success codes:** 200

### Azure Application Gateway

- **Health probe path:** `/`
- **Interval:** 30 seconds
- **Timeout:** 30 seconds
- **Unhealthy threshold:** 3

### Google Cloud Load Balancer

- **Health check path:** `/`
- **Check interval:** 30 seconds
- **Timeout:** 5 seconds
- **Healthy threshold:** 2
- **Unhealthy threshold:** 3

## Secrets Management

### AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name membrane/jwt-secret \
  --secret-string "your-secret-value"
```

Reference in ECS task definition:
```json
{
  "secrets": [
    {
      "name": "SECRET",
      "valueFrom": "arn:aws:secretsmanager:region:account:secret:membrane/jwt-secret"
    }
  ]
}
```

### Azure Key Vault

```bash
az keyvault secret set \
  --vault-name membrane-vault \
  --name jwt-secret \
  --value "your-secret-value"
```

### Google Secret Manager

```bash
echo -n "your-secret-value" | gcloud secrets create jwt-secret --data-file=-
```

## Logging

### Centralized Logging

- **AWS:** CloudWatch Logs
- **Azure:** Log Analytics
- **GCP:** Cloud Logging

All services log to stdout/stderr in plain text format.

## Monitoring

Configure health checks for all services:
- API, UI, Console: `GET /`
- Custom Code Runner: `GET /api/v2/health`
- Workers: `GET /` or `GET /prometheus/queued-tasks`

## Autoscaling

Container services support auto-scaling:
- **AWS ECS:** Target tracking scaling policies
- **Azure Container Apps:** HTTP scaling rules or custom metrics
- **GCP Cloud Run:** Automatic based on requests

See [Autoscaling Guide](../autoscaling.md) for detailed configuration.

## Troubleshooting

### Common Issues

**Container fails to start:**
- Check logs in cloud provider console
- Verify environment variables
- Ensure MongoDB/Redis connectivity

**Cannot pull image:**
- Verify registry credentials
- Check network/firewall rules
- Ensure image name and tag are correct

**Health checks failing:**
- Verify container is listening on correct port
- Check startup time (increase grace period if needed)
- Review application logs

## Next Steps

- Configure [Autoscaling](../autoscaling.md)
- Set up monitoring and alerts
- Review [FAQ](../faq.md)
