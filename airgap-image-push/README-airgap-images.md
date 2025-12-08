# Airgap Image Management

## Overview

This documentation covers two companion scripts for managing container images in airgap environments:

- **`airgap-image-pull.sh`**: Extracts all container images from Helm charts for **kubeslice-egs-helm-ent-prod** charts. It reads chart information from a configuration file and generates a comprehensive list of all container images used in the specified Helm charts.

- **`airgap-image-push.sh`**: Pushes container images to a target repository. It reads a list of images and performs pull, tag, and push operations for airgap deployments.

## Features

- ✅ Extracts container images from Helm charts
- ✅ **Resilient processing**: Continues processing all charts even if one fails
- ✅ Supports specific chart versions or latest version (`*`)
- ✅ Processes all kubeslice-egs-helm-ent-prod charts:
  - `kubeslice-controller-egs`
  - `kubeslice-worker-egs`
  - `kubeslice-ui-egs`
- ✅ Handles subcharts (kubetally, NSM)
- ✅ Validates repository URL and repository name
- ✅ Creates organized output with date-based directories
- ✅ Deduplicates images automatically
- ✅ Generates both consolidated and per-chart image lists
- ✅ Provides execution summary showing which charts were processed successfully

## Prerequisites

### Required Tools

1. **Helm** (v3.x)
   ```bash
   helm version
   ```

2. **yq** (v4.x)
   ```bash
   yq --version
   ```

3. **Bash** (v4.0+)

4. **sed** (stream editor)
   ```bash
   sed --version
   ```
   **Note**: `sed` is typically pre-installed on most Linux/Unix systems. It's used internally by the script and in the manual configuration commands provided in this documentation.

### Required Environment Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `HELM_CHART_INFO` | Path to the chart info file (e.g., `helm-chart-info.txt`) | ✅ Yes | `helm-chart-info.txt` |

## Input File Format

The `airgap-image-pull.sh` script reads chart information from a text file (typically named `helm-chart-info.txt`). This file should be specified using the `HELM_CHART_INFO` environment variable.

**Reference File**: An example `helm-chart-info.txt` file is provided in the `airgap-image-push/` directory. When running the script from within the `airgap-image-push/` directory, you can use it directly. You can also use it as a template or modify it according to your needs.

The input file format is as follows:

```
*****************<repo-url>*************** ******<repo-name>****** ****<chart-name>**** ****<chart-version>****
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-controller-egs 1.15.4
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-worker-egs 1.15.4
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-ui-egs 1.15.4
```

### File Format Details

- **Line 1**: Header line (will be skipped automatically)
- **Subsequent lines**: Each line contains 4 space-separated fields:
  1. **REPO_URL**: Must be exactly `https://kubeslice.aveshalabs.io/repository`
  2. **REPO_NAME**: Must be exactly `kubeslice-egs-helm-ent-prod`
  3. **CHART_NAME**: One of the following charts:
     - `kubeslice-controller-egs`
     - `kubeslice-worker-egs`
     - `kubeslice-ui-egs`
  4. **CHART_VERSION**: 
     - Specific version: `1.15.3`, `1.15.4`, etc.
     - Latest version: `*` (will fetch the latest available version from the prod repository)

### Example Input Files

**Example: `helm-chart-info.txt` with Specific Versions:**
```
*****************<repo-url>*************** ******<repo-name>****** ****<chart-name>**** ****<chart-version>****
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-controller-egs 1.15.4
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-worker-egs 1.15.4
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-ui-egs 1.15.4
```

**Example: `helm-chart-info.txt` with Latest Versions:**
```
*****************<repo-url>*************** ******<repo-name>****** ****<chart-name>**** ****<chart-version>****
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-controller-egs *
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-worker-egs *
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-ui-egs *
```

**Note**: 
- An example `helm-chart-info.txt` file is available in the `airgap-image-push/` directory for reference
- When running the script from within the `airgap-image-push/` directory, use: `export HELM_CHART_INFO="helm-chart-info.txt"`
- The file name `helm-chart-info.txt` is a convention, but you can use any filename
- Ensure you set the `HELM_CHART_INFO` environment variable to point to your input file
- You can modify the example file or create your own following the format above

