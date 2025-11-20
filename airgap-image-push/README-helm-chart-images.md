# Helm Chart Image Fetch Script

## Overview

The `helm-image-fetch.sh` script extracts all container images from Helm charts for **kubeslice-egs-helm-ent-prod** charts. It reads chart information from a configuration file and generates a comprehensive list of all container images used in the specified Helm charts.

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

### Required Environment Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `HELM_CHART_INFO` | Path to the chart info file | ✅ Yes | `helm-chart-info.txt` |

## Input File Format

The script reads chart information from a text file with the following format:

```
*****************<repo-url>*************** ******<repo-name>****** ****<chart-name>**** ****<chart-version>****
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-controller-egs 1.15.3
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-worker-egs 1.15.3
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-ui-egs 1.15.3
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

### Example Files

**Specific Version:**
```
*****************<repo-url>*************** ******<repo-name>****** ****<chart-name>**** ****<chart-version>****
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-controller-egs 1.15.3
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-worker-egs 1.15.3
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-ui-egs 1.15.3
```

**Latest Version:**
```
*****************<repo-url>*************** ******<repo-name>****** ****<chart-name>**** ****<chart-version>****
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-controller-egs *
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-worker-egs *
https://kubeslice.aveshalabs.io/repository kubeslice-egs-helm-ent-prod kubeslice-ui-egs *
```

## Usage

### Basic Usage

```bash
# Set required environment variable
export HELM_CHART_INFO="helm-chart-info.txt"

# Run the script
bash helm-image-fetch.sh
```

### Complete Example

```bash
#!/bin/bash

# Set required environment variable
export HELM_CHART_INFO="helm-chart-info.txt"

# Run the script
bash helm-image-fetch.sh
```

## Output

### Output Files

The script generates the following output files:

#### 1. Consolidated File (All Charts Combined)

**Location**: `helm-chart-images.txt` (in the directory where you run the script)

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
- `<DATE>` = Timestamp when script was run (format: `YYYY-MM-DDTHH:MM:SS`)
- `<CHART_NAME>` = One of: `kubeslice-controller-egs`, `kubeslice-worker-egs`, `kubeslice-ui-egs`
- `<CHART_VERSION>` = Chart version (e.g., `1.15.3`)

**Exact File Locations for All 3 Charts:**

When you process all three charts, you'll get these files:

1. **kubeslice-controller-egs**:
   ```
   kubeslice-egs-helm-ent-prod/2025-11-13T11:35:07/kubeslice-controller-egs/1.15.3/helm-chart-images.txt
   ```

2. **kubeslice-worker-egs**:
   ```
   kubeslice-egs-helm-ent-prod/2025-11-13T11:35:07/kubeslice-worker-egs/1.15.3/helm-chart-images.txt
   ```

3. **kubeslice-ui-egs**:
   ```
   kubeslice-egs-helm-ent-prod/2025-11-13T11:35:07/kubeslice-ui-egs/1.15.3/helm-chart-images.txt
   ```

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
    └── 2025-11-13T11:35:07/                 # Date-based directory (timestamp)
        ├── kubeslice-controller-egs/
        │   └── 1.15.3/
        │       └── helm-chart-images.txt     # ✅ Controller chart images
        ├── kubeslice-worker-egs/
        │   └── 1.15.3/
        │       └── helm-chart-images.txt     # ✅ Worker chart images
        └── kubeslice-ui-egs/
            └── 1.15.3/
                └── helm-chart-images.txt     # ✅ UI chart images
```

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

# View specific chart's images
cat kubeslice-egs-helm-ent-prod/2025-11-13T11:35:07/kubeslice-controller-egs/1.15.3/helm-chart-images.txt
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
   helm-chart-info-1.15.3.txt
   helm-chart-info-1.15.4.txt
   helm-chart-info-latest.txt
   ```

3. **Review Output**: Always review `helm-chart-images.txt` to ensure all expected images are present

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

## Image Push Script

The `image-push.sh` script is a companion utility that helps push container images to a target repository. It reads a list of images and performs pull, tag, and push operations.

### Features

- ✅ Pulls images from source registries
- ✅ Tags images with target repository prefix
- ✅ Pushes images to target repository
- ✅ Supports dry-run mode for testing
- ✅ Processes all images from version 1.15.4

### Prerequisites

1. **Docker**: Docker must be installed and running
2. **Docker Login**: You must be logged in to the target repository
   ```bash
   docker login kubeslice.aveshalabs.io
   ```

### Usage

```bash
# Run with actual push
bash image-push.sh

# Run in dry-run mode (no actual operations)
bash image-push.sh --dry-run
```

### Image List

The script contains all images from version 1.15.4, organized by chart:

**Controller Chart Images:**
```bash
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-controller-egs/1.15.4/helm-chart-images.txt
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
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-ui-egs/1.15.4/helm-chart-images.txt
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
cat kubeslice-egs-helm-ent-prod/<DATE>/kubeslice-worker-egs/1.15.4/helm-chart-images.txt
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

The script uses the following default configuration:

- **Target Repository**: `kubeslice.aveshalabs.io`
- **Image Source**: Images are pulled from their original registries (e.g., `harbor.saas1.smart-scaler.io`)
- **Tagging**: Images are tagged as `kubeslice.aveshalabs.io/<image-path>`

### Example Workflow

1. **Extract images** using `helm-image-fetch.sh`:
   ```bash
   export HELM_CHART_INFO="helm-chart-info.txt"
   bash helm-image-fetch.sh
   ```

2. **Push images** using `image-push.sh`:
   ```bash
   # Test first with dry-run
   bash image-push.sh --dry-run
   
   # Then push for real
   bash image-push.sh
   ```

