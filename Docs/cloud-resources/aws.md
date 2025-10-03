# AWS Resources

This guide covers AWS-specific resource provisioning for Membrane.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured (optional, for manual setup)
- Terraform installed (recommended for infrastructure as code)

## Overview

Required AWS resources:
- **S3 Buckets** - Storage for temp files, connectors, and static assets
- **CloudFront Distribution** - CDN for serving static files
- **ElastiCache for Redis** - Caching and job queue
- **IAM Roles** - Service access permissions
- **MongoDB Atlas** - Database (see [Cloud Resources](index.md#mongodb-atlas-setup-terraform-example))

## S3 Storage

### Create S3 Buckets

```hcl
# Variables
variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

# Temporary files bucket
resource "aws_s3_bucket" "tmp" {
  bucket = "${var.environment}-integration-app-tmp"

  tags = {
    Environment = var.environment
    Service     = "membrane"
    Purpose     = "temporary-storage"
  }
}

# Lifecycle rule for automatic cleanup
resource "aws_s3_bucket_lifecycle_configuration" "tmp" {
  bucket = aws_s3_bucket.tmp.id

  rule {
    id     = "cleanup-old-files"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Block public access for tmp bucket
resource "aws_s3_bucket_public_access_block" "tmp" {
  bucket = aws_s3_bucket.tmp.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Connectors bucket
resource "aws_s3_bucket" "connectors" {
  bucket = "${var.environment}-integration-app-connectors"

  tags = {
    Environment = var.environment
    Service     = "membrane"
    Purpose     = "connector-storage"
  }
}

# Enable versioning for connectors (recommended)
resource "aws_s3_bucket_versioning" "connectors" {
  bucket = aws_s3_bucket.connectors.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access for connectors bucket
resource "aws_s3_bucket_public_access_block" "connectors" {
  bucket = aws_s3_bucket.connectors.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Static files bucket
resource "aws_s3_bucket" "static" {
  bucket = "${var.environment}-integration-app-static"

  tags = {
    Environment = var.environment
    Service     = "membrane"
    Purpose     = "static-files"
  }
}

# CORS configuration for static bucket
resource "aws_s3_bucket_cors_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
    expose_headers  = ["ETag"]
  }
}

# Block public access initially - CloudFront will access via OAC
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## CloudFront Distribution

CloudFront serves static files with CDN caching and HTTPS.

### ACM Certificate (for custom domain)

```hcl
# Certificate must be in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name (e.g., example.com)"
  type        = string
}

# Request certificate
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = "static.${var.environment}.${var.hosted_zone_name}"
  validation_method = "DNS"

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation
data "aws_route53_zone" "main" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```

### CloudFront Distribution Configuration

```hcl
# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "static" {
  name                              = "${var.environment}-static-oac"
  description                       = "OAC for static S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "static" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Membrane static files CDN"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"  # US, Canada, Europe

  aliases = ["static.${var.environment}.${var.hosted_zone_name}"]

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.static.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "S3-${aws_s3_bucket.static.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400   # 1 day
    max_ttl     = 31536000 # 1 year
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "static_cloudfront" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static.arn
          }
        }
      }
    ]
  })
}

# DNS record for CloudFront
resource "aws_route53_record" "static" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "static.${var.environment}.${var.hosted_zone_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static.domain_name
    zone_id                = aws_cloudfront_distribution.static.hosted_zone_id
    evaluate_target_health = false
  }
}

# Output the CloudFront URL
output "static_cdn_url" {
  value = "https://${aws_cloudfront_distribution.static.domain_name}"
  description = "CloudFront distribution URL for static files"
}

output "static_custom_domain_url" {
  value = "https://static.${var.environment}.${var.hosted_zone_name}"
  description = "Custom domain URL for static files (use for BASE_STATIC_URI)"
}
```

## Redis

### ElastiCache for Redis

**Important:** AWS ElastiCache Serverless for Redis is **NOT supported**. Use standard ElastiCache or cluster mode.

```hcl
# Subnet group for ElastiCache
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.environment}-membrane-redis"
  subnet_ids = var.private_subnet_ids  # Your VPC private subnets

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }
}

# Security group for Redis
resource "aws_security_group" "redis" {
  name_prefix = "${var.environment}-membrane-redis-"
  description = "Security group for Membrane Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from VPC"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }
}