## Usage

### Basic Usage

```bash
# Set required environment variable to point to your input file
# When running from within the airgap-image-push/ directory:
export HELM_CHART_INFO="helm-chart-info.txt"

# Run the script
bash airgap-image-pull.sh
```

### Complete Example

```bash
#!/bin/bash

# Navigate to the airgap-image-push directory (if not already there)
cd airgap-image-push

# Set required environment variable to point to your input file
# The example file helm-chart-info.txt is in the current directory
export HELM_CHART_INFO="helm-chart-info.txt"

# Run the script
bash airgap-image-pull.sh
```

**Using the Reference File**: 
- An example `helm-chart-info.txt` file is provided in the `airgap-image-push/` directory
- When running the script from within the `airgap-image-push/` directory, use: `export HELM_CHART_INFO="helm-chart-info.txt"`
- The file should follow the format described in the "Input File Format" section above

## Image Registry Configuration

### Using egs-installer-config.yaml

If you are using the `egs-installer-config.yaml` file for your installation, you can extract the image registry settings from it for both the image pull and push scripts.

**Note**: The commands below should be run from the `egs-installation/` directory (parent directory of `airgap-image-push/`). If you're in the `airgap-image-push/` directory, use `../egs-installer-config.yaml` instead of `egs-installer-config.yaml`.

#### For Image Pull Script (`airgap-image-pull.sh`)

The image pull script should use the image registry settings from `egs-installer-config.yaml` for pulling images. Extract the registry values using the following paths:

1. **Controller Chart Registry**:
   ```bash
   # From egs-installation/ directory:
   yq eval '.kubeslice_controller_egs.inline_values.global.imageRegistry' egs-installer-config.yaml
   
   # Or from airgap-image-push/ directory:
   yq eval '.kubeslice_controller_egs.inline_values.global.imageRegistry' ../egs-installer-config.yaml
   ```
   Example output: `harbor.saas1.smart-scaler.io/avesha/aveshasystems`

2. **UI Chart Registry**:
   ```bash
   # From egs-installation/ directory:
   yq eval '.kubeslice_ui_egs.inline_values.global.imageRegistry' egs-installer-config.yaml
   
   # Or from airgap-image-push/ directory:
   yq eval '.kubeslice_ui_egs.inline_values.global.imageRegistry' ../egs-installer-config.yaml
   ```
   Example output: `harbor.saas1.smart-scaler.io/avesha/aveshasystems`

3. **Worker Chart Registry** (for each worker in the array):
   ```bash
   # From egs-installation/ directory:
   yq eval '.kubeslice_worker_egs[].inline_values.global.imageRegistry' egs-installer-config.yaml
   
   # Or from airgap-image-push/ directory:
   yq eval '.kubeslice_worker_egs[].inline_values.global.imageRegistry' ../egs-installer-config.yaml
   ```
   Example output: `harbor.saas1.smart-scaler.io/avesha/aveshasystems`

**Note**: The image pull script will use these registries when extracting images from Helm charts. Ensure that the registry values in `egs-installer-config.yaml` point to the source registry where images should be pulled from.

#### For Image Push Script (`airgap-image-push.sh`)

The image push script should use the global image pull secret registry from `egs-installer-config.yaml` for pushing images to the target airgap registry:

```bash
# From egs-installation/ directory:
yq eval '.global_image_pull_secret.registry' egs-installer-config.yaml

# Or from airgap-image-push/ directory:
yq eval '.global_image_pull_secret.registry' ../egs-installer-config.yaml
```

Example output: `https://index.docker.io/v1/` or your airgap registry URL

**Important**: The `global_image_pull_secret.registry` setting in `egs-installer-config.yaml` is used for global image pull secret settings for airgap installations. This registry will be the target where images are pushed during the airgap setup.

### Using Local Charts (Manual Configuration)

If you are **not** using `egs-installer-config.yaml` and are working directly with the local charts in `charts/`, you need to manually update the `global.imageRegistry` value in each chart's `values.yaml` file:

**Note**: The commands below should be run from the `egs-installation/` directory where the `charts/` directory is located.

1. **Controller Chart**:
   - File: `charts/kubeslice-controller-egs/values.yaml`
   - Update: `global.imageRegistry`

2. **UI Chart**:
   - File: `charts/kubeslice-ui-egs/values.yaml`
   - Update: `global.imageRegistry`

3. **Worker Chart**:
   - File: `charts/kubeslice-worker-egs/values.yaml`
   - Update: `global.imageRegistry`

#### Quick Update Using sed Command

To update all three charts' `global.imageRegistry` values at once, use the following sed command:

```bash
# Run from egs-installation/ directory
# Replace REGISTRY_URL with your actual registry URL
REGISTRY_URL="harbor.saas1.smart-scaler.io/avesha/aveshasystems"

# Update controller chart
sed -i "s|^  imageRegistry:.*|  imageRegistry: ${REGISTRY_URL}|" charts/kubeslice-controller-egs/values.yaml

# Update UI chart
sed -i "s|^  imageRegistry:.*|  imageRegistry: ${REGISTRY_URL}|" charts/kubeslice-ui-egs/values.yaml

# Update worker chart
sed -i "s|^  imageRegistry:.*|  imageRegistry: ${REGISTRY_URL}|" charts/kubeslice-worker-egs/values.yaml
```

**Alternative single command** (updates all three files in one go):

```bash
# Run from egs-installation/ directory
# Replace REGISTRY_URL with your actual registry URL
REGISTRY_URL="harbor.saas1.smart-scaler.io/avesha/aveshasystems"

# Update all three charts at once
for chart in kubeslice-controller-egs kubeslice-ui-egs kubeslice-worker-egs; do
  sed -i "s|^  imageRegistry:.*|  imageRegistry: ${REGISTRY_URL}|" charts/${chart}/values.yaml
done
```

**Verification**: After updating, verify the changes:

```bash
# Run from egs-installation/ directory
# Check controller chart
grep "imageRegistry:" charts/kubeslice-controller-egs/values.yaml

# Check UI chart
grep "imageRegistry:" charts/kubeslice-ui-egs/values.yaml

# Check worker chart
grep "imageRegistry:" charts/kubeslice-worker-egs/values.yaml
```

## Output

### Output Files

The script generates the following output files:

#### 1. Consolidated File (All Charts Combined)

**Location**: `helm-chart-images.txt` (in the directory where you run the script)

**Note**: This is a **generated output file** created by the script. It will be created when you run `airgap-image-pull.sh` and contains all unique images from all processed charts.

- Contains all unique images from all processed charts
- Sorted and deduplicated
- Format: One image per line

**Example content (from version 1.15.4):**
```
harbor.saas1.smart-scaler.io/avesha/aveshasystems/alpine-k8s:1.0.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/alpine-k8s:1.22.9
harbor.saas1.smart-scaler.io/avesha/aveshasystems/brancz-kube-rbac-proxy:v0.18.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-admission-webhook-k8s:1.7.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-exclude-prefixes-k8s:1.5.5
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-forwarder-kernel:1.0.9
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nsc:1.5.14
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nsc-init:1.5.9
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nse-vl3:1.0.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nsmgr:1.5.7
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-registry-k8s:1.5.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/dns:0.1.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/egs-agent:1.0.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/egs-core-apis:1.14.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/egs-gpu-agent:1.0.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/envoygateway:v1.0.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/envoyproxy-distroless:1.30.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gateway-certs-generator:0.8.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gpr-manager:1.14.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gw-sidecar:1.0.5
harbor.saas1.smart-scaler.io/avesha/aveshasystems/inventory-manager:1.14.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-controller:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-huggingfaceserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-lgbserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-modelmesh-controller:v0.12.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-paddleserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-pmmlserver:v0.14.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-sklearnserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-storage-initializer:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-xgbserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kube-aiops-operator:1.15.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubebuilder-kube-rbac-proxy:0.18.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-api-gw-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-controller-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-router-sidecar:1.4.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-proxy:1.12.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-v2-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubetally-report:1.13.5
harbor.saas1.smart-scaler.io/avesha/aveshasystems/metrics-server:v0.6.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/minio:RELEASE.2025-09-07T16-13-09Z-cpuv1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/netops:0.2.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/nvidia-tritonserver:23.04-py3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/nvidia-tritonserver:23.05-py3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/openvino-model_server:2022.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/openvpn-client.alpine:1.0.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/openvpn-server.alpine:1.0.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/price-updater:1.12.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/pricing-service:1.13.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/proxyv2:1.16.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/pytorch-torchserve:0.7.1-cpu
harbor.saas1.smart-scaler.io/avesha/aveshasystems/pytorch-torchserve-kfs:0.9.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/queue-manager:1.13.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/seldonio-mlserver:1.3.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/seldonio-mlserver:1.5.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/sig-storage-csi-node-driver-registrar:v2.8.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/slicegw-edge:1.0.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spiffe-csi-driver:0.2.7
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spiffe-spire-controller-manager:0.2.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spire-agent:1.9.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spire-server:1.9.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/tensorflow-serving:2.6.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/wait-for-it:1.0.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/wireguard-client.alpine:1.0.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/wireguard-server.alpine:1.0.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/worker-installer:1.9.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/worker-operator-ent-egs:1.15.4
```

