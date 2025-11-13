############################################
# Private-only subnet group
############################################
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Service     = "redis"
    Environment = var.environment
  }
}

############################################
# Replication group — CLUSTER MODE ENABLED
############################################
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.environment}-redis-new"
  description          = "Redis (cluster mode enabled) for Integration.app"

  engine         = "redis"
  engine_version = var.redis_engine_version # e.g. "7.1.0"
  node_type      = var.redis_node_type      # e.g. "cache.t3.micro"
  port           = 6380

  num_node_groups         = var.redis_shards             # shards
  replicas_per_node_group = var.redis_replicas_per_shard # replicas per shard
  automatic_failover_enabled = true
  multi_az_enabled = true  # Enable Multi-AZ

  # Encryption configuration
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  parameter_group_name = "default.redis7.cluster.on"
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  auto_minor_version_upgrade = true
  maintenance_window         = "sun:02:00-sun:03:00" # UTC off-peak
  snapshot_retention_limit   = 7
  snapshot_window            = "04:00-05:00" # UTC off-peak
  apply_immediately          = false

  tags = {
    Service     = "redis"
    Environment = var.environment
  }
}

############################################
# Variables (tune as needed)
############################################
variable "redis_engine_version" {
  type        = string
  default     = "7.1"
  description = "Keep consistent across environments."
}

variable "redis_shards" {
  type    = number
  default = 2 # total shards
}

variable "redis_replicas_per_shard" {
  type    = number
  default = 1 # 1 replica => 2 nodes per shard
}
