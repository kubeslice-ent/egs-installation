# REPO_CONTEXT: egs-installation

## Purpose
Primary EGS software installation repository. Contains Helm charts, shell scripts, and configuration for installing, upgrading, and uninstalling the full EGS platform stack on Kubernetes clusters. Also serves as the documentation site (GitHub Pages) for EGS.

## Role in EGS System
The authoritative installer used by customers and the SaaS team to deploy EGS. Installs:
- KubeSlice controller (hub cluster)
- KubeSlice worker operator (worker clusters)
- EGS core services (queue-manager, core-apis, inference-auth-server, gpu-agent)
- Observability stack (Prometheus, Grafana)
- Ingress, cert-manager, external-dns

## Current Version
**v1.17.2** — all Helm charts (kubeslice-controller-egs, kubeslice-ui-egs, kubeslice-worker-egs)

## Tech Stack
- **Installer:** Bash shell scripts + Helm
- **Charts:** Helm v3, stored in `charts/`
- **Docs site:** GitHub Pages (branch `gh-pages`)

## Key Components
```
install-egs.sh            - Primary single-command installer with full CLI flag support
egs-installer.sh          - Core installation logic (called by install-egs.sh)
egs-install-prerequisites.sh - Pre-flight dependency checker
egs-preflight-check.sh    - Cluster readiness validation
egs-uninstall.sh          - Full platform teardown (K3s/RKE/EKS/GKE/AKS aware)
egs-troubleshoot.sh       - Diagnostic script
egs-installer-config.yaml - Primary configuration file (cluster endpoints, image tags, feature flags)
egs-only-config.yaml      - Minimal config for EGS-only installs
charts/                   - Helm charts for all EGS components
docs/                     - GitHub Pages documentation source
airgap-image-push/        - Scripts for air-gapped environment image mirroring
create-namespaces.sh      - Namespace bootstrapping
multi-cluster-example.yaml- Example config for multi-cluster deployments
poc/                      - POC/lab install guides (K3S, RKE controller+worker, vLLM examples)
```

## Usage
```bash
# Standard install — edit egs-installer-config.yaml first
bash install-egs.sh

# Register a separate worker cluster
bash install-egs.sh --register-worker --worker-kubeconfig /path/to/worker.yaml

# Generate config file only, no install
bash install-egs.sh --generate-config

# Reuse existing config as-is (skip config regeneration)
bash install-egs.sh --preserve-config

# Use a local checkout of the installer instead of pulling from git
bash install-egs.sh --local-repo /path/to/local/egs-installation
```

## install-egs.sh CLI Flags
| Flag | Description |
|---|---|
| `--generate-config` / `--dry-run` | Build config file then exit without installing |
| `--preserve-config` | Reuse existing `egs-installer-config.yaml` as-is |
| `--skip-dependency-check` | Bypass Helm-based prerequisite detection |
| `--local-repo PATH` | Use a local installer checkout instead of git clone |
| `--register-worker` | Register a separate worker cluster against an existing controller |
| `--worker-kubeconfig` | Path(s) to worker cluster kubeconfigs |
| `--worker-endpoints` | Override worker endpoint addresses |
| `--project-name` | Override project name (default: `avesha`) |

The installer traps `EXIT/INT/TERM` to always clean up temp files and restore the original kubectl context, even on failure. Existing `egs-installer-config.yaml` is auto-backed up with a timestamp before any overwrite.

## egsAgent Endpoint Resolution
The `egsAgent.agentSecret.endpoint` is resolved by looking up the `kubeslice-ui-proxy` Service on the controller cluster, regardless of whether the UI is being installed in the current run. This makes `--register-worker` mode work correctly without crash-looping egs-agent on a missing `API_GW_ENDPOINT`. The lookup is non-fatal — if the Service is absent it warns and skips rather than failing the install.

## egs-uninstall.sh Behavior
- Retries kubectl calls on transient API server errors (configurable via `KUBECTL_RETRY_MAX`, `KUBECTL_RETRY_DELAY`)
- Prunes stale/orphaned pods in batches before bulk namespace deletes to avoid API overload
- Removes SPIRE and KServe namespaces created by the worker operator
- Removes SPIRE CRDs on full teardown
- Works across all distros: K3s, RKE, EKS, GKE, AKS, kubeadm

## Key Configuration (`egs-installer-config.yaml`)
- Cluster endpoints (hub + workers)
- Component image tags (controller, worker-operator, queue-manager, etc.)
- Feature flags (GPU monitoring, time-slicing, SaaS mode)
- License key

## POC Guides (`poc/`)
- `K3S EGS Install Readme.md` — K3S-based EGS install walkthrough
- `EGS-RKE-Controller-Install-Guide.md` — RKE controller cluster install
- `EGS-RKE-Worker-Install-Guide.md` — RKE worker cluster install
- `POC ReadMe.md` — POC overview and prerequisites
- `sample-inference-endpoint.yaml` — sample InferenceEndpoint CR for testing
- `vllm-helm-values.yaml`, `vllm-slice-ns-gateway.yaml` — vLLM deployment examples

## Dependencies & Integrations
- **apis-ent-egs** — CRD YAMLs applied during install
- **kubeslice-controller-ent-egs** — controller image installed
- **worker-operator-ent-egs** — worker operator image installed
- **egs-queue-manager, egs-core-apis, egs-gpu-agent, egs-inference-auth-server** — all installed as part of EGS stack
- **egs-installer-job** — containerised version of this installer for automated/SaaS deployments
