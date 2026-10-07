# awc-oci-register

Register a **private OCI registry** with the **Anywhere Cloud** **marketplace** after you publish engine and blueprint artifacts.

The tool performs two updates on the AWC control plane:

1. **Pull credentials** — merge registry host auth into `awc-console-registry-creds` in `auth-config-operator-system` and `awc-core`. A reflector propagates the secret to workload namespaces for image/chart pulls.
2. **Marketplace catalog** — append the full OCI catalog entry (`registryHost` + `marketplacePrefix`) to `awc-taikun-secrets` → `MARKETPLACE_REGISTRIES` in `awc-core`, then restart `awc-console` when the list changes.

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


| Command                 | Description                               |
| ----------------------- | ----------------------------------------- |
| `apply -f config.yaml`  | Patch pull secret and marketplace list    |
| `plan -f config.yaml`   | Dry-run; print intended changes           |
| `verify -f config.yaml` | Dependencies, kube context, secrets exist |
| `init [-o file.yaml]`   | Copy annotated template                   |


## Configuration

One YAML file per team or environment. Required:

- `registryHost` — OCI hostname only (no path)
- `marketplacePrefix` — repository path under that host (no hostname)
- `auth.kind` — `gcr`, `basic`, `ecr`, or `acr`

Examples: [examples/](examples/).

### Platform defaults (`config/defaults.yaml`)

Secret names, Kubernetes namespaces, marketplace secret keys, and behavior flags are defined once in [config/defaults.yaml](config/defaults.yaml). Every team config is **merged** with that file on load—you only need `registryHost`, `marketplacePrefix`, and `auth` in your YAML unless something differs from standard AWC marketplace installs.

- **Platform / release maintainers:** edit `config/defaults.yaml` to change AWC-wide names (e.g. pull-secret namespaces).
- **One team / environment:** add an `awc:` or `behavior:` block in your team file to override specific keys.

Optional: `--set awc.kubeconfig=/path/to/kubeconfig` for CI.

### Auth kinds


| `auth.kind` | Registries                      | Fields                                              |
| ----------- | ------------------------------- | --------------------------------------------------- |
| `gcr`       | GCR, Artifact Registry          | `keyFile` (username is `_json_key`)                 |
| `basic`     | Docker Hub, Harbor, Artifactory | `username`, `passwordFile`                          |
| `ecr`       | Amazon ECR                      | `region` (uses `aws ecr get-login-password`)        |
| `acr`       | Azure ACR                       | `registryName` (uses `az acr login --expose-token`) |




## Dependencies

- **Always:** `kubectl`, `jq`, `yq` (v4), `base64`
- **ECR:** AWS CLI (`aws`)
- **ACR:** Azure CLI (`az`)



## Safety

AWC marketplace secrets on the control plane are shared platform resources. Export or back up current secret values before patching in production, and coordinate with platform owners when required.