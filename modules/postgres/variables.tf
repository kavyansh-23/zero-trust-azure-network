variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "vnet_id" { type = string }
variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}
variable "tags" {
  type    = map(string)
  default = {}
}