#### 2. Per-Chart Files (Individual Chart Outputs)

Each chart gets its own output file in a date-based directory structure:

**Directory Structure**: `kubeslice-egs-helm-ent-prod/<DATE>/<CHART_NAME>/<CHART_VERSION>/helm-chart-images.txt`

**Where:**
- `<DATE>` = Timestamp when script was run (format: `YYYY-MM-DDTHH:MM:SS`, e.g., `2025-11-21T14:25:04`)
- `<CHART_NAME>` = One of: `kubeslice-controller-egs`, `kubeslice-worker-egs`, `kubeslice-ui-egs`
- `<CHART_VERSION>` = Chart version (e.g., `1.15.4`)

**Note**: These are **generated output files** created by the script. The directory structure is created automatically when you run `airgap-image-pull.sh`.

**Exact File Locations for All 3 Charts:**

When you process all three charts, you'll get these files:

1. **kubeslice-controller-egs**:
   ```
   kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-controller-egs/1.15.4/helm-chart-images.txt
   ```
   Example: `kubeslice-egs-helm-ent-prod/2025-11-21T14:25:04/kubeslice-controller-egs/1.15.4/helm-chart-images.txt`

2. **kubeslice-worker-egs**:
   ```
   kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-worker-egs/1.15.4/helm-chart-images.txt
   ```
   Example: `kubeslice-egs-helm-ent-prod/2025-11-21T14:25:04/kubeslice-worker-egs/1.15.4/helm-chart-images.txt`

3. **kubeslice-ui-egs**:
   ```
   kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-ui-egs/1.15.4/helm-chart-images.txt
   ```
   Example: `kubeslice-egs-helm-ent-prod/2025-11-21T14:25:04/kubeslice-ui-egs/1.15.4/helm-chart-images.txt`

**Note**: The `<DATE>` will be different each time you run the script, creating a new timestamped directory. This means:
- Each run creates a new directory (no overwriting)
- Historical runs are preserved automatically
- You can compare images across different runs
- Old directories are NOT automatically deleted (you can clean them up manually if needed)

### Complete Output Structure

```
.
├── helm-chart-images.txt                    # ✅ Consolidated image list (all charts)
└── kubeslice-egs-helm-ent-prod/
    └── <DATE>/                               # Date-based directory (timestamp, e.g., 2025-11-21T14:25:04)
        ├── kubeslice-controller-egs/
        │   └── 1.15.4/
        │       └── helm-chart-images.txt     # ✅ Controller chart images
        ├── kubeslice-worker-egs/
        │   └── 1.15.4/
        │       └── helm-chart-images.txt     # ✅ Worker chart images
        └── kubeslice-ui-egs/
            └── 1.15.4/
                └── helm-chart-images.txt     # ✅ UI chart images
```

**Note**: Both `helm-chart-images.txt` and the `kubeslice-egs-helm-ent-prod/` directory are **generated output files** created by the script when you run `airgap-image-pull.sh`.

### Finding Your Output Files

**Quick commands to find output files:**

