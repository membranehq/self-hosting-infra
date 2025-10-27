variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "integration-app"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "EKS cluster VPC id"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_ids" {
  description = "EKS cluster public subnet ids"
  type        = set(string)
}

variable "private_subnet_ids" {
  description = "EKS cluster private subnet ids"
  type        = set(string)
}

variable "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = "Z09418161W0GPSHMRJNF0"
}

variable "hosted_zone_name" {
  description = "Hosted zone name"
  type        = string
  default     = "int-membrane.com"
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster to grant access to"
  type        = string
}

variable "eks_admin_users" {
  description = "List of IAM users to grant EKS admin access"
  type        = list(string)
}

variable "public_subnet_cidr_blocks" {
  description = "List of IAM users to grant EKS admin access"
  type        = list(string)
}
