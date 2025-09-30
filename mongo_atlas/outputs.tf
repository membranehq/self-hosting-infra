output "mongo_uri" {
  description = "MongoDB URI"
  value       = "mongodb+srv://${mongodbatlas_database_user.integration_app.username}:${mongodbatlas_database_user.integration_app.password}@${replace(mongodbatlas_advanced_cluster.integration_app.connection_strings[0].standard_srv, "mongodb+srv://", "")}/engine-${var.environment}"
  sensitive   = true
}
