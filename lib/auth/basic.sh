# shellcheck shell=bash

auth_basic_resolve() {
  local user pass_file
  user="$(config_get '.auth.username')"
  pass_file="$(config_get '.auth.passwordFile')"
  [[ -r "$pass_file" ]] || die "cannot read auth.passwordFile: $pass_file"
  AUTH_USER="$user"
  AUTH_PASSWORD="$(cat "$pass_file")"
}
