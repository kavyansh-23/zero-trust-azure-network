variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "spoke_address_spaces" { type = list(string) }
variable "allowed_fqdns" {
  type    = list(string)
  default = ["*.ubuntu.com"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
