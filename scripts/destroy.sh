#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ("${1:-}" != "" && "$1" != "--apply") ]]; then
  printf 'Usage: bash scripts/destroy.sh [--apply]\n' >&2
  exit 2
fi

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID to the student subscription}"
: "${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP to the dedicated Quiz App group}"
: "${AZURE_ACR_NAME:?Set AZURE_ACR_NAME to the Quiz App registry name}"

group_id="$(az group show --name "$AZURE_RESOURCE_GROUP" --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query id -o tsv)"
test -n "$group_id"
inventory="$(az resource list --resource-group "$AZURE_RESOURCE_GROUP" --subscription "$AZURE_SUBSCRIPTION_ID" -o json)"
jq -e 'type == "array"' <<< "$inventory" >/dev/null
printf 'Target: %s\n' "$group_id"
jq -r '.[] | [.type, .name] | @tsv' <<< "$inventory"

unexpected="$(jq -r --arg acr "$AZURE_ACR_NAME" '
  .[] | (.type | ascii_downcase) + ":" + .name
  | select(. != ("microsoft.containerregistry/registries:" + $acr)
    and . != "microsoft.app/containerapps:backend"
    and . != "microsoft.app/containerapps:quiz-frontend"
    and . != "microsoft.app/managedenvironments:quiz-env-standard"
    and . != "microsoft.managedidentity/userassignedidentities:quiz-acr-pull"
    and . != "microsoft.managedidentity/userassignedidentities:quiz-github-deploy")
' <<< "$inventory")"
if [[ -n "$unexpected" ]]; then
  printf 'Unexpected resources. Group deletion blocked:\n%s\n' "$unexpected" >&2
  exit 1
fi

if [[ "${1:-}" != "--apply" ]]; then
  printf 'Preview. Run again with --apply to request deletion.\n'
  exit 0
fi

read -r -p 'Type the full resource group ID above to confirm: ' confirmation
if [[ "$confirmation" != "$group_id" ]]; then
  printf 'Confirmation does not match.\n' >&2
  exit 1
fi

current_inventory="$(az resource list --resource-group "$AZURE_RESOURCE_GROUP" --subscription "$AZURE_SUBSCRIPTION_ID" -o json)"
if [[ "$(jq -c 'map(.id) | sort' <<< "$current_inventory")" != "$(jq -c 'map(.id) | sort' <<< "$inventory")" ]]; then
  printf 'Resource inventory changed. Review it again before deleting.\n' >&2
  exit 1
fi

az group delete --name "$AZURE_RESOURCE_GROUP" --subscription "$AZURE_SUBSCRIPTION_ID" --yes
