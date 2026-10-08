# awc-oci-register

Register a **private OCI registry** with the **Anywhere Cloud** **marketplace** after you publish engine and blueprint artifacts.

The tool performs two updates on the AWC control plane:

1. **Pull credentials** — merge registry host auth into `awc-console-registry-creds` in `auth-config-operator-system` and `awc-core`. A reflector propagates the secret to workload namespaces for image/chart pulls.
2. **Marketplace catalog** — append the full OCI catalog entry (`registryHost` + `marketplacePrefix`) to `awc-taikun-secrets` → `MARKETPLACE_REGISTRIES` in `awc-core`, then restart `awc-console` when the list changes.

## Quick start

```bash
git clone https://github.com/agupta-git/awc-oci-register.git
cd awc-oci-register
chmod +x ./awc-oci-register

cp examples/phoenixai-gcr.yaml config.local.yaml
# edit registryHost, marketplacePrefix, auth.keyFile
```

Point `kubectl` at the **AWC control plane** cluster (where `awc-core` runs):

- **Already on the cluster** (kubectl is preconfigured):
  ```bash
  kubectl config current-context
  ```
- **Outside the cluster** - set kubeconfig:
  ```bash
  export KUBECONFIG=/path/to/awc-control-plane-kubeconfig
  kubectl config current-context
  ```

Register the registry:

```bash
./awc-oci-register verify -f config.local.yaml
./awc-oci-register apply  -f config.local.yaml
```

Example configs: [examples/](examples/) (PhoenixAI: [phoenixai-gcr.yaml](examples/phoenixai-gcr.yaml)).

## Commands


| Command                 | Description                               |
| ----------------------- | ----------------------------------------- |
| `apply -f config.yaml`  | Patch pull secret and marketplace list    |
| `plan -f config.yaml`   | Dry-run; print intended changes           |
| `verify -f config.yaml` | Dependencies, kube context, secrets exist |
| `init [-o file.yaml]`   | Copy annotated template                   |


## Configuration

Use one YAML file (see [examples/](examples/)). Required fields:

- `registryHost` — OCI hostname only (no path)
- `marketplacePrefix` — repository path under that host (no hostname)
- `auth.kind` — `gcr`, `basic`, `ecr`, or `acr`

### Platform defaults (`config/defaults.yaml`)

[config/defaults.yaml](config/defaults.yaml) holds AWC marketplace settings (secret names, namespaces, console deployment, behavior flags). It is merged into your config on load. A minimal file only needs `registryHost`, `marketplacePrefix`, and `auth`; add `awc:` or `behavior:` to override defaults. Use `--set key=value` for one-off overrides (e.g. `awc.kubeconfig`).

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