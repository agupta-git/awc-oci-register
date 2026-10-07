# shellcheck shell=bash
# Load and validate team YAML config (via yq -> JSON).

CONFIG_JSON=""

config_load() {
  local file="$1"
  shift || true

  [[ -f "$file" ]] || die "config not found: $file"

  require_cmds yq jq
  CONFIG_JSON="$(yq eval -o=json '.' "$file")"

  local kv key val jq_expr
  while (($# > 0)); do
    kv="$1"
    shift
    [[ -n "$kv" ]] || continue
    key="${kv%%=*}"
    val="${kv#*=}"
    [[ "$key" != "$kv" ]] || die "invalid --set (expected key=value): $kv"
    jq_expr=".$key = \$v"
    CONFIG_JSON="$(echo "$CONFIG_JSON" | jq --arg v "$val" "$jq_expr")" \
      || die "failed to apply --set $key"
  done

  config_apply_defaults
  config_validate
  config_export_shell
}

config_get() {
  local jq_path="$1"
  echo "$CONFIG_JSON" | jq -r "$jq_path"
}

config_apply_defaults() {
  local mp host
  mp="$(config_get '.marketplacePrefix // empty')"
  host="$(config_get '.registryHost // empty')"
  if [[ -z "$host" && -n "$mp" ]]; then
    host="${mp%%/*}"
    CONFIG_JSON="$(echo "$CONFIG_JSON" | jq --arg h "$host" '.registryHost = $h')"
  fi

  CONFIG_JSON="$(echo "$CONFIG_JSON" | jq '
    .awc //= {} |
    .awc.pullSecret //= {} |
    .awc.pullSecret.name //= "awc-console-registry-creds" |
    .awc.pullSecret.namespaces //= ["auth-config-operator-system", "awc-core"] |
    .awc.marketplace //= {} |
    .awc.marketplace.secret //= "awc-taikun-secrets" |
    .awc.marketplace.namespace //= "awc-core" |
    .awc.marketplace.dataKey //= "MARKETPLACE_REGISTRIES" |
    .awc.marketplace.consoleDeployment //= "awc-console" |
    .awc.kubeconfig //= "" |
    .behavior //= {} |
    .behavior.restartConsole //= true |
    .behavior.skipIfPrefixPresent //= true
  ')"
}

config_validate() {
  local mp kind
  mp="$(config_get '.marketplacePrefix // empty')"
  [[ -n "$mp" ]] || die "marketplacePrefix is required"
  [[ "$mp" == */* ]] || die "marketplacePrefix must include host and path (e.g. registry.example.com/org/awc)"

  kind="$(config_get '.auth.kind // empty')"
  [[ -n "$kind" ]] || die "auth.kind is required"

  case "$kind" in
    gcpServiceAccountKey)
      [[ -n "$(config_get '.auth.keyFile // empty')" ]] || die "auth.keyFile is required for gcpServiceAccountKey"
      ;;
    basic)
      [[ -n "$(config_get '.auth.username // empty')" ]] || die "auth.username is required for basic"
      [[ -n "$(config_get '.auth.passwordFile // empty')" ]] || die "auth.passwordFile is required for basic"
      ;;
    ecr)
      [[ -n "$(config_get '.auth.region // empty')" ]] || die "auth.region is required for ecr"
      ;;
    acr)
      [[ -n "$(config_get '.auth.registryName // empty')" ]] || die "auth.registryName is required for acr"
      ;;
    *)
      die "unsupported auth.kind: $kind (use gcpServiceAccountKey, basic, ecr, or acr)"
      ;;
  esac

  local host
  host="$(config_get '.registryHost // empty')"
  [[ -n "$host" ]] || die "registryHost could not be derived; set registryHost explicitly"
  [[ "$host" != *"/"* ]] || die "registryHost must be hostname only (no path): $host"
}

config_export_shell() {
  MARKETPLACE_PREFIX="$(config_get '.marketplacePrefix')"
  REGISTRY_HOST="$(config_get '.registryHost')"
  AUTH_KIND="$(config_get '.auth.kind')"

  AWC_KUBECONFIG="$(config_get '.awc.kubeconfig')"
  if [[ -z "$AWC_KUBECONFIG" ]]; then
    AWC_KUBECONFIG="${KUBECONFIG:-}"
  fi

  PULL_SECRET_NAME="$(config_get '.awc.pullSecret.name')"
  PULL_SECRET_NAMESPACES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && PULL_SECRET_NAMESPACES+=("$line")
  done < <(echo "$CONFIG_JSON" | jq -r '.awc.pullSecret.namespaces[]')

  MARKETPLACE_SECRET="$(config_get '.awc.marketplace.secret')"
  MARKETPLACE_NAMESPACE="$(config_get '.awc.marketplace.namespace')"
  MARKETPLACE_DATA_KEY="$(config_get '.awc.marketplace.dataKey')"
  CONSOLE_DEPLOYMENT="$(config_get '.awc.marketplace.consoleDeployment')"

  BEHAVIOR_RESTART_CONSOLE="$(config_get '.behavior.restartConsole')"
  BEHAVIOR_SKIP_IF_PREFIX_PRESENT="$(config_get '.behavior.skipIfPrefixPresent')"
}
