terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = ">= 2.0.0"
    }
  }
}

provider "onepassword" {
}

locals {
  op_ref_pattern = "^op://([^/]+)/([^/]+)/([^/]+)$"

  proxmox_token_inputs = {
    id     = var.proxmox_api_token_id
    secret = nonsensitive(var.proxmox_api_token_secret)
  }

  proxmox_token_refs = {
    for k, v in local.proxmox_token_inputs : k => regex(local.op_ref_pattern, v)
    if can(regex(local.op_ref_pattern, v))
  }
}

data "onepassword_item" "proxmox_token" {
  for_each = local.proxmox_token_refs
  vault    = each.value[0]
  title    = each.value[1]
}

locals {
  proxmox_token = {
    for k, v in local.proxmox_token_inputs : k => (
      contains(keys(local.proxmox_token_refs), k)
      ? data.onepassword_item.proxmox_token[k][local.proxmox_token_refs[k][2]]
      : v
    )
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = sensitive("${local.proxmox_token.id}=${local.proxmox_token.secret}")
  insecure  = var.proxmox_insecure

  ssh {
    agent    = true
    username = var.ssh_username
  }
}
