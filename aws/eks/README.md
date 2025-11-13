# AWS EKS Infrastructure for Integration.app

This Terraform module creates a complete AWS EKS (Elastic Kubernetes Service) infrastructure for running Integration.app in a self-hosted environment.

## Architecture Overview

This module provisions:

- **VPC**: Multi-AZ VPC with public and private subnets, NAT gateways, and internet gateway
- **EKS Cluster**: Managed Kubernetes cluster with OIDC provider for IRSA
- **EKS Managed Node Group**: Auto-scaling worker nodes across multiple AZs
- **EKS Addons**: vpc-cni, kube-proxy, coredns, ebs-csi-driver
- **ElastiCache Redis**: Cluster-mode enabled with encryption and Multi-AZ
- **S3 Buckets**: tmp, connectors, and static buckets with lifecycle policies
- **CloudFront**: CDN for static assets with OAC
- **ACM Certificates**: SSL/TLS certificates for ALB and CloudFront
- **Route53 Records**: DNS records for static assets and certificate validation
- **IAM Roles**: IRSA roles for integration-app, AWS Load Balancer Controller, and External DNS

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.11.3
3. **Route53 Hosted Zone** already created
4. **IAM Users** created for cluster admin access

## Quick Start

### 1. Configure Variables

Copy the sample variables file and customize it:

```bash
cp terraform.tfvars-sample terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
environment = "dev"
aws_region  = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

route53_zone_id  = "Z1234567890ABC"
hosted_zone_name = "example.com"

eks_admin_users = ["your-iam-username"]
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan and Apply

```bash
terraform plan
terraform apply
```

**Note**: The initial apply takes approximately 15-20 minutes as it creates the VPC, EKS cluster, node group, and all supporting resources.

### 4. Configure kubectl

After the cluster is created, configure kubectl to access it:

```bash
aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region us-east-1
```

Test access:

```bash
kubectl get nodes
```

## Post-Deployment Steps

### 1. Install AWS Load Balancer Controller

The IAM role is already created. Install the controller using Helm:

```bash
# Add the EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get the IAM role ARN
export ALB_CONTROLLER_ROLE_ARN=$(terraform output -raw load_balancer_controller_role_arn)

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw eks_cluster_name) \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_CONTROLLER_ROLE_ARN
```

### 2. Install External DNS (Optional)

If you want automatic DNS record management:

```bash
export EXTERNAL_DNS_ROLE_ARN=$(terraform output -raw external_dns_role_arn)

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm install external-dns external-dns/external-dns \
  -n kube-system \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EXTERNAL_DNS_ROLE_ARN \
  --set provider=aws \
  --set policy=sync \
  --set registry=txt \
  --set txtOwnerId=$(terraform output -raw eks_cluster_name)
```

### 3. Install KEDA for Autoscaling

The Integration.app Helm chart uses KEDA for event-driven autoscaling:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
```

### 4. Install Prometheus (for KEDA metrics)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### 5. Deploy Integration.app

Now you can deploy the Integration.app using the Helm chart. First, create a values file:

```yaml
# integration-app-values.yaml
image:
  repository: harbor.integration.app
  tag: latest

imagePullSecrets:
  - name: integration-app-harbor

serviceAccount:
  create: true
  name: integration-app
  annotations:
    eks.amazonaws.com/role-arn: <integration-app-sa-role-arn>

redis:
  uri: <redis-uri-from-terraform-output>

storage:
  tmp:
    bucket: <tmp-bucket-name>
  connectors:
    bucket: <connectors-bucket-name>
  static:
    bucket: <static-bucket-name>
    uri: <static-uri>
```

Deploy:

```bash
# Create Harbor credentials secret
kubectl create secret docker-registry integration-app-harbor \
  --docker-server=harbor.integration.app \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace default

# Deploy Integration.app
helm install integration-app ./path/to/helm/chart \
  --namespace default \
  -f integration-app-values.yaml
```

## Key Outputs

