resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = var.cloud_image_datastore
  node_name    = var.proxmox_node

  source_raw {
    data      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOF
    file_name = "k8s-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_pool" "cluster_pool" {
  count   = var.resource_pool != "" ? 1 : 0
  pool_id = var.resource_pool
}
# Download Ubuntu cloud image to Proxmox
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.cloud_image_datastore
  node_name    = var.proxmox_node
  url          = var.ubuntu_image_url
  file_name    = "ubuntu-cloud.img"
}

# Master node
resource "proxmox_virtual_environment_vm" "master" {
  name      = "${var.cluster_name}-master"
  node_name = var.proxmox_node
  vm_id     = var.vm_id_base
  tags      = var.tags
  pool_id = var.resource_pool != "" ? proxmox_virtual_environment_pool.cluster_pool[0].pool_id : null


  agent {
    enabled = true
  }

  cpu {
    cores = var.master_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.master_memory
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    discard      = "on"
    ssd          = true
    size         = var.master_disk_size
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
    ip_config {
      ipv4 {
        address = var.use_dhcp ? "dhcp" : var.master_ip
        gateway = var.use_dhcp ? null : var.gateway
      }
    }

    user_account {
      username = var.ci_user
      keys     = [var.ssh_public_key]
      password = var.ci_password != "" ? var.ci_password : null
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {} # Needed for cloud-init console output

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
    ]
  }
}

# Worker nodes
resource "proxmox_virtual_environment_vm" "worker" {
  count = var.worker_count
  name      = "${var.cluster_name}-worker-${count.index + 1}"
  node_name = var.proxmox_node
  vm_id     = var.vm_id_base + count.index + 1
  tags      = var.tags
  pool_id = var.resource_pool != "" ? proxmox_virtual_environment_pool.cluster_pool[0].pool_id : null

  agent {
    enabled = true
  }

  cpu {
    cores = var.worker_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    discard      = "on"
    ssd          = true
    size         = var.worker_disk_size
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
    ip_config {
      ipv4 {
        address = var.use_dhcp ? "dhcp" : var.worker_ips[count.index]
        gateway = var.use_dhcp ? null : var.gateway
      }
    }

    user_account {
      username = var.ci_user
      keys     = [var.ssh_public_key]
      password = var.ci_password != "" ? var.ci_password : null
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
    ]
  }
}
