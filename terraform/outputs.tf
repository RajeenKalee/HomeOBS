output "master_ip" {
  description = "Master node IP address"
  value       = proxmox_virtual_environment_vm.master.ipv4_addresses[1][0]
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value = {
    for vm in proxmox_virtual_environment_vm.worker :
    vm.name => vm.ipv4_addresses[1][0]
  }
}

output "master_vm_id" {
  value = proxmox_virtual_environment_vm.master.vm_id
}

output "worker_vm_ids" {
  value = [for vm in proxmox_virtual_environment_vm.worker : vm.vm_id]
}

output "ssh_command_master" {
  description = "Quick SSH to master"
  value       = "ssh ${var.ci_user}@${proxmox_virtual_environment_vm.master.ipv4_addresses[1][0]}"
}