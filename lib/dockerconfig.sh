# shellcheck shell=bash
# Merge registry host credentials into dockerconfig JSON.

dockerconfig_merge_host() {
  local current_file="$1"
  local host="$2"
  local user="$3"
  local pass="$4"
  local out_file="$5"

  require_cmds jq
  local auth
  auth="$(printf '%s' "${user}:${pass}" | base64_encode)"

  jq --arg h "$host" \
     --arg u "$user" \
     --arg p "$pass" \
     --arg a "$auth" \
     '.auths[$h] = {username: $u, password: $p, auth: $a}' \
     "$current_file" >"$out_file"
}

dockerconfig_fetch_current() {
  local secret_name="$1"
  local namespace="$2"
  local out_file="$3"

  if kubectl_cmd get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null \
      | base64 -d >"$out_file" 2>/dev/null; then
    if ! jq -e . "$out_file" >/dev/null 2>&1; then
      echo '{}' >"$out_file"
    fi
  else
    echo '{}' >"$out_file"
  fi
}
