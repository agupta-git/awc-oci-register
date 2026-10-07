# shellcheck shell=bash
# Load and validate team YAML config (via yq -> JSON).

CONFIG_JSON=""
DEFAULTS_FILE="${AWC_OCI_REGISTER_ROOT}/config/defaults.yaml"

config_load() {
  local file="$1"
  shift || true

  [[ -f "$file" ]] || die "config not found: $file"
  [[ -f "$DEFAULTS_FILE" ]] || die "defaults not found: $DEFAULTS_FILE"

  require_cmds yq jq

  local defaults_json team_json
  defaults_json="$(yq eval -o=json '.' "$DEFAULTS_FILE")"
  team_json="$(yq eval -o=json '.' "$file")"

  CONFIG_JSON="$(echo "$team_json" "$defaults_json" | jq -s '
    .[1] as $defaults | .[0] |
    .awc = ($defaults.awc * (.awc // {})) |
    .behavior = ($defaults.behavior * (.behavior // {}))
  ')"

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

  config_validate
  config_export_shell
}

config_get() {
  local jq_path="$1"
  echo "$CONFIG_JSON" | jq -r "$jq_path"
}

config_validate() {
  local mp host kind
  host="$(config_get '.registryHost // empty')"
  mp="$(config_get '.marketplacePrefix // empty')"

  [[ -n "$host" ]] || die "registryHost is required (OCI hostname only, e.g. us-west1-docker.pkg.dev)"
  [[ "$host" != *"/"* ]] || die "registryHost must be hostname only (no path): $host"

  [[ -n "$mp" ]] || die "marketplacePrefix is required (repository path only, no host)"
  mp="${mp#/}"
  [[ "$mp" == *"/"* ]] || die "marketplacePrefix must be a path under the registry (e.g. my-project/enterprise/awc)"
  [[ "$mp" != *"://"* ]] || die "marketplacePrefix must not be a URL; set registryHost separately"

  if [[ "$mp" == "$host" || "$mp" == "$host/"* ]]; then
    die "marketplacePrefix must not include registryHost; use registryHost + path only"
  fi

  kind="$(config_get '.auth.kind // empty')"
  [[ -n "$kind" ]] || die "auth.kind is required"

  case "$kind" in
    gcr)
      [[ -n "$(config_get '.auth.keyFile // empty')" ]] || die "auth.keyFile is required for gcr"
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
      die "unsupported auth.kind: $kind (use gcr, basic, ecr, or acr)"
      ;;
  esac
}

config_export_shell() {
  local path
  REGISTRY_HOST="$(config_get '.registryHost')"
  path="$(config_get '.marketplacePrefix')"
  path="${path#/}"
  MARKETPLACE_PATH="$path"
  MARKETPLACE_PREFIX="${REGISTRY_HOST}/${path}"

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