After applying, use these commands to get important values:

```bash
# EKS Cluster
terraform output eks_cluster_name
terraform output eks_cluster_endpoint
terraform output eks_cluster_oidc_issuer_url

# IAM Roles
terraform output integration_app_sa_role_arn
terraform output load_balancer_controller_role_arn
terraform output external_dns_role_arn

# Storage
terraform output tmp_bucket_name
terraform output connectors_bucket_name
terraform output static_bucket_name
terraform output static_uri

# Redis
terraform output redis_configuration_endpoint
terraform output redis_port
terraform output -raw redis_uri  # Sensitive
```

## Architecture Details

### VPC Design

- **CIDR**: Default `10.0.0.0/16` (customizable)
- **Subnets**: 3 public + 3 private (one per AZ)
- **Public Subnets**: Used for ALB/NLB and NAT gateways
- **Private Subnets**: Used for EKS nodes, Redis, and pods
- **NAT Gateways**: One per AZ for high availability
- **Kubernetes Tags**: Subnets are tagged for automatic discovery by AWS Load Balancer Controller

### EKS Cluster

- **Version**: Kubernetes 1.31 (default, configurable)
- **Control Plane Logging**: API, audit, authenticator, controller manager, scheduler
- **Endpoint Access**: Both public and private (configurable)
- **OIDC Provider**: Automatically created for IRSA (IAM Roles for Service Accounts)

### Node Group

- **Instance Types**: t3.xlarge (default, customizable)
- **Capacity**: 2 desired, 1 min, 10 max (customizable)
- **Disk**: 100GB EBS volumes
- **Capacity Type**: ON_DEMAND (can use SPOT for cost savings)
- **Placement**: Private subnets across all AZs
- **Auto Scaling**: Managed by EKS

### Redis (ElastiCache)

- **Mode**: Cluster mode enabled
- **Engine**: Redis 7.1
- **Encryption**: At-rest and in-transit (TLS)
- **Shards**: 2 (default, customizable)
- **Replicas**: 1 per shard (default, customizable)
- **Multi-AZ**: Enabled with automatic failover
- **Port**: 6380 (TLS)
- **Backups**: 7-day retention

### Security

- **Cluster Security Group**: Allows communication between control plane and nodes
- **Node Security Group**: Allows inter-node communication and cluster API access
- **Redis Security Group**: Only allows access from EKS nodes on port 6380
- **IRSA**: Fine-grained IAM permissions for pods using service accounts

## Cost Optimization

### Use Spot Instances

Set `node_group_capacity_type = "SPOT"` in terraform.tfvars for ~70% cost savings on compute.

### Reduce Redis Costs

- Use smaller node type: `cache.t4g.micro` (ARM-based)
- Reduce shards/replicas for non-production environments

### Optimize NAT Gateways

For dev/test environments, consider using a single NAT gateway instead of one per AZ.

## Troubleshooting

### Cannot access EKS cluster

1. Ensure your IAM user is in the `eks_admin_users` list
2. Update kubeconfig: `aws eks update-kubeconfig --name <cluster-name>`
3. Check IAM permissions for `eks:DescribeCluster`

### Pods cannot pull images

1. Ensure Harbor credentials secret exists
2. Check service account has `imagePullSecrets` configured
3. Verify node security groups allow egress to Harbor

### Redis connection fails

1. Check security groups allow traffic from nodes to Redis
2. Verify TLS is enabled in your Redis client (`rediss://` not `redis://`)
3. Check subnet group has correct private subnets

### ALB not created

1. Ensure AWS Load Balancer Controller is installed
2. Check controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`
3. Verify IAM role has correct permissions

## Cleanup

To destroy all resources:

```bash
# Warning: This will delete everything including data in S3 and Redis!
terraform destroy
```

**Note**: You may need to manually delete any load balancers created by Kubernetes services before destroying the VPC.

## Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [KEDA Documentation](https://keda.sh/)
- [Integration.app Documentation](https://docs.integration.app/)
