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

## Tech Stack
- **Installer:** Bash shell scripts + Helm
- **Charts:** Helm v3, stored in `charts/`
- **Docs site:** GitHub Pages (branch `gh-pages`)

## Key Components
```
egs-installer.sh          - Main installer entry point
egs-install-prerequisites.sh - Pre-flight dependency checker
egs-preflight-check.sh    - Cluster readiness validation
egs-uninstall.sh          - Full platform teardown
egs-troubleshoot.sh       - Diagnostic script
egs-installer-config.yaml - Primary configuration file (cluster endpoints, image tags, feature flags)
charts/                   - Helm charts for all EGS components
docs/                     - GitHub Pages documentation source
airgap-image-push/        - Scripts for air-gapped environment image mirroring
install-egs.sh            - Streamlined single-command installer
create-namespaces.sh      - Namespace bootstrapping
multi-cluster-example.yaml- Example config for multi-cluster deployments
```

## Usage
```bash
# Edit egs-installer-config.yaml with your cluster details
bash egs-installer.sh
```

## Key Configuration (`egs-installer-config.yaml`)
- Cluster endpoints (hub + workers)
- Component image tags (controller, worker-operator, queue-manager, etc.)
- Feature flags (GPU monitoring, time-slicing, SaaS mode)
- License key

## Dependencies & Integrations
- **apis-ent-egs** — CRD YAMLs applied during install
- **kubeslice-controller-ent-egs** — controller image installed
- **worker-operator-ent-egs** — worker operator image installed
- **egs-queue-manager, egs-core-apis, egs-gpu-agent, egs-inference-auth-server** — all installed as part of EGS stack
- **egs-installer-job** — containerised version of this installer for automated/SaaS deployments
