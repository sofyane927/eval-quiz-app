#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_ACR_NAME:?Set AZURE_ACR_NAME to the Azure registry name}"
: "${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP to the Container Apps resource group}"

if [[ -n "$(git status --porcelain)" ]]; then
  printf 'Commit or remove local changes before deploying.\n' >&2
  exit 1
fi

tag="$(git rev-parse HEAD)"
registry="$(az acr show --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" \
  --query loginServer -o tsv)"
test -n "$registry"
backend_image="$registry/quiz-backend:$tag"
frontend_image="$registry/quiz-frontend:$tag"

for app in backend quiz-frontend; do
  mode="$(az containerapp show --name "$app" --resource-group "$AZURE_RESOURCE_GROUP" \
    --query properties.configuration.activeRevisionsMode -o tsv)"
  if [[ "$mode" != Single ]]; then
    printf '%s must use single-revision mode for the ready revision to receive traffic.\n' "$app" >&2
    exit 1
  fi
done

docker build --platform linux/amd64 --tag "$backend_image" ./backend
docker build --platform linux/amd64 --tag "$frontend_image" .
bash scripts/scan-image.sh "$backend_image"
bash scripts/scan-image.sh "$frontend_image"

if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
  main_ref="$(git ls-remote --exit-code origin refs/heads/main)"
  if [[ "${main_ref%%$'\t'*}" != "$tag" ]]; then
    printf 'A newer commit is on main. Skipping deployment of %s.\n' "$tag"
    exit 0
  fi
fi

az acr login --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP"
docker push "$backend_image"
docker push "$frontend_image"

deploy_image() {
  local app="$1" image="$2" digest revision ready attempt
  digest="$(docker buildx imagetools inspect "$image" --format '{{.Manifest.Digest}}')"
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]
  image="${image%:*}@$digest"
  revision="$(az containerapp update --name "$app" --resource-group "$AZURE_RESOURCE_GROUP" \
    --image "$image" --query properties.latestRevisionName -o tsv)"
  test -n "$revision"
  for attempt in {1..24}; do
    ready="$(az containerapp show --name "$app" --resource-group "$AZURE_RESOURCE_GROUP" \
      --query properties.latestReadyRevisionName -o tsv)"
    if [[ "$ready" == "$revision" ]]; then
      printf '%s ready at %s (%s)\n' "$app" "$revision" "$image"
      return 0
    fi
    sleep 5
  done
  printf 'Revision %s of %s did not become ready.\n' "$revision" "$app" >&2
  return 1
}

deploy_image backend "$backend_image"
deploy_image quiz-frontend "$frontend_image"

frontend_host="$(az containerapp show --name quiz-frontend --resource-group "$AZURE_RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn -o tsv)"
test -n "$frontend_host"
curl --fail --silent --show-error --retry 8 --retry-all-errors --retry-delay 5 --max-time 20 \
  "https://$frontend_host/health" | jq -e '.status == "ok"'
printf 'Quiz App is responding at https://%s\n' "$frontend_host"
