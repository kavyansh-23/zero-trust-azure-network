#!/usr/bin/env bash
# Open an SSH session to a spoke VM through Azure Bastion (the only way in).
# Usage: ./scripts/connect.sh payments [~/.ssh/id_ed25519]
set -euo pipefail
SPOKE="${1:?spoke name, e.g. payments}"
KEY="${2:-$HOME/.ssh/id_ed25519}"

cd "$(dirname "$0")/../envs/prod"
BASTION=$(terraform output -raw bastion_name)
RG=$(terraform output -raw hub_resource_group)
VM_ID=$(terraform output -json vm_ids | jq -r --arg s "$SPOKE" '.[$s]')

az network bastion ssh --name "$BASTION" --resource-group "$RG" \
  --target-resource-id "$VM_ID" --auth-type ssh-key --username azureuser --ssh-key "$KEY"
