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

## Deploy

```bash
az login && az account set --subscription <id>
./bootstrap/state-backend.sh                # remote state, writes envs/prod/backend.hcl

cd envs/prod
cat > secrets.auto.tfvars <<VARS
subscription_id = "<subscription-guid>"
ssh_public_key  = "$(cat ~/.ssh/id_ed25519.pub)"
VARS

terraform fmt -recursive ../..
terraform init -backend-config=backend.hcl
terraform validate
terraform plan  -var-file=prod.tfvars -out=tfplan
terraform apply tfplan
```

Then prove it works:

```bash
./scripts/connect.sh payments               # SSH through Bastion
# inside the VM:
psql "host=<database_fqdn> dbname=appdb user=pgadmin sslmode=require"
./tests/verify-zero-trust.sh                # from your laptop: asserts the invariants
```

## Cost and teardown

Azure Firewall and Bastion Standard bill hourly while they exist, so they dominate the bill. Deploy, capture your evidence, then `terraform destroy` the same day. While iterating on the network only, set `enable_firewall = false` and/or `enable_bastion = false`. Check current prices in the Azure pricing calculator before you deploy.

## CI/CD setup

1. Create an Entra app registration with a federated credential for this repo (GitHub OIDC), give it `Contributor` and `Resource Policy Contributor` on the subscription, plus `Storage Blob Data Contributor` on the state account.
2. Repo secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `SSH_PUBLIC_KEY`. Repo variables: `TFSTATE_RG`, `TFSTATE_SA`.
3. Create a GitHub environment named `production` with required reviewers; that is the apply gate.

Pipeline: `fmt` -> `validate` -> `tflint` -> `checkov` -> `plan` on every PR; `apply` on merge to `main` after approval.

## Evidence checklist (this is your proof)

Capture these during one live deployment and commit them under `docs/evidence/`:

- [ ] Green GitHub Actions run (static checks, plan, gated apply)
- [ ] `terraform apply` summary and `terraform state list`
- [ ] Network Watcher topology screenshot showing hub + 2 spokes
- [ ] Bastion SSH session into the payments VM, then `psql` connecting to the database
- [ ] Negative tests: connecting to the DB FQDN from your laptop fails; VM has no public IP; `az postgres flexible-server show` reports public access Disabled
- [ ] Output of `tests/verify-zero-trust.sh`
- [ ] Firewall log query (`AZFWApplicationRule`) showing an allowed and a denied FQDN
- [ ] Azure Policy compliance screenshot; a deployment of a public-IP NIC being denied
- [ ] Cost screenshot and `terraform destroy` output

## Roadmap (not built yet: do not claim on a resume until done)

Key Vault with private endpoint for secrets, Private Endpoints + Private DNS for Storage/Key Vault, VNet flow logs + Traffic Analytics, Sentinel analytics rules, Firewall Premium (IDPS/TLS inspection), second-region hub with global peering, `terraform test` / Terratest suite, Infracost in PRs.

## Status

Written without access to Azure or the Terraform registry, so it has not been through `terraform validate` yet. Run `terraform fmt -recursive`, `init`, and `validate` first and fix anything that surfaces. Verify the four Azure Policy display names in `envs/prod/main.tf` resolve in your tenant, and pick a region where PostgreSQL Flexible Server B-series and your subscription's region policy allow deployment.
