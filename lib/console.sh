# shellcheck shell=bash

console_restart_if_needed() {
  local needed="$1"
  [[ "$needed" == "true" ]] || return 0
  [[ "$BEHAVIOR_RESTART_CONSOLE" == "true" ]] || return 0

  log "restart deployment/$CONSOLE_DEPLOYMENT in $MARKETPLACE_NAMESPACE"

  if is_dry_run; then
    log "[dry-run] would rollout restart deployment/$CONSOLE_DEPLOYMENT"
    return 0
  fi

  kubectl_cmd rollout restart "deployment/${CONSOLE_DEPLOYMENT}" -n "$MARKETPLACE_NAMESPACE"
  kubectl_cmd rollout status "deployment/${CONSOLE_DEPLOYMENT}" -n "$MARKETPLACE_NAMESPACE"
}
