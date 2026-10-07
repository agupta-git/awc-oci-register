# shellcheck shell=bash

auth_acr_resolve() {
  local registry_name
  registry_name="$(config_get '.auth.registryName')"
  command -v az >/dev/null 2>&1 || die "az CLI required for auth.kind acr"

  AUTH_USER="00000000-0000-0000-0000-000000000000"
  AUTH_PASSWORD="$(az acr login --name "$registry_name" --expose-token --output tsv --query accessToken 2>/dev/null)" \
    || die "az acr login --expose-token failed for registry $registry_name"
  [[ -n "$AUTH_PASSWORD" ]] || die "empty ACR access token for $registry_name"
}
