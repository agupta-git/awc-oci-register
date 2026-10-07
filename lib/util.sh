# shellcheck shell=bash
# Shared helpers for awc-oci-register.

AWC_OCI_REGISTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

mktemp_dir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/awc-oci-register.XXXXXX")"
  echo "$d"
}

kubectl_cmd() {
  if [[ -n "${AWC_KUBECONFIG:-}" ]]; then
    kubectl --kubeconfig "$AWC_KUBECONFIG" "$@"
  else
    kubectl "$@"
  fi
}

require_cmds() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}

base64_encode() {
  if base64 --help 2>&1 | grep -q '\-w'; then
    base64 -w0
  else
    base64 | tr -d '\n'
  fi
}

is_dry_run() {
  [[ "${DRY_RUN:-0}" == "1" ]]
}
