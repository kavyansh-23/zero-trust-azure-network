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

## Proofs
Recource Groups:-
<img width="940" height="361" alt="image" src="https://github.com/user-attachments/assets/f18b1ec6-499d-4abd-b9f5-8a441b4e54ac" />
Recources:-
<img width="940" height="326" alt="image" src="https://github.com/user-attachments/assets/3c66ff61-dc1a-43fe-a9a4-9a0bd0142afd" />
<img width="940" height="331" alt="image" src="https://github.com/user-attachments/assets/8cb7a546-5635-4878-bac7-a7d472d71c5b" />
<img width="940" height="185" alt="image" src="https://github.com/user-attachments/assets/727416e5-ac1a-4ba5-bff2-3c417a5a002a" />
Apply completed status:-
<img width="940" height="236" alt="image" src="https://github.com/user-attachments/assets/b2777b07-8440-48f7-9574-9d4ef6b2a852" />
Verifying Zero trust:-
<img width="940" height="60" alt="image" src="https://github.com/user-attachments/assets/840cee4e-2ddb-4802-adf1-b1320c18b7fd" />
Log analytics workspace:-
<img width="919" height="673" alt="image" src="https://github.com/user-attachments/assets/293ad6f2-fd79-42c5-8a4b-9f6e55107b74" />