```bash
# Find all per-chart image files
find kubeslice-egs-helm-ent-prod -name "helm-chart-images.txt" -type f

# List all output files with details
find kubeslice-egs-helm-ent-prod -name "helm-chart-images.txt" -exec ls -lh {} \;

# Count images in each file
for file in $(find kubeslice-egs-helm-ent-prod -name "helm-chart-images.txt"); do
  echo "$file: $(wc -l < $file) images"
done

# View specific chart's images (replace <DATE> with actual timestamp from your run)
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-controller-egs/1.15.4/helm-chart-images.txt

# Or use find to get the latest run
LATEST_RUN=$(ls -td kubeslice-egs-helm-ent-prod/*/ | head -1)
cat ${LATEST_RUN}kubeslice-controller-egs/1.15.4/helm-chart-images.txt
```

### Output File Format

All output files (both consolidated and per-chart) use the same format:
- One container image per line
- Full image path with registry, repository, and tag
- Sorted alphabetically
- Deduplicated (no duplicate images)

**Example (from version 1.15.4):**
```
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gateway-certs-generator:0.8.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-controller-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/worker-operator-ent-egs:1.15.4
```

## Chart Processing Details

### kubeslice-controller-egs

- Extracts images from main chart templates
- Processes kubetally subchart if present
- Handles global image registry configuration
- Extracts images with proper registry prefixes

### kubeslice-worker-egs

- Extracts images from worker chart templates
- Handles imagePullSecrets validation
- Processes NSM subchart if present
- Extracts metrics-server images from preinstall configmap
- Requires dummy cluster.name and cluster.endpoint for validation

### kubeslice-ui-egs

- Extracts images using default extraction method
- Processes all image references in chart templates

## Validation

The script performs validations to ensure correct processing:

1. **Repository URL**: Must be exactly `https://kubeslice.aveshalabs.io/repository`
2. **Repository Name**: Must be exactly `kubeslice-egs-helm-ent-prod`
3. **Input File**: Must exist and be readable
4. **Chart Version**: Validates version format or `*` for latest

## Error Handling

The script uses `set +e` to continue processing all charts even if one fails. This ensures that:
- If one chart fails, other charts are still processed
- You get a complete summary of all successful, failed, and skipped charts
- The script provides detailed error messages for each failure

Common errors:

1. **Missing Input File**
   ```
   Error: Input file not found: <path>
   Please set HELM_CHART_INFO environment variable to the path of your chart info file.
   ```

2. **Repository Add Failure**
   ```
   Error: Failed to add Helm repository for <chart-name>
   ```
   Solution: Check network connectivity and verify repository URL is correct

3. **Chart Not Found**
   ```
   Error: Failed to pull chart
   ```
   Solution: Verify chart name and version exist in the repository

4. **Invalid Chart Version**
   ```
   Error: Failed to pull chart
   ```
   Solution: Check if the specified version exists

## Troubleshooting

### Issue: Script exits immediately

**Cause**: Missing required environment variable or invalid input file

**Solution**:
```bash
# Verify required environment variable is set
echo $HELM_CHART_INFO

# Verify input file exists
ls -la $HELM_CHART_INFO
```

### Issue: "Warning: Skipping non-prod chart"

**Cause**: Input file contains wrong repository name

**Solution**: 
1. Ensure all lines have:
   - `REPO_NAME` exactly `kubeslice-egs-helm-ent-prod`
   - `REPO_URL` exactly `https://kubeslice.aveshalabs.io/repository`

### Issue: No images extracted

**Cause**: Chart templates don't contain image references or extraction failed

**Solution**:
1. Check if chart was pulled successfully
2. Verify chart has image references in values.yaml
3. Check script output for processing messages

### Issue: Repository access errors

**Cause**: Network issues or repository unavailable

**Solution**:
```bash
# Test repository access manually
helm repo add test-repo https://kubeslice.aveshalabs.io/repository/kubeslice-egs-helm-ent-prod/

# If this fails, check:
# 1. Network connectivity
# 2. Repository URL is correct
# 3. Repository is accessible from your location
```

## Best Practices

1. **Use Specific Versions**: For reproducible results, use specific chart versions instead of `*`

2. **Organize Input Files**: Keep chart info files organized by version:
   ```
   helm-chart-info-1.15.4.txt
   helm-chart-info-1.15.5.txt
   helm-chart-info-latest.txt
   ```

