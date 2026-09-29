# No secrets here. Provide subscription_id and ssh_public_key via TF_VAR_* or secrets.auto.tfvars.

hub = {
  address_space          = ["10.0.0.0/22"]
  firewall_subnet_prefix = "10.0.0.0/26"
  bastion_subnet_prefix  = "10.0.1.0/26"
}

spokes = {
  payments = {
    address_space = ["10.1.0.0/16"]
    subnets = {
      app  = { address_prefix = "10.1.1.0/24" }
      data = { address_prefix = "10.1.2.0/24", delegation = "Microsoft.DBforPostgreSQL/flexibleServers", route_via_firewall = false }
    }
    nsg_rules = {
      app = [
        { name = "allow-bastion-ssh", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_address_prefix = "10.0.1.0/26", destination_address_prefix = "10.1.1.0/24", destination_port_range = "22" }
      ]
      data = [
        { name = "allow-app-postgres", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_address_prefix = "10.1.1.0/24", destination_address_prefix = "10.1.2.0/24", destination_port_range = "5432" }
      ]
    }
    deploy_workload = true
    deploy_database = true
  }

  analytics = {
    address_space = ["10.2.0.0/16"]
    subnets = {
      app  = { address_prefix = "10.2.1.0/24" }
      data = { address_prefix = "10.2.2.0/24", delegation = "Microsoft.DBforPostgreSQL/flexibleServers", route_via_firewall = false }
    }
    nsg_rules = {
      app = [
        { name = "allow-bastion-ssh", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_address_prefix = "10.0.1.0/26", destination_address_prefix = "10.2.1.0/24", destination_port_range = "22" }
      ]
    }
    deploy_workload = true
  }
}
