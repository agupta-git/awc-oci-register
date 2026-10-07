# shellcheck shell=bash

AUTH_USER=""
AUTH_PASSWORD=""

auth_resolve() {
  case "$AUTH_KIND" in
    gcpServiceAccountKey) auth_gcp_resolve ;;
    basic) auth_basic_resolve ;;
    ecr) auth_ecr_resolve ;;
    acr) auth_acr_resolve ;;
    *) die "unknown auth.kind: $AUTH_KIND" ;;
  esac
  [[ -n "$AUTH_USER" && -n "$AUTH_PASSWORD" ]] || die "failed to resolve registry credentials"
}