3. **Review Output**: Always review `helm-chart-images.txt` (the generated consolidated output file) to ensure all expected images are present. This file is created in the directory where you run the script.

4. **Clean Up**: The script automatically cleans up:
   - Helm repository entries (removed after each chart)
   - Extracted chart directories (removed after processing)
   - Temporary files
   
   **Note**: Old timestamped output directories are NOT deleted automatically. Each run creates a new timestamped directory, so you can keep historical runs. To clean up old directories manually:
   ```bash
   # Remove directories older than 30 days
   find kubeslice-egs-helm-ent-prod -type d -mtime +30 -exec rm -rf {} +
   ```

## Script Workflow

1. **Initialization**
   - Validates input file exists
   - Creates output file
   - Sets up date-based directory structure
   - Initializes tracking arrays for processed/failed/skipped charts

2. **Chart Processing Loop** (uses `set +e` to continue on errors)
   - Reads each line from input file (skips header)
   - Validates repository URL and name
   - Adds Helm repository
   - Determines chart version (specific or latest using `*`)
   - Pulls chart (with cleanup of existing directories)
   - Extracts images based on chart type:
     - **Controller**: Main chart + kubetally subchart
     - **Worker**: Main chart + NSM subchart + metrics-server
     - **UI**: Default extraction method
   - Processes subcharts if present
   - Saves per-chart image list
   - Cleans up chart and repository
   - Tracks success/failure for summary

3. **Finalization**
   - Deduplicates consolidated image list
   - Sorts images
   - Displays comprehensive summary:
     - Successfully processed charts
     - Failed charts (with reasons)
     - Skipped charts (with reasons)
     - Total unique images found
     - Per-chart output file locations

## Airgap Image Push Script

The `airgap-image-push.sh` script is a companion utility that helps push container images to a target repository. It reads a list of images and performs pull, tag, and push operations for airgap deployments.

### Features

- ✅ Pulls images from source registries
- ✅ Tags images with target repository prefix
- ✅ Pushes images to target repository
- ✅ Supports dry-run mode for testing
- ✅ Supports both Docker Hub and private registries (Nexus)
- ✅ Auto-detects registry type and adjusts image tagging accordingly
- ✅ Processes all images from version 1.15.4

### Supported Registry Types

| Registry Type | REPO Format | Tagged Image Format |
|--------------|-------------|---------------------|
| Docker Hub | `docker.io/username` | `username/image:tag` |
| Private Registry (Nexus) | `registry.example.com` | `registry.example.com/path/image:tag` |

### Prerequisites

1. **Docker**: Docker must be installed and running

2. **Registry Authentication**: You must login to your target registry before running the push script:

   **For Docker Hub:**
   ```bash
   docker login -u <username>
   # Enter your password or access token when prompted
   ```

   **For Private Registry (Nexus):**
   ```bash
   docker login <registry-url>
   # Example: docker login kubeslice.aveshalabs.io
   # Enter your username and password when prompted
   ```

   **Note**: Without authentication, the push operation will fail with `unauthorized: access to the requested resource is not authorized`.

### Configuration

Before running the script, you need to update two things in `airgap-image-push.sh`:

#### 1. Update Target Repository

Edit the `REPO` variable in `airgap-image-push.sh` to set your target repository:

```bash
# Open the script for editing
vi airgap-image-push.sh

# Find and update this line (around line 4):
REPO="kubeslice.aveshalabs.io"  # Change to your target registry
```

**Using egs-installer-config.yaml**:

If you're using `egs-installer-config.yaml`, extract the target registry and update the script:

```bash
# Run from airgap-image-push/ directory
# Extract target registry from egs-installer-config.yaml
TARGET_REGISTRY=$(yq eval '.global_image_pull_secret.registry' ../egs-installer-config.yaml)
# Remove protocol prefix if present (e.g., https://)
TARGET_REGISTRY=$(echo "$TARGET_REGISTRY" | sed 's|^https\?://||' | sed 's|/v1/$||')

# Update the script
sed -i "s|^REPO=.*|REPO=\"${TARGET_REGISTRY}\"|" airgap-image-push.sh
```

