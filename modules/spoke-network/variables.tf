variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "address_space" { type = list(string) }

variable "subnets" {
  type = map(object({
    address_prefix     = string
    delegation         = optional(string)
    route_via_firewall = optional(bool, true)
  }))
}

variable "nsg_rules" {
  type = map(list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_address_prefix      = string
    destination_address_prefix = string
    destination_port_range     = string
  })))
  default = {}
}

variable "hub_vnet_id" { type = string }
variable "hub_vnet_name" { type = string }
variable "hub_resource_group_name" { type = string }

variable "route_via_firewall_enabled" {
  type    = bool
  default = true
}
variable "firewall_private_ip" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
