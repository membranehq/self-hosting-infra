output "nat_gateway_public_ips" {
  value       = aws_eip.nat[*].public_ip
  description = "Public IP addresses of NAT Gateways - use these for MongoDB Atlas whitelist"
}

output "nat_gateway_allocation_ids" {
  value       = aws_eip.nat[*].id
  description = "Allocation IDs of the Elastic IPs for NAT Gateways"
}
output "primary_endpoint_address" {
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
  description = "primary_endpoint_address"
}

output "redis_cluster_member_nodes" {
  value       = aws_elasticache_replication_group.redis.member_clusters
  description = "List of Redis cluster member node IDs"
}

output "redis_cluster_nodes" {
  value       = aws_elasticache_replication_group.redis.member_clusters
  description = "List of Redis cluster node addresses"
}
