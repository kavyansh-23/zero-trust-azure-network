variable "subscription_id" { type = string }
variable "enforce" {
  type    = bool
  default = true
}
variable "policies" {
  description = "Map of short assignment name (max 24 chars) => built-in policy display name + optional parameters."
  type = map(object({
    display_name = string
    parameters   = optional(string)
  }))
}
