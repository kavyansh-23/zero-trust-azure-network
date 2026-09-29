#!/usr/bin/env bash
# Creates the remote-state storage account and writes envs/prod/backend.hcl.
# Usage: ./bootstrap/state-backend.sh [location]
set -euo pipefail

LOCATION="${1:-centralindia}"
RG="rg-ztnet-tfstate"
SA="stztnettf$(openssl rand -hex 4)"
CONTAINER="tfstate"

az group create -n "$RG" -l "$LOCATION" -o none
az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false -o none
az storage container create -n "$CONTAINER" --account-name "$SA" --auth-mode login -o none

# Your user needs data-plane access because the backend uses Entra ID auth, not account keys.
ME=$(az ad signed-in-user show --query id -o tsv)
SA_ID=$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)
az role assignment create --assignee "$ME" --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none

cat > "$(dirname "$0")/../envs/prod/backend.hcl" <<HCL
resource_group_name  = "$RG"
storage_account_name = "$SA"
container_name       = "$CONTAINER"
key                  = "ztnet-prod.tfstate"
use_azuread_auth     = true
HCL

echo "Wrote envs/prod/backend.hcl (storage account: $SA)"
