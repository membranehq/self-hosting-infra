output "nat_gateway_public_ips" {
  value       = aws_eip.nat[*].public_ip
  description = "Public IP addresses of NAT Gateways - use these for MongoDB Atlas whitelist"
}

output "nat_gateway_allocation_ids" {
  value       = aws_eip.nat[*].id
  description = "Allocation IDs of the Elastic IPs for NAT Gateways"
}

output "redis_primary_endpoint" {
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  description = "Redis primary endpoint address"
}

output "redis_port" {
  value       = aws_elasticache_replication_group.main.port
  description = "Redis port"
}

output "docdb_endpoint" {
  value       = var.enable_managed_database ? aws_docdb_cluster.main[0].endpoint : null
  description = "DocumentDB cluster endpoint"
}

output "docdb_reader_endpoint" {
  value       = var.enable_managed_database ? aws_docdb_cluster.main[0].reader_endpoint : null
  description = "DocumentDB cluster reader endpoint"
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "Bastion host instance ID - use with SSM Session Manager"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Bastion host public IP address"
}
