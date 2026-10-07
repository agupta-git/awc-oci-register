# shellcheck shell=bash

# Returns 0 if prefix was added (or would be added in dry-run); 1 if already present.
marketplace_append_prefix() {
  local current new_list b64

  if is_dry_run; then
    log "[dry-run] would ensure $MARKETPLACE_DATA_KEY contains prefix: $MARKETPLACE_PREFIX"
    return 0
  fi

  current="$(kubectl_cmd get secret "$MARKETPLACE_SECRET" -n "$MARKETPLACE_NAMESPACE" \
    -o "jsonpath={.data.${MARKETPLACE_DATA_KEY}}" | base64 -d | tr -d '\n')"

  if [[ "$BEHAVIOR_SKIP_IF_PREFIX_PRESENT" == "true" ]] \
      && echo "$current" | tr ',' '\n' | grep -qxF "$MARKETPLACE_PREFIX"; then
    log "MARKETPLACE_REGISTRIES already contains: $MARKETPLACE_PREFIX"
    return 1
  fi

  if [[ -n "$current" ]]; then
    new_list="${current},${MARKETPLACE_PREFIX}"
  else
    new_list="$MARKETPLACE_PREFIX"
  fi

  log "append marketplace prefix: $MARKETPLACE_PREFIX"

  b64="$(printf '%s' "$new_list" | base64_encode)"
  kubectl_cmd patch secret "$MARKETPLACE_SECRET" -n "$MARKETPLACE_NAMESPACE" --type=merge \
    -p "{\"data\":{\"${MARKETPLACE_DATA_KEY}\":\"${b64}\"}}"

  log "MARKETPLACE_REGISTRIES now:"
  kubectl_cmd get secret "$MARKETPLACE_SECRET" -n "$MARKETPLACE_NAMESPACE" \
    -o "jsonpath={.data.${MARKETPLACE_DATA_KEY}}" | base64 -d
  printf '\n'
  return 0
}

marketplace_verify() {
  kubectl_cmd get secret "$MARKETPLACE_SECRET" -n "$MARKETPLACE_NAMESPACE" >/dev/null 2>&1 \
    || die "missing secret/$MARKETPLACE_SECRET in namespace $MARKETPLACE_NAMESPACE"
}
