# Create a cluster in existing project
resource "mongodbatlas_advanced_cluster" "integration_app" {
  project_id = var.project_id
  name       = var.cluster_name

  # Cluster configuration
  cluster_type = "REPLICASET"

  # MongoDB version
  mongo_db_major_version = var.mongodb_version

  # Backup configuration
  backup_enabled = var.cloud_backup_enabled

  # Replication specs for the cluster
  replication_specs {
    region_configs {
      electable_specs {
        instance_size = var.instance_size
        node_count    = var.num_nodes
      }
      analytics_specs {
        instance_size = var.instance_size
        node_count    = var.num_analytic_nodes
      }
      provider_name = var.provider_name
      region_name   = var.provider_region
      priority      = 7

      auto_scaling {
        disk_gb_enabled = var.auto_scaling_disk_enabled
        compute_enabled = var.auto_scaling_compute_enabled

        compute_scale_down_enabled = var.auto_scaling_compute_enabled
        compute_min_instance_size  = var.compute_min_instance_size != null ? var.compute_min_instance_size : var.instance_size
        compute_max_instance_size  = var.compute_max_instance_size != null ? var.compute_max_instance_size : "M30"
      }
    }
  }

  # Advanced configuration
  advanced_configuration {
    javascript_enabled                 = true
    minimum_enabled_tls_protocol       = "TLS1_2"
    no_table_scan                      = false
    oplog_size_mb                      = null
    oplog_min_retention_hours          = null
    transaction_lifetime_limit_seconds = null
  }
}

# Database user
resource "mongodbatlas_database_user" "integration_app" {
  username           = var.database_username
  password           = var.database_password
  project_id         = var.project_id
  auth_database_name = "admin"

  roles {
    role_name     = "readWriteAnyDatabase"
    database_name = "admin"
  }

  scopes {
    name = mongodbatlas_advanced_cluster.integration_app.name
    type = "CLUSTER"
  }
}

# IP Whitelist (Optional - only created if CIDR is provided)
# resource "mongodbatlas_project_ip_access_list" "integration_app" {
#   count = var.ip_whitelist_cidr != null && var.ip_whitelist_cidr != "" ? 1 : 0

#   project_id = var.project_id
#   cidr_block = var.ip_whitelist_cidr
#   comment    = "Allow access from ${var.environment} environment"
# }