# ElastiCache Redis cluster
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.environment}-membrane"
  replication_group_description = "Membrane Redis cluster"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = "cache.t3.medium"  # Adjust based on workload
  num_cache_clusters         = 2  # Primary + 1 replica
  parameter_group_name       = "default.redis7"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]

  # Automatic failover for multi-AZ
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Maintenance window
  maintenance_window = "sun:05:00-sun:06:00"

  # Snapshot configuration (optional - Redis data is ephemeral for Membrane)
  snapshot_retention_limit = 0

  # Enable encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token  # Strong password

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }
}

# Output Redis connection string
output "redis_connection_string" {
  value     = "rediss://:${var.redis_auth_token}@${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
  sensitive = true
  description = "Redis connection string (use for REDIS_URI)"
}
```

## IAM Configuration

Membrane containers support IAM role-based access to AWS services. This is the **recommended approach** instead of using access keys.

### ECS Task Role (for ECS deployments)

```hcl
# IAM role for ECS tasks
resource "aws_iam_role" "membrane_task" {
  name = "${var.environment}-membrane-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }
}

# S3 access policy
resource "aws_iam_role_policy" "membrane_s3" {
  name = "${var.environment}-membrane-s3-access"
  role = aws_iam_role.membrane_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.tmp.arn,
          "${aws_s3_bucket.tmp.arn}/*",
          aws_s3_bucket.connectors.arn,
          "${aws_s3_bucket.connectors.arn}/*",
          aws_s3_bucket.static.arn,
          "${aws_s3_bucket.static.arn}/*"
        ]
      }
    ]
  })
}

# Output role ARN
output "ecs_task_role_arn" {
  value       = aws_iam_role.membrane_task.arn
  description = "ECS task role ARN for Membrane services"
}
```

### EKS Service Account (for Kubernetes deployments)

```hcl
# OIDC provider for EKS (if not already created)
data "aws_eks_cluster" "main" {
  name = var.eks_cluster_name
}

data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Environment = var.environment
  }
}

# IAM role for Kubernetes service account
resource "aws_iam_role" "membrane_k8s" {
  name = "${var.environment}-membrane-k8s-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${var.k8s_namespace}:membrane-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Service     = "membrane"
  }
}

# Attach S3 policy
resource "aws_iam_role_policy" "membrane_k8s_s3" {
  name = "${var.environment}-membrane-k8s-s3-access"
  role = aws_iam_role.membrane_k8s.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.tmp.arn,
          "${aws_s3_bucket.tmp.arn}/*",
          aws_s3_bucket.connectors.arn,
          "${aws_s3_bucket.connectors.arn}/*",
          aws_s3_bucket.static.arn,
          "${aws_s3_bucket.static.arn}/*"
        ]
      }
    ]
  })
}

# Output for Kubernetes service account annotation
output "k8s_service_account_role_arn" {
  value       = aws_iam_role.membrane_k8s.arn
  description = "IAM role ARN to annotate Kubernetes service account"
}
```

### Using IAM Roles

When using IAM roles, **omit** these environment variables from your Membrane services:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

The containers will automatically use IAM role credentials.

## MongoDB

**AWS DocumentDB is NOT supported** due to MongoDB API compatibility issues.

**Recommended:** Use [MongoDB Atlas](index.md#mongodb-atlas-setup-terraform-example) (managed service) or self-host MongoDB on EC2.

## Environment Variables Summary

After provisioning AWS resources, configure these environment variables:

```bash
# Storage
STORAGE_PROVIDER=s3
AWS_REGION=us-east-1
TMP_STORAGE_BUCKET=prod-integration-app-tmp
CONNECTORS_STORAGE_BUCKET=prod-integration-app-connectors
STATIC_STORAGE_BUCKET=prod-integration-app-static
BASE_STATIC_URI=https://static.prod.example.com

# Redis
REDIS_URI=rediss://:your-auth-token@your-redis-endpoint:6379

# MongoDB (from Atlas)
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/membrane

# IAM (if using IAM roles, these are NOT needed)
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
```

## Next Steps

1. Verify all resources are provisioned correctly
2. Configure [Authentication](../authentication/auth0.md)
3. Proceed to [Deployment](../deployment/services.md)
