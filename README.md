# awc-oci-register

Register a **private OCI registry** with **Anywhere Cloud** and the **AWC marketplace** after you publish engine and blueprint artifacts.

The tool performs two updates on the AWC control plane:

1. **Pull credentials** — merge registry host auth into `awc-console-registry-creds` (`.dockerconfigjson` → `auths[<host>]`) in `auth-config-operator-system` and `awc-core`. A reflector propagates the secret to workload namespaces for image/chart pulls.
2. **Marketplace catalog** — append the full OCI catalog entry (`registryHost` + `marketplacePrefix`) to `awc-taikun-secrets` → `MARKETPLACE_REGISTRIES` in `awc-core`, then restart `awc-console` when the list changes.

| Concept | Config field | Stored as | Example |
|---------|--------------|-----------|---------|
| Registry **host** (pull auth) | `registryHost` | `auths` key in dockerconfigjson | `us-west1-docker.pkg.dev` |
| Repository **path** (under host) | `marketplacePrefix` | combined into `MARKETPLACE_REGISTRIES` | `phoenix-ai-images/enterprise/awc` |
| **Full catalog prefix** (computed) | — | comma entry in `MARKETPLACE_REGISTRIES` | `us-west1-docker.pkg.dev/phoenix-ai-images/enterprise/awc` |

This does **not** publish or mirror OCI artifacts (use `awc-marketplace publish` for that).

## Quick start

```bash
export KUBECONFIG=/path/to/awc-control-plane-kubeconfig
chmod +x ./awc-oci-register

cp examples/phoenixai-gcr.yaml team.local.yaml
# edit auth.keyFile and paths

./awc-oci-register verify -f team.local.yaml
./awc-oci-register plan  -f team.local.yaml
./awc-oci-register apply -f team.local.yaml
```

PhoenixAI (GCR / Artifact Registry): see [examples/phoenixai-gcr.yaml](examples/phoenixai-gcr.yaml).

## Commands

| Command | Description |
|---------|-------------|
| `apply -f config.yaml` | Patch pull secret and marketplace list |
| `plan -f config.yaml` | Dry-run; print intended changes |
| `verify -f config.yaml` | Dependencies, kube context, secrets exist |
| `init [-o file.yaml]` | Copy annotated template |

Optional: `--set auth.keyFile=/secure/key.json` for CI without editing YAML.

## Configuration

One YAML file per team or environment. Required:

- `registryHost` — OCI hostname only (no path)
- `marketplacePrefix` — repository path under that host (no hostname)
- `auth.kind` — `gcr`, `basic`, `ecr`, or `acr`

Examples: [examples/](examples/).

### Auth kinds

| `auth.kind` | Registries | Fields |
|-------------|------------|--------|
| `gcr` | GCR, Artifact Registry | `keyFile` (username is `_json_key`) |
| `basic` | Docker Hub, Harbor, Artifactory | `username`, `passwordFile` |
| `ecr` | Amazon ECR | `region` (uses `aws ecr get-login-password`) |
| `acr` | Azure ACR | `registryName` (uses `az acr login --expose-token`) |

## Dependencies

- **Always:** `kubectl`, `jq`, `yq` (v4), `base64`
- **ECR:** AWS CLI (`aws`)
- **ACR:** Azure CLI (`az`)

## Safety

AWC marketplace secrets on the control plane are shared platform resources. Export or back up current secret values before patching in production, and coordinate with platform owners when required.
