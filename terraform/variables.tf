# Proxmox connection
variable "proxmox_endpoint" {
  description = "Proxmox API URL (e.g. https://192.168.1.10:8006)"
  type        = string
}

variable "ssh_username" {
  description = "SSH user for Proxmox node access"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "API token ID (format: USER@REALM!TOKENNAME)"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "API token secret (UUID)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for self-signed certs"
  type        = bool
  default     = true
}

# Proxmox environment
variable "proxmox_node" {
  description = "Target Proxmox node name"
  type        = string
  default     = "pve"
}

variable "datastore_id" {
  description = "Storage pool for VM disks (e.g. local-lvm, ceph-pool)"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge for VM NICs"
  type        = string
  default     = "vmbr0"
}

variable "cloud_image_datastore" {
  description = "Storage for cloud-init image snippets"
  type        = string
  default     = "local"
}

variable "ubuntu_image_url" {
  description = "URL of the Ubuntu cloud image (qcow2)"
  type        = string
}

variable "resource_pool" {
  description = "Proxmox resource pool for grouping VMs"
  type        = string
  default     = ""
}

# SSH

variable "ssh_public_key" {
  description = "SSH public key for cloud-init user"
  type        = string
}

variable "ci_user" {
  description = "Default cloud-init user"
  type        = string
  default     = "ubuntu"
}

variable "ci_password" {
  description = "Optional cloud-init password (leave empty to rely on SSH keys)"
  type        = string
  default     = ""
  sensitive   = true
}

# Networking

variable "use_dhcp" {
  description = "Use DHCP for all VMs (if false, static IPs are required)"
  type        = bool
  default     = true
}

variable "gateway" {
  description = "Default gateway IP (only used when use_dhcp = false)"
  type        = string
  default     = ""
}

variable "master_ip" {
  description = "Static IP for master in CIDR (only used when use_dhcp = false)"
  type        = string
  default     = ""
}

variable "worker_ips" {
  description = "Static IPs for workers in CIDR (only used when use_dhcp = false)"
  type        = list(string)
  default     = []
}

# VM specs

variable "master_cores" {
  type    = number
  default = 4
}

variable "master_memory" {
  description = "Master RAM in MB"
  type        = number
  default     = 6144
}

variable "master_disk_size" {
  description = "Master disk size in GB"
  type        = number
  default     = 40
}

variable "worker_cores" {
  type    = number
  default = 4
}

variable "worker_memory" {
  description = "Worker RAM in MB"
  type        = number
  default     = 8192
}

variable "worker_disk_size" {
  description = "Worker disk size in GB"
  type        = number
  default     = 60
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

# Naming

variable "cluster_name" {
  description = "Prefix for VM names"
  type        = string
  default     = "k8s"
}

variable "vm_id_base" {
  description = "Starting VM ID (master = base, workers = base+1, base+2, …)"
  type        = number
  default     = 200
}

variable "tags" {
  description = "Tags to apply to all VMs"
  type        = list(string)
  default     = ["k8s", "terraform"]
}
