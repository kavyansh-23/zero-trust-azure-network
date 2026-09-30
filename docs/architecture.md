# Architecture

Hub-and-spoke network on Azure, defined entirely in Terraform. Everything is private by default: the only public IPs in the estate belong to Azure Firewall and Azure Bastion.

## Topology

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

**How to read it:** thick arrows are the only paths that cross the internet boundary, dashed arrows are routing and telemetry, and green/red/blue nodes are workloads, data and shared network services.

## Traffic flows

```mermaid
sequenceDiagram
  autonumber
  actor Eng as Engineer
  participant Bas as Azure Bastion (hub)
  participant VM as App VM (payments)
  participant DB as PostgreSQL (data subnet)
  participant FW as Azure Firewall (hub)
  participant Net as Internet

  Note over Eng,DB: Admin path: Bastion is the only way in
  Eng->>Bas: az network bastion ssh (HTTPS 443, Entra ID)
  Bas->>VM: SSH 22 over the private IP
  VM->>DB: psql on 5432 (NSG allows the app subnet only)
  DB-->>VM: query result

  Note over VM,Net: Egress path: forced through the firewall
  VM->>FW: 0.0.0.0/0 routed by the UDR
  FW-->>Net: allowed FQDNs only (for example *.ubuntu.com)
  FW--xVM: everything else denied and logged
```

## Address plan

| Network | CIDR | Subnets |
|---|---|---|
| Hub | `10.0.0.0/22` | `AzureFirewallSubnet` 10.0.0.0/26, `AzureBastionSubnet` 10.0.1.0/26 |
| Spoke: payments | `10.1.0.0/16` | `snet-app` 10.1.1.0/24, `snet-data` 10.1.2.0/24 (PostgreSQL, delegated) |
| Spoke: analytics | `10.2.0.0/16` | `snet-app` 10.2.1.0/24, `snet-data` 10.2.2.0/24 (delegated, no database deployed) |

Adding a spoke is one more entry in `spokes` in `envs/prod/prod.tfvars`.

## Zero-trust controls

| Control | Where | What it enforces |
|---|---|---|
| Single entry point | `modules/bastion` | The only public ingress is Bastion over 443; VMs and the database have no public IP |
| Explicit deny-all inbound | `modules/spoke-network` | A priority 4096 rule per subnet overrides the default `AllowVnetInBound`, so peered networks are not implicitly trusted |
| Least-privilege allow rules | `envs/prod/prod.tfvars` | App accepts SSH only from the Bastion subnet; data accepts 5432 only from the app subnet |
| Forced tunnelling | `modules/spoke-network` | `0.0.0.0/0` goes to the firewall; `default_outbound_access_enabled = false` removes implicit egress |
| Egress allow-list | `modules/firewall` | Firewall denies by default; only listed FQDNs pass; threat-intel mode `Deny` |
| Isolated data tier | `modules/postgres` | VNet-integrated PostgreSQL in a delegated subnet, `public_network_access_enabled = false`, private DNS zone |
| Spoke-to-spoke isolation | peering design | Spokes peer only with the hub, so cross-spoke traffic must pass the firewall |
| Guardrails | `modules/policy` | Azure Policy denies NIC public IPs, off-region deployments and public PostgreSQL, and audits subnets without an NSG |
| Visibility | `modules/monitoring` | Firewall and Bastion logs land in Log Analytics |

## Design decisions

- **Bastion Standard, not Basic:** native-client tunnelling (`az network bastion ssh`) and reach into peered VNets.
- **Delegated subnet instead of a private endpoint for PostgreSQL:** the server gets a private IP inside the data subnet, so the NSG on that subnet directly controls who can connect, and no public endpoint exists at all.
- **Firewall Standard with FQDN rules:** enough to demonstrate default-deny egress; Premium (TLS inspection, IDPS) is on the roadmap.
- **One NSG per subnet, generated from data:** rules live in `tfvars`, so a reviewer can read the whole security posture in one file.
- **Two-pass deployment for cost:** `enable_firewall` and `enable_bastion` switches let the network, VMs and database be built and tested before the hourly-billed services are added.

## CI/CD pipeline

```mermaid
flowchart LR
  push(["git push / pull request"]) --> fmt["terraform fmt<br/>+ validate"]
  fmt --> lint["tflint"]
  lint --> scan["checkov<br/>IaC security scan"]
  scan --> plan["terraform plan<br/>(OIDC to Azure)"]
  plan --> gate{"manual approval<br/>environment: production"}
  gate -->|"approved"| apply["terraform apply"]

  classDef always fill:#E8F7EE,stroke:#107C10,stroke-width:2px,color:#0B3D0B
  classDef gated fill:#FFF4E5,stroke:#D97706,stroke-width:2px,color:#5A3300
  class fmt,lint,scan always
  class plan,gate,apply gated
```

Green stages run on every push and pull request without cloud credentials. The orange stages need Azure OIDC credentials and run only when the repository variable `DEPLOY_ENABLED` is `true`.

## Known limitations

- Traffic inside one spoke (app to data) uses the VNet system route and is controlled by NSGs, not the firewall.
- The PostgreSQL delegated subnet skips the firewall route and outbound deny, to avoid breaking platform management traffic. Isolation there comes from delegation, no public endpoint and the inbound NSG.
- The Bastion subnet has no NSG yet (Azure requires a specific rule set).
- The database admin password is generated by Terraform and lives in encrypted remote state. Moving it to Key Vault is on the roadmap.
