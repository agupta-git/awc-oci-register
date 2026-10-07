# shellcheck shell=bash

pull_secret_apply_all() {
  local ns
  for ns in "${PULL_SECRET_NAMESPACES[@]}"; do
    pull_secret_apply_one "$ns"
  done
}

pull_secret_apply_one() {
  local ns="$1"
  local tmpdir cur merged b64

  log "merge pull credentials into secret/$PULL_SECRET_NAME namespace=$ns host=$REGISTRY_HOST"

  if is_dry_run; then
    log "[dry-run] would patch secret/$PULL_SECRET_NAME -n $ns"
    return 0
  fi

  tmpdir="$(mktemp_dir)"
  cur="$tmpdir/current.json"
  merged="$tmpdir/merged.json"

  dockerconfig_fetch_current "$PULL_SECRET_NAME" "$ns" "$cur"
  dockerconfig_merge_host "$cur" "$REGISTRY_HOST" "$AUTH_USER" "$AUTH_PASSWORD" "$merged"

  b64="$(base64_encode <"$merged")"
  kubectl_cmd patch secret "$PULL_SECRET_NAME" -n "$ns" --type=merge \
    -p "{\"data\":{\".dockerconfigjson\":\"${b64}\"}}"

  log "auths hosts in $ns:"
  kubectl_cmd get secret "$PULL_SECRET_NAME" -n "$ns" \
    -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq -r '.auths | keys[]' | sed 's/^/    /'
}

pull_secret_verify() {
  local ns
  for ns in "${PULL_SECRET_NAMESPACES[@]}"; do
    kubectl_cmd get secret "$PULL_SECRET_NAME" -n "$ns" >/dev/null 2>&1 \
      || die "missing secret/$PULL_SECRET_NAME in namespace $ns"
  done
}
