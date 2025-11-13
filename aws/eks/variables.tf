variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "membrane"
}

variable "cost_center" {
  description = "Cost center for billing and cost allocation (optional)"
  type        = string
  default     = "membrane-eks"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to deploy resources into"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
}

variable "hosted_zone_name" {
  description = "Hosted zone name (e.g., example.com)"
  type        = string
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_admin_users" {
  description = "List of IAM users to grant EKS admin access"
  type        = list(string)
  default     = []
}

variable "node_group_instance_types" {
  description = "List of instance types for EKS managed node group"
  type        = list(string)
  default     = ["t3.xlarge"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the EKS managed node group"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the EKS managed node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the EKS managed node group"
  type        = number
  default     = 10
}

variable "node_group_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 100
}

variable "node_group_capacity_type" {
  description = "Capacity type for the node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks allowed to access the EKS cluster endpoint publicly"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "vpc_cni_addon_version" {
  description = "VPC CNI addon version"
  type        = string
  default     = null  # Uses latest compatible version
}

variable "kube_proxy_addon_version" {
  description = "Kube-proxy addon version"
  type        = string
  default     = null  # Uses latest compatible version
}

variable "coredns_addon_version" {
  description = "CoreDNS addon version"
  type        = string
  default     = null  # Uses latest compatible version
}

variable "ebs_csi_addon_version" {
  description = "EBS CSI driver addon version"
  type        = string
  default     = null  # Uses latest compatible version
}
