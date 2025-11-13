# AWS EKS Infrastructure for Membrane

This Terraform module creates a complete AWS EKS (Elastic Kubernetes Service) infrastructure for running Membrane in a self-hosted environment.

## Architecture Overview

This module provisions:

- **VPC**: Multi-AZ VPC with public and private subnets, NAT gateways, and internet gateway
- **EKS Cluster**: Managed Kubernetes cluster with OIDC provider for IRSA
- **EKS Managed Node Group**: Auto-scaling worker nodes across multiple AZs
- **EKS Addons**: vpc-cni, kube-proxy, coredns, ebs-csi-driver
- **ElastiCache Redis**: Cluster-mode disabled with encryption and Multi-AZ
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

**IMPORTANT**: Install this controller BEFORE External DNS, as External DNS depends on the ALB Controller webhook.

The IAM role is already created. Install the controller using Helm:

```bash
# Add the EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get the IAM role ARN and VPC ID
export ALB_CONTROLLER_ROLE_ARN=$(terraform output -raw load_balancer_controller_role_arn)
export VPC_ID=$(terraform output -raw vpc_id)

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw eks_cluster_name) \
  --set region=$(terraform output -raw aws_region) \
  --set vpcId=$VPC_ID \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_CONTROLLER_ROLE_ARN

# Verify the controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### 2. Install External DNS (Optional)

**NOTE**: Ensure AWS Load Balancer Controller is installed first (see step 1 above).

If you want automatic DNS record management:

```bash
export EXTERNAL_DNS_ROLE_ARN=$(terraform output -raw external_dns_role_arn)
export HOSTED_ZONE_NAME=$(terraform output -raw hosted_zone_name)

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm install external-dns external-dns/external-dns \
  -n kube-system \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EXTERNAL_DNS_ROLE_ARN \
  --set provider=aws \
  --set policy=sync \
  --set registry=txt \
  --set txtOwnerId=$(terraform output -raw eks_cluster_name) \
  --set domainFilters[0]=$HOSTED_ZONE_NAME

# Verify the controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
```

### 3. Install KEDA for Autoscaling

The Membrane Helm chart uses KEDA for event-driven autoscaling:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace

# Verify KEDA is running
kubectl get pods -n keda
```

### 4. Install Metrics Server

Metrics Server is required for `kubectl top` commands and for Lens/K9s to display resource usage:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify it's running
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Test it works
kubectl top nodes
```

### 5. Install Prometheus (for KEDA metrics)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### 6. Install NGINX Ingress Controller

The Membrane Helm chart requires NGINX Ingress Controller with the `public-nginx` IngressClass:

```bash
# Add NGINX Ingress repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.ingressClassResource.name=public-nginx \
  --set controller.ingressClass=public-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing"

# Verify the controller is running
kubectl get pods -n ingress-nginx

# Verify the IngressClass was created
kubectl get ingressclass

# Get the NLB DNS name (you'll need to point your DNS records to this)
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 7. Install cert-manager

cert-manager is required for automatic TLS certificate provisioning from Let's Encrypt:

```bash
# Add cert-manager Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.2 \
  --set crds.enabled=true

# Verify cert-manager is running
kubectl get pods -n cert-manager
```

### 8. Create Let's Encrypt ClusterIssuer

Create a ClusterIssuer for automatic certificate issuance:

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@integration.app  # Change this to your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: public-nginx
EOF

# Verify the ClusterIssuer is ready
kubectl get clusterissuer letsencrypt-prod
```

### 9. Deploy Membrane

First, pull the Helm chart from Harbor:

```bash
helm pull oci://harbor.integration.app/helm/integration-app --version 0.2.3
tar -xzf integration-app-0.2.3.tgz
```

Create a values file:

```yaml
# membrane-values.yml
image:
  repository: harbor.integration.app/core
  tag: latest

imagePullSecrets:
  - name: membrane-harbor

serviceaccount:
  create: true
  name: membrane
  annotations:
    eks.amazonaws.com/role-arn: <membrane-sa-role-arn>

app:
  brand: membrane
  env: development
  serviceAccountName: membrane

