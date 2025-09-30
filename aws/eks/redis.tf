resource "aws_elasticache_parameter_group" "main" {
  family = "redis7"
  name   = "${var.environment}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Service = "redis"
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.environment}-redis"
  description                = "Redis cluster for Integration.app"
  node_type                  = var.redis_node_type
  port                       = 6379
  engine_version             = "7.0"
  parameter_group_name       = aws_elasticache_parameter_group.main.name
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = false
  num_cache_clusters         = 1

  tags = {
    Service = "api"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Service = "redis"
  }
}
