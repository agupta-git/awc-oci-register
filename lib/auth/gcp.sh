# shellcheck shell=bash

auth_gcp_resolve() {
  local key_file
  key_file="$(config_get '.auth.keyFile')"
  [[ -r "$key_file" ]] || die "cannot read auth.keyFile: $key_file"
  AUTH_USER="_json_key"
  AUTH_PASSWORD="$(cat "$key_file")"
}