config:
  NODE_ENV: production
  MONGO_URI: <your-mongodb-uri>
  REDIS_URI: <redis-uri-from-terraform-output>

  # Service URIs - update with your actual domain
  API_URI: https://api.development.<your-domain>
  UI_URI: https://app.development.<your-domain>
  CONSOLE_URI: https://console.development.<your-domain>

  # S3 Buckets
  CONNECTORS_S3_BUCKET: <connectors-bucket-name>
  TMP_S3_BUCKET: <tmp-bucket-name>
  STATIC_S3_BUCKET: <static-bucket-name>
  BASE_STATIC_URI: <static-uri>

  # Auth0 Settings
  AUTH0_DOMAIN: <your-auth0-domain>
  AUTH0_CLIENT_ID: <your-auth0-client-id>
  AUTH0_CLIENT_SECRET: <your-auth0-client-secret>

  # Secrets - generate random strings for these
  SECRET: <your-jwt-secret>
  ENCRYPTION_SECRET: <your-encryption-secret>

  # Cloud flag
  NEXT_PUBLIC_IS_CLOUD: "false"
```

Deploy:

```bash
# Create Harbor credentials secret
kubectl create secret docker-registry membrane-harbor \
  --docker-server=harbor.integration.app \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace default

# Deploy Membrane
helm install membrane ./integration-app \
  --namespace default \
  -f membrane-values.yml

# Verify all pods are running
kubectl get pods -n default

# Check certificate status (certificates are auto-generated by cert-manager)
kubectl get certificates -n default
kubectl get certificaterequests -n default

# The ingress is pre-configured with these TLS features:
# - cert-manager.io/cluster-issuer: letsencrypt-prod
# - nginx.ingress.kubernetes.io/proxy-body-size: "100m" (for file uploads)
# - nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
# - nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

**Note**: The Helm chart's ingress template is pre-configured to request TLS certificates from cert-manager automatically. Certificates will be issued within a few minutes after deployment.

## Key Outputs

After applying, use these commands to get important values:

```bash
# EKS Cluster
terraform output eks_cluster_name
terraform output eks_cluster_endpoint
terraform output eks_cluster_oidc_issuer_url

# IAM Roles
terraform output membrane_sa_role_arn
terraform output load_balancer_controller_role_arn
terraform output external_dns_role_arn

# Storage
terraform output tmp_bucket_name
terraform output connectors_bucket_name
terraform output static_bucket_name
terraform output static_uri

# Network
terraform output nat_gateway_ips  # Whitelist these in MongoDB Atlas

# Redis
terraform output redis_primary_endpoint
terraform output redis_reader_endpoint
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

- **Mode**: Cluster mode disabled (single primary with replicas)
- **Engine**: Redis 7.1
- **Encryption**: At-rest and in-transit (TLS)
- **Nodes**: 1 primary + 1 replica (default, customizable via redis_replicas_per_shard)
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

### TLS certificates not issued

1. Check cert-manager is running: `kubectl get pods -n cert-manager`
2. Check ClusterIssuer status: `kubectl get clusterissuer letsencrypt-prod`
3. Check certificate status: `kubectl describe certificate -n default`
4. Check certificate request status: `kubectl get certificaterequest -n default`
5. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`
6. Verify DNS records are pointing to the load balancer
7. Check Let's Encrypt rate limits (5 certificates per domain per week)
8. Restart CoreDNS to flush DNS cache: `kubectl rollout restart deployment coredns -n kube-system`

## Cleanup

To destroy all resources, you must first uninstall all Helm releases and then run Terraform destroy:

```bash
# Step 1: Uninstall Membrane application
helm uninstall membrane --namespace default

# Step 2: Uninstall cert-manager
helm uninstall cert-manager --namespace cert-manager
kubectl delete namespace cert-manager

# Step 3: Uninstall NGINX Ingress Controller
helm uninstall nginx-ingress --namespace ingress-nginx
kubectl delete namespace ingress-nginx

# Step 4: Uninstall Prometheus
helm uninstall prometheus-stack --namespace monitoring
kubectl delete namespace monitoring

# Step 5: Uninstall KEDA
helm uninstall keda --namespace keda
kubectl delete namespace keda

# Step 6: Uninstall External DNS (if installed)
helm uninstall external-dns --namespace kube-system

# Step 7: Uninstall AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller --namespace kube-system

# Step 8: Uninstall Metrics Server
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Step 9: Wait for all load balancers to be deleted (check AWS console)
# This is important to avoid VPC deletion errors

# Step 10: Destroy Terraform resources
# Warning: This will delete everything including data in S3 and Redis!
terraform destroy
```

**Important Notes:**
- You MUST uninstall all Helm releases before running `terraform destroy`
- Wait for all AWS Load Balancers to be fully deleted (check in AWS Console)
- This will permanently delete all data in S3 buckets and Redis
- DNS records created by External DNS will be removed

## Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [KEDA Documentation](https://keda.sh/)
- [External DNS Documentation](https://kubernetes-sigs.github.io/external-dns/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
