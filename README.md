# Zero-Trust Azure Network (Terraform)

Hub-and-spoke network on Azure built entirely from reusable Terraform modules. Workloads and databases have no public IPs, databases sit in an isolated delegated subnet, and **Azure Bastion is the only way in**. Egress is forced through Azure Firewall, guardrails are enforced by Azure Policy, and everything ships through a CI/CD pipeline with static analysis and a manual approval gate.

See [docs/architecture.md](docs/architecture.md) for the diagram and control matrix.

## What is in the repo

| Module | Purpose |
|---|---|
| `hub-network` | Hub VNet with `AzureFirewallSubnet` and `AzureBastionSubnet` |
| `firewall` | Azure Firewall Standard + policy (default deny, FQDN allow-list, DNS proxy, threat intel) + diagnostics |
| `bastion` | Bastion Standard with native-client tunnelling, shareable links off + diagnostics |
| `spoke-network` | Spoke VNet, per-subnet NSGs with deny-all inbound, forced-tunnel route table, hub peering |
| `workload-vm` | Ubuntu 24.04 VM, SSH key only, no public IP, managed identity |
| `postgres` | PostgreSQL Flexible Server, private access, private DNS zone, generated admin password |
| `monitoring` | Log Analytics workspace |
| `policy` | Subscription-scope Azure Policy assignments (built-in definitions) |

Scale lever: each spoke is one map entry in `envs/prod/prod.tfvars`. Add a spoke, get its VNet, NSGs, routes, peering, and optionally a VM and database.
