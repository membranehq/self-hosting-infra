# VPC Network
resource "google_compute_network" "main" {
  name                    = "${local.service_name_prefix}-network"
  auto_create_subnetworks = false
}

# Subnet for Cloud Run services
resource "google_compute_subnetwork" "main" {
  name          = "${local.service_name_prefix}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true
}

# Reserve IP address range for VPC peering (for Redis)
resource "google_compute_global_address" "private_ip_range" {
  name          = "${local.service_name_prefix}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

# VPC peering for private services (Redis)
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.service_name_prefix}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# Firewall rule to allow health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${local.service_name_prefix}-allow-health-checks"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

# Firewall rule to allow Cloud Run services to access Redis
# Cloud Run services use VPC connector to access VPC-peered services
# This rule allows traffic from the VPC connector range to Redis
resource "google_compute_firewall" "allow_redis_access" {
  name    = "${local.service_name_prefix}-allow-redis"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  # Allow from VPC connector range (Cloud Run services use connector)
  source_ranges = [
    google_vpc_access_connector.main.ip_cidr_range
  ]
  target_tags   = []
  description    = "Allow Cloud Run services (via VPC connector) to access Redis via VPC peering"
  
  # Ensure this rule is created after VPC peering and connector are established
  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_vpc_access_connector.main
  ]
}

# Static IP addresses for Cloud NAT (for MongoDB Atlas whitelisting)
resource "google_compute_address" "nat_ip" {
  count   = 2
  name    = "${local.service_name_prefix}-nat-ip-${count.index + 1}"
  region  = var.region
  purpose = "NAT"
}

# Cloud NAT for outbound connectivity
resource "google_compute_router" "main" {
  name    = "${local.service_name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${local.service_name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = google_compute_router.main.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.nat_ip[*].self_link
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  # Exclude private IP ranges from NAT (Redis is in VPC peering range 10.103.0.0/16)
  # Cloud NAT automatically excludes RFC 1918 ranges, but being explicit helps
  enable_endpoint_independent_mapping = false

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# VPC Connector for Cloud Run (alternative approach)
resource "google_vpc_access_connector" "main" {
  name          = "${local.service_name_prefix}-connector"
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = "10.8.0.0/28"

  min_instances = 2
  max_instances = 3
}
