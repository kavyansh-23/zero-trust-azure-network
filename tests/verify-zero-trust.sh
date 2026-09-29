#!/usr/bin/env bash
# Post-deploy assertions. Exit non-zero if any zero-trust invariant is broken.
# Usage: ./tests/verify-zero-trust.sh   (run after terraform apply, logged in with az)
set -uo pipefail
PREFIX="${1:-ztnet-prod}"
fail=0
check() { if [ "$2" = "true" ]; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }

# 1. Only the firewall and Bastion own public IPs.
mapfile -t PIPS < <(az network public-ip list --query "[?contains(name,'$PREFIX')].name" -o tsv)
bad=$(printf '%s\n' "${PIPS[@]}" | grep -vE 'fw|bastion' || true)
check "public IPs exist only for firewall + bastion (${PIPS[*]})" "$([ -z "$bad" ] && echo true || echo false)"

# 2. No NIC has a public IP.
nic_pips=$(az network nic list --query "[?contains(name,'$PREFIX')].ipConfigurations[].publicIPAddress.id" -o tsv)
check "no NIC carries a public IP" "$([ -z "$nic_pips" ] && echo true || echo false)"

# 3. Every spoke subnet has an NSG.
missing=$(az network vnet list --query "[?contains(name,'$PREFIX') && !contains(name,'hub')].subnets[?networkSecurityGroup==null].name" -o tsv)
check "every spoke subnet has an NSG" "$([ -z "$missing" ] && echo true || echo false)"

# 4. Every PostgreSQL flexible server has public access disabled.
open=$(az postgres flexible-server list --query "[?network.publicNetworkAccess!='Disabled'].name" -o tsv)
check "PostgreSQL public network access is Disabled" "$([ -z "$open" ] && echo true || echo false)"

# 5. Spoke route tables send 0.0.0.0/0 to a virtual appliance.
rt=$(az network route-table list --query "[?contains(name,'$PREFIX')].routes[?addressPrefix=='0.0.0.0/0' && nextHopType!='VirtualAppliance'].name" -o tsv)
check "default routes point at the firewall" "$([ -z "$rt" ] && echo true || echo false)"

exit $fail
