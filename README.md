# Zero-Trust Azure Network (Terraform)

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.9-7B42BC?logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-hub--and--spoke-0078D4?logo=microsoftazure&logoColor=white)
![azurerm](https://img.shields.io/badge/azurerm-4.x-0078D4)

A hub-and-spoke network on Azure built entirely from reusable Terraform modules. Workloads and databases have no public IPs, the database sits in an isolated delegated subnet, and **Azure Bastion is the only way in**. Egress is forced through Azure Firewall and guardrails are enforced by Azure Policy.

Deployed to a live Azure subscription, verified with an automated test script, and torn down with `terraform destroy`.

## Architecture

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontFamily": "Segoe UI, Inter, sans-serif", "lineColor": "#5B6B7B", "primaryTextColor": "#0B2E4F"}}}%%
flowchart TB
  eng(["👤 Engineer<br/>Entra ID + RBAC"])
  net(("🌐 Internet"))

  subgraph hub["🏢 HUB VNet · 10.0.0.0/22"]
    direction LR
    bas["🔐 Azure Bastion<br/>Standard · 10.0.1.0/26<br/>the only way in"]
    fw["🔥 Azure Firewall + Policy<br/>default deny · FQDN allow-list<br/>10.0.0.0/26"]
    law[("📊 Log Analytics<br/>firewall + Bastion logs")]
  end

  subgraph pay["💳 SPOKE payments · 10.1.0.0/16"]
    direction TB
    payapp["🖥️ snet-app · 10.1.1.0/24<br/>Linux VM · no public IP<br/>NSG: SSH from Bastion only"]
    paydb[("🗄️ snet-data · 10.1.2.0/24<br/>PostgreSQL Flexible Server<br/>delegated · no public endpoint<br/>NSG: 5432 from app only")]
  end

  subgraph ana["📈 SPOKE analytics · 10.2.0.0/16"]
    direction TB
    anaapp["🖥️ snet-app · 10.2.1.0/24<br/>Linux VM · no public IP<br/>NSG: SSH from Bastion only"]
    anadata["🗄️ snet-data · 10.2.2.0/24<br/>delegated · reserved"]
  end

  subgraph gov["🛡️ GOVERNANCE · Azure Policy at subscription scope"]
    direction LR
    p1["Deny NIC<br/>public IPs"]
    p2["Allowed<br/>locations"]
    p3["Deny public<br/>PostgreSQL"]
    p4["Audit subnets<br/>without NSG"]
  end

  eng ==>|"HTTPS 443"| bas
  bas -->|"SSH 22 via peering"| payapp
  bas -->|"SSH 22 via peering"| anaapp
  payapp -->|"TCP 5432"| paydb
  payapp -.->|"0.0.0.0/0 via UDR"| fw
  anaapp -.->|"0.0.0.0/0 via UDR"| fw
  fw ==>|"allow-listed FQDNs only"| net
  fw -.->|"diagnostics"| law
  bas -.->|"diagnostics"| law
  pay ~~~ gov
  ana ~~~ gov

  classDef entry fill:#FFF4E5,stroke:#D97706,stroke-width:2px,color:#5A3300
  classDef edge fill:#EAF2FF,stroke:#0078D4,stroke-width:2px,color:#0B2E4F
  classDef workload fill:#E8F7EE,stroke:#107C10,stroke-width:2px,color:#0B3D0B
  classDef data fill:#FDECEC,stroke:#C42B1C,stroke-width:2px,color:#5A0E08
  classDef ops fill:#F3F4F6,stroke:#6B7280,stroke-width:1.5px,color:#111827
  classDef policy fill:#F5EEFF,stroke:#7C3AED,stroke-width:1.5px,color:#2E1065
  class eng,net entry
  class bas,fw edge
  class payapp,anaapp workload
  class paydb,anadata data
  class law ops
  class p1,p2,p3,p4 policy
  style hub fill:#F5F9FF,stroke:#0078D4,stroke-width:2px,stroke-dasharray: 6 4
  style pay fill:#F6FBF7,stroke:#107C10,stroke-width:2px,stroke-dasharray: 6 4
  style ana fill:#F6FBF7,stroke:#107C10,stroke-width:2px,stroke-dasharray: 6 4
  style gov fill:#FAF7FF,stroke:#7C3AED,stroke-width:1.5px,stroke-dasharray: 3 3
```

More detail (traffic flows, address plan, design decisions, limitations): [docs/architecture.md](docs/architecture.md).

## Highlights

- **8 reusable modules** and **2 spokes**; adding a spoke is one map entry in `prod.tfvars`.
- **2 public IPs in the whole estate** (Firewall and Bastion). VMs and PostgreSQL have none.
- **Default-deny everywhere:** deny-all inbound NSG on every subnet, default-deny firewall egress, forced tunnelling via route tables.
- **4 Azure Policy guardrails** at subscription scope.
- **Self-checking:** `tests/verify-zero-trust.sh` asserts the zero-trust invariants against the live deployment.
- **Cost-aware:** firewall and Bastion can be switched off while iterating.

## What is in the repo

| Module | Purpose |
|---|---|
| `hub-network` | Hub VNet with `AzureFirewallSubnet` and `AzureBastionSubnet` |
| `firewall` | Azure Firewall Standard + policy (default deny, FQDN allow-list, DNS proxy, threat intel) + diagnostics |
| `bastion` | Bastion Standard with native-client tunnelling, shareable links off, diagnostics |
| `spoke-network` | Spoke VNet, per-subnet NSGs with deny-all inbound, forced-tunnel route table, hub peering |
| `workload-vm` | Ubuntu 24.04 VM, SSH key only, no public IP, managed identity |
| `postgres` | PostgreSQL Flexible Server, private access, private DNS zone, generated admin password |
| `monitoring` | Log Analytics workspace |
| `policy` | Subscription-scope Azure Policy assignments (built-in definitions) |

```
.
├── modules/            # the 8 reusable modules above
├── envs/prod/          # root module: wiring, variables, prod.tfvars
├── bootstrap/          # creates the remote-state storage account
├── scripts/connect.sh  # SSH to a spoke VM through Bastion
├── tests/verify-zero-trust.sh
├── docs/architecture.md
└── .github/workflows/terraform.yml
```

## Getting started

Prerequisites: Terraform 1.9 or newer, Azure CLI, `jq`, an Azure subscription, an SSH key (`ssh-keygen -t ed25519`).

```bash
az login
./bootstrap/state-backend.sh                 # remote state, writes envs/prod/backend.hcl

cd envs/prod
cat > secrets.auto.tfvars <<VARS
subscription_id = "<subscription-guid>"
ssh_public_key  = "$(cat ~/.ssh/id_ed25519.pub)"
VARS

terraform init -backend-config=backend.hcl
terraform plan  -var-file=prod.tfvars -out=tfplan
terraform apply tfplan
```

Then connect and verify:

```bash
./scripts/connect.sh payments                # SSH through Bastion (the only way in)
./tests/verify-zero-trust.sh                 # asserts the zero-trust invariants
```

### Cost and teardown

Azure Firewall and Bastion Standard bill hourly and dominate the cost. Deploy in two passes: first with `-var enable_firewall=false -var enable_bastion=false` to build and test everything else cheaply, then add them. Always tear down with `terraform destroy -var-file=prod.tfvars`, not from the portal, so state and the subscription-level policy assignments are cleaned up together.

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

## CI/CD

`.github/workflows/terraform.yml` runs `terraform fmt`, `validate`, `tflint` and `checkov` on every push and pull request. The `plan` and `apply` jobs authenticate to Azure with OIDC (no stored secrets), and `apply` waits for manual approval on the `production` environment. Those two jobs are gated behind the repository variable `DEPLOY_ENABLED`, because a deployment costs money; the deployment shown above was run manually from the command line.

## Lessons learned

- **State backend permissions lag.** A new role assignment on the state storage account took several minutes to work, and `init` failed with a 403 until it did.
- **A network drop mid-apply leaves orphans.** Resources were created in Azure but never saved to state; recovered with `terraform import` and a re-apply.
- **Never delete from the portal.** It desynchronises state, and subscription-scope policy assignments survive a resource group deletion. Use `terraform destroy`.

## Limitations and roadmap

Known limitations are listed in [docs/architecture.md](docs/architecture.md#known-limitations). Not built yet: Key Vault with a private endpoint for secrets, VNet flow logs with Traffic Analytics, Sentinel analytics rules, Firewall Premium, a second-region hub, a `terraform test` suite and Infracost in pull requests.

