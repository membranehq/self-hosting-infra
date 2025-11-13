# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

# EKS Cluster Outputs
output "eks_cluster_id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, "")
}

output "eks_cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# S3 Outputs
output "tmp_bucket_name" {
  value = aws_s3_bucket.tmp.bucket
}

output "connectors_bucket_name" {
  value = aws_s3_bucket.connectors.bucket
}

output "static_bucket_name" {
  value = aws_s3_bucket.static.bucket
}

output "redis_primary_endpoint" {
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  description = "Primary endpoint for Redis (cluster mode disabled)"
}

output "redis_reader_endpoint" {
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
  description = "Reader endpoint for Redis (cluster mode disabled)"
}

output "redis_port" {
  value = aws_elasticache_replication_group.redis.port
}

output "redis_uri" {
  value       = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
  sensitive   = true
  description = "Redis URI with TLS (rediss://)"
}

output "static_uri" {
  value = "https://static.${var.environment}.${var.hosted_zone_name}"
}

output "membrane_sa_role_arn" {
  value       = aws_iam_role.integration_app_sa.arn
  description = "IAM role ARN for the membrane service account"
}

# Legacy output name for backwards compatibility
output "integration_app_sa_role_arn" {
  value       = aws_iam_role.integration_app_sa.arn
  description = "IAM role ARN for the integration-app service account (deprecated, use membrane_sa_role_arn)"
}

output "external_dns_role_arn" {
  value       = try(aws_iam_role.external_dns.arn, "")
  description = "IAM role ARN for External DNS controller"
}

output "hosted_zone_name" {
  value       = var.hosted_zone_name
  description = "Name of the hosted zone"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region where resources are deployed"
}

output "load_balancer_controller_role_arn" {
  value       = aws_iam_role.load_balancer_controller.arn
  description = "IAM role ARN for AWS Load Balancer Controller"
}

output "alb_certificate_arn" {
  value       = aws_acm_certificate.alb.arn
  description = "ARN of the ACM certificate for ALB"
}

output "nat_gateway_ips" {
  value       = aws_eip.nat[*].public_ip
  description = "Public IPs of NAT Gateways - whitelist these in MongoDB Atlas"
}
