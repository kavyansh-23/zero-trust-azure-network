variable "subscription_id" { type = string }
variable "location" {
  type    = string
  default = "centralindia"
}
variable "project" {
  type    = string
  default = "ztnet"
}
variable "environment" {
  type    = string
  default = "prod"
}

variable "hub" {
  type = object({
    address_space          = list(string)
    firewall_subnet_prefix = string
    bastion_subnet_prefix  = string
  })
}

# Adding a spoke = adding one entry here. Subnets named "app" and "data" are used by the
# workload_vm and database modules when deploy_workload / deploy_database are true.
variable "spokes" {
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      address_prefix     = string
      delegation         = optional(string)
      route_via_firewall = optional(bool, true)
    }))
    nsg_rules = optional(map(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_address_prefix      = string
      destination_address_prefix = string
      destination_port_range     = string
    }))), {})
    deploy_workload = optional(bool, false)
    deploy_database = optional(bool, false)
  }))
}

variable "enable_firewall" {
  description = "Set false while iterating to save cost (no forced tunnelling, no egress for VMs)."
  type        = bool
  default     = true
}
variable "enable_bastion" {
  type    = bool
  default = true
}
variable "firewall_allowed_fqdns" {
  type    = list(string)
  default = ["*.ubuntu.com"]
}
variable "enforce_policies" {
  type    = bool
  default = true
}
variable "ssh_public_key" {
  type      = string
  sensitive = true
}