**Note**: If you're running from the `egs-installation/` directory, use `egs-installer-config.yaml` instead of `../egs-installer-config.yaml`:
```bash
# Run from egs-installation/ directory
TARGET_REGISTRY=$(yq eval '.global_image_pull_secret.registry' egs-installer-config.yaml)
TARGET_REGISTRY=$(echo "$TARGET_REGISTRY" | sed 's|^https\?://||' | sed 's|/v1/$||')
sed -i "s|^REPO=.*|REPO=\"${TARGET_REGISTRY}\"|" airgap-image-push/airgap-image-push.sh
```

#### 2. Update Image List

The script contains a hardcoded list of images in the `IMAGES` array. You need to update this list with the images extracted by `airgap-image-pull.sh`.

**Option A: Copy from the consolidated output file**

After running `airgap-image-pull.sh`, you'll have a consolidated file `helm-chart-images.txt`. Copy the images from this file to the `IMAGES` array in `airgap-image-push.sh`:

1. Open `helm-chart-images.txt` to view the extracted images
2. Copy the image list
3. Update the `IMAGES` array in `airgap-image-push.sh` with the copied images

**Option B: Manually update the IMAGES array**

1. Open `airgap-image-push.sh` in an editor
2. Find the `IMAGES` array (starts around line 8)
3. Replace the existing image list with images from your `helm-chart-images.txt` file
4. Ensure each image is on a separate line and properly quoted

**Example of updating the IMAGES array:**

```bash
# From this:
IMAGES=(
"harbor.saas1.smart-scaler.io/avesha/aveshasystems/image1:tag1"
"harbor.saas1.smart-scaler.io/avesha/aveshasystems/image2:tag2"
)

# To this (using your extracted images):
IMAGES=(
"harbor.saas1.smart-scaler.io/avesha/aveshasystems/new-image1:tag1"
"harbor.saas1.smart-scaler.io/avesha/aveshasystems/new-image2:tag2"
)
```

### Usage

```bash
# Run with actual push
bash airgap-image-push.sh

# Run in dry-run mode (no actual operations)
bash airgap-image-push.sh --dry-run
```

### Image List

The script contains all images from version 1.15.4, organized by chart:

**Controller Chart Images:**
```bash
# Replace <DATE> with actual timestamp from your run
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-controller-egs/1.15.4/helm-chart-images.txt

# Or use find to get the latest run
LATEST_RUN=$(ls -td kubeslice-egs-helm-ent-prod/*/ | head -1)
cat ${LATEST_RUN}kubeslice-controller-egs/1.15.4/helm-chart-images.txt
```
```
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gateway-certs-generator:0.8.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gpr-manager:1.14.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/inventory-manager:1.14.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubebuilder-kube-rbac-proxy:0.18.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-controller-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubetally-report:1.13.5
harbor.saas1.smart-scaler.io/avesha/aveshasystems/minio:RELEASE.2025-09-07T16-13-09Z-cpuv1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/price-updater:1.12.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/pricing-service:1.13.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/queue-manager:1.13.3
```

**UI Chart Images:**
```bash
# Replace <DATE> with actual timestamp from your run
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-ui-egs/1.15.4/helm-chart-images.txt

# Or use find to get the latest run
LATEST_RUN=$(ls -td kubeslice-egs-helm-ent-prod/*/ | head -1)
cat ${LATEST_RUN}kubeslice-ui-egs/1.15.4/helm-chart-images.txt
```
```
harbor.saas1.smart-scaler.io/avesha/aveshasystems/egs-core-apis:1.14.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-api-gw-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-proxy:1.12.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-ui-v2-ent-egs:1.15.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/worker-installer:1.9.0
```

