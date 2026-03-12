variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "test"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "integration-app"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "integration-app-rg"
}

variable "dns_zone_name" {
  description = "Azure DNS zone name used for the static Front Door custom domain and External-DNS domain filter."
  type        = string
  default     = "azure.int-membrane.com"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_namespace" {
  description = "K8S namespace"
  type        = string
}

variable "private_endpoint_subnet_cidr" {
  description = "CIDR block for private endpoints subnet. If not provided, will calculate dynamically."
  type        = string
  default     = null
}

variable "cors_allowed_origins" {
  description = "List of origins allowed to make cross-origin requests to the storage account (e.g. [\"https://ui.example.com\", \"https://console.example.com\"])."
  type        = list(string)
}

variable "external_dns_service_account_name" {
  description = "Name of the Kubernetes service account used by External-DNS. Must match the serviceAccount.name in the External-DNS Helm chart values."
  type        = string
  default     = "external-dns"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.32"
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_subnet_cidr" {
  description = "CIDR block for the node subnet. Must be within vnet_cidr and must not overlap with pod_cidr or service_cidr."
  type        = string
  default     = "10.0.0.0/22"
}

variable "pod_cidr" {
  description = "CIDR block for pod IPs (Azure CNI Overlay — must not overlap with vnet_cidr or service_cidr). WARNING: the default 192.168.0.0/16 is common in office/home networks; override if this conflicts with peered or on-premises network ranges."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes service IPs (must not overlap with vnet_cidr or pod_cidr)."
  type        = string
  default     = "172.16.0.0/16"
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool. Ephemeral OS disk size is limited by the VM's cache disk size (Standard_D2s_v5 = 75 GiB)."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_node_count" {
  description = "Fixed number of nodes in the system node pool."
  type        = number
  default     = 2
}

variable "user_node_vm_size" {
  description = "VM size for the user node pool. Ephemeral OS disk size is limited by the VM's cache disk size (Standard_D4s_v5 = 150 GiB)."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "user_node_min_count" {
  description = "Minimum number of nodes in the user node pool (auto-scaling)."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum number of nodes in the user node pool (auto-scaling)."
  type        = number
  default     = 10
}

variable "api_server_authorized_ip_ranges" {
  description = "List of CIDR blocks authorized to access the Kubernetes API server. Must contain at least one entry and must not include 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = length(var.api_server_authorized_ip_ranges) > 0
    error_message = "api_server_authorized_ip_ranges must not be empty. Specify at least one CIDR block."
  }

  validation {
    condition     = !contains(var.api_server_authorized_ip_ranges, "0.0.0.0/0")
    error_message = "api_server_authorized_ip_ranges must not contain 0.0.0.0/0. Specify explicit CIDRs for your office, VPN, and CI/CD egress IPs."
  }
}
