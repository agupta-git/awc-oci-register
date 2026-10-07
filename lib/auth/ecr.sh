# shellcheck shell=bash

auth_ecr_resolve() {
  local region
  region="$(config_get '.auth.region')"
  command -v aws >/dev/null 2>&1 || die "aws CLI required for auth.kind ecr"
  AUTH_USER="AWS"
  AUTH_PASSWORD="$(aws ecr get-login-password --region "$region")" \
    || die "aws ecr get-login-password failed for region $region"
}