**Worker Chart Images:**
```bash
# Replace <DATE> with actual timestamp from your run
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-worker-egs/1.15.4/helm-chart-images.txt

# Or use find to get the latest run
LATEST_RUN=$(ls -td kubeslice-egs-helm-ent-prod/*/ | head -1)
cat ${LATEST_RUN}kubeslice-worker-egs/1.15.4/helm-chart-images.txt
```
```
harbor.saas1.smart-scaler.io/avesha/aveshasystems/alpine-k8s:1.0.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/alpine-k8s:1.22.9
harbor.saas1.smart-scaler.io/avesha/aveshasystems/brancz-kube-rbac-proxy:v0.18.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-admission-webhook-k8s:1.7.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-exclude-prefixes-k8s:1.5.5
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-forwarder-kernel:1.0.9
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nsc:1.5.14
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nsc-init:1.5.9
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nse-vl3:1.0.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-nsmgr:1.5.7
harbor.saas1.smart-scaler.io/avesha/aveshasystems/cmd-registry-k8s:1.5.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/dns:0.1.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/egs-agent:1.0.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/egs-gpu-agent:1.0.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/envoygateway:v1.0.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/envoyproxy-distroless:1.30.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/gw-sidecar:1.0.5
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-controller:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-huggingfaceserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-lgbserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-modelmesh-controller:v0.12.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-paddleserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-pmmlserver:v0.14.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-sklearnserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-storage-initializer:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kserve-xgbserver:v0.14.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kube-aiops-operator:1.15.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubebuilder-kube-rbac-proxy:0.18.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/kubeslice-router-sidecar:1.4.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/metrics-server:v0.6.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/netops:0.2.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/nvidia-tritonserver:23.04-py3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/nvidia-tritonserver:23.05-py3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/openvino-model_server:2022.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/openvpn-client.alpine:1.0.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/openvpn-server.alpine:1.0.4
harbor.saas1.smart-scaler.io/avesha/aveshasystems/proxyv2:1.16.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/pytorch-torchserve:0.7.1-cpu
harbor.saas1.smart-scaler.io/avesha/aveshasystems/pytorch-torchserve-kfs:0.9.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/seldonio-mlserver:1.3.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/seldonio-mlserver:1.5.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/sig-storage-csi-node-driver-registrar:v2.8.1
harbor.saas1.smart-scaler.io/avesha/aveshasystems/slicegw-edge:1.0.6
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spiffe-csi-driver:0.2.7
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spiffe-spire-controller-manager:0.2.3
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spire-agent:1.9.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/spire-server:1.9.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/tensorflow-serving:2.6.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/wait-for-it:1.0.2
harbor.saas1.smart-scaler.io/avesha/aveshasystems/wireguard-client.alpine:1.0.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/wireguard-server.alpine:1.0.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/worker-installer:1.9.0
harbor.saas1.smart-scaler.io/avesha/aveshasystems/worker-operator-ent-egs:1.15.4
```

### Configuration

The script configuration depends on whether you're using `egs-installer-config.yaml` or working with local charts:

#### Using egs-installer-config.yaml

If you are using `egs-installer-config.yaml`, the target repository for pushing images should be extracted from the global image pull secret registry:

```bash
# From egs-installation/ directory:
TARGET_REGISTRY=$(yq eval '.global_image_pull_secret.registry' egs-installer-config.yaml)
echo "Target registry: ${TARGET_REGISTRY}"

# Or from airgap-image-push/ directory:
TARGET_REGISTRY=$(yq eval '.global_image_pull_secret.registry' ../egs-installer-config.yaml)
echo "Target registry: ${TARGET_REGISTRY}"
```

**Note**: The `global_image_pull_secret.registry` setting in `egs-installer-config.yaml` is used for global image pull secret settings for airgap installations. This registry will be the target where images are pushed during the airgap setup.

#### Default Configuration (if not using egs-installer-config.yaml)

If you're not using `egs-installer-config.yaml`, the script uses the following default configuration:

- **Target Repository**: `kubeslice.aveshalabs.io`
- **Image Source**: Images are pulled from their original registries (e.g., `harbor.saas1.smart-scaler.io`)
- **Tagging**: Images are tagged as `kubeslice.aveshalabs.io/<image-path>`

### Example Workflow

1. **Extract images** using `airgap-image-pull.sh`:
   ```bash
   export HELM_CHART_INFO="helm-chart-info.txt"
   bash airgap-image-pull.sh
   ```

2. **Push images** using `airgap-image-push.sh`:
   ```bash
   # Test first with dry-run
   bash airgap-image-push.sh --dry-run
   
   # Then push for real
   bash airgap-image-push.sh
   ```

