output "tmp_bucket_name" {
  value = aws_s3_bucket.tmp.bucket
}

output "connectors_bucket_name" {
  value = aws_s3_bucket.connectors.bucket
}

output "static_bucket_name" {
  value = aws_s3_bucket.static.bucket
}

output "redis_uri" {
  value     = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379"
  sensitive = true
}

output "static_uri" {
  value = "https://static.${var.environment}.${var.hosted_zone_name}"
}

output "integration_app_sa_role_arn" {
  value       = aws_iam_role.integration_app_sa.arn
  description = "IAM role ARN for the integration-app service account"
}

output "external_dns_role_arn" {
  value       = try(aws_iam_role.external_dns.arn, "")
  description = "IAM role ARN for External DNS controller"
}

output "hosted_zone_name" {
  value       = var.hosted_zone_name
  description = "Name of the hosted zone"
}

output "public_subnet_cidr_blocks" {
  value       = var.public_subnet_cidr_blocks
  description = "List of public subnet CIDR blocks"
}
