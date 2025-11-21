#!/bin/bash

################################################################################
# AirGap Image Pull Script
# 
# This script extracts container images from Helm charts for kubeslice-egs-helm-ent-prod
# It reads chart information from a file and generates a list of all container images
# used in the specified Helm charts.
################################################################################

# Don't exit on error - we want to process all charts even if one fails
set +e

# Input file containing Helm chart information
input_file="${HELM_CHART_INFO}"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
  echo "Error: Input file not found: $input_file"
  echo "Please set HELM_CHART_INFO environment variable to the path of your chart info file."
  exit 1
fi

# Remove extra blank lines from the input file
sed -i '/^[[:space:]]*$/d' "$input_file"

# Initialize output file
OUTPUT_FILE="helm-chart-images.txt"
> "$OUTPUT_FILE"  # Clear/create the output file

# Get current date for directory structure
DATE=$(date +'%Y-%m-%dT%H:%M:%S')

# Track processed charts
PROCESSED_CHARTS=()
FAILED_CHARTS=()
SKIPPED_CHARTS=()

echo "========================================="
echo "AirGap Image Pull Script"
echo "========================================="
echo "Input file: $input_file"
echo "Output file: $OUTPUT_FILE"
echo "Date: $DATE"
echo "========================================="
echo ""

# Iterate over each line in the input file, starting from the second line (skip header)
while IFS= read -r line; do
  # Skip header line or empty lines
  if [[ "$line" =~ ^\*+.*\*+.*\*+.*\*+.*$ ]] || [[ -z "$line" ]]; then
    continue
  fi

  REPO_URL=$(echo "$line" | awk '{print $1}')
  REPO_NAME=$(echo "$line" | awk '{print $2}')
  CHART_NAME=$(echo "$line" | awk '{print $3}')
  CHART_VERSION_INPUT=$(echo "$line" | awk '{print $4}')

  echo "----------------------------------------"
  echo "Processing Chart:"
  echo "  REPO_URL: $REPO_URL"
  echo "  REPO_NAME: $REPO_NAME"
  echo "  CHART_NAME: $CHART_NAME"
  echo "  CHART_VERSION: $CHART_VERSION_INPUT"
  echo "----------------------------------------"

  # Validate that we're only processing kubeslice-egs-helm-ent-prod charts
  if [ "$REPO_URL" != "https://kubeslice.aveshalabs.io/repository" ]; then
    echo "Warning: Skipping non-kubeslice-egs chart. Only processing https://kubeslice.aveshalabs.io/repository"
    SKIPPED_CHARTS+=("$CHART_NAME (wrong repo URL)")
    continue
  fi
  
  # Validate that we're processing prod charts only
  if [[ ! "$REPO_NAME" =~ kubeslice-egs-helm-ent-prod ]]; then
    echo "Warning: Skipping non-prod chart. Only processing kubeslice-egs-helm-ent-prod charts."
    echo "         Found REPO_NAME: $REPO_NAME"
    SKIPPED_CHARTS+=("$CHART_NAME (non-prod)")
    continue
  fi

  # Add Helm repository
  echo "Adding Helm repository..."
  helm repo add "$REPO_NAME" "$REPO_URL/$REPO_NAME/"
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to add Helm repository for $CHART_NAME"
    echo "Skipping this chart and continuing with next chart..."
    FAILED_CHARTS+=("$CHART_NAME (repo add failed)")
    continue
  fi

  # Update Helm repositories
  helm repo update "$REPO_NAME"

  # Determine chart version
  if [ "$CHART_VERSION_INPUT" == "*" ]; then
    # Fetch the latest version
    echo "Fetching latest version..."
    helm pull "$REPO_NAME/$CHART_NAME" --devel --untar
    
    if [ $? -ne 0 ]; then
      echo "Error: Failed to pull chart to determine latest version for $CHART_NAME"
      echo "Skipping this chart and continuing with next chart..."
      helm repo remove "$REPO_NAME" || true
      FAILED_CHARTS+=("$CHART_NAME (version detection failed)")
      continue
    fi
    
    CHART_VERSION=$(yq -r '.version' "$CHART_NAME/Chart.yaml")
    rm -rf "$CHART_NAME"
  else
    CHART_VERSION="$CHART_VERSION_INPUT"
  fi

  echo "Using CHART_VERSION: $CHART_VERSION"

  # Create output directory structure
  OUTPUT_DIR="$REPO_NAME/$DATE/$CHART_NAME/$CHART_VERSION"
  mkdir -p "$OUTPUT_DIR"

  # Search and pull the chart
  echo "Searching for chart..."
  helm search repo "$REPO_NAME/$CHART_NAME" --version "$CHART_VERSION" --devel

  # Clean up any existing chart directory before pulling
  if [ -d "./$CHART_NAME" ]; then
    echo "Cleaning up existing chart directory..."
    rm -rf "./$CHART_NAME"
  fi

  echo "Pulling chart..."
  helm pull "$REPO_NAME/$CHART_NAME" --version "$CHART_VERSION" --devel --untar
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to pull chart $CHART_NAME version $CHART_VERSION"
    echo "Skipping this chart and continuing with next chart..."
    helm repo remove "$REPO_NAME" || true
    FAILED_CHARTS+=("$CHART_NAME v$CHART_VERSION (pull failed)")
    continue
  fi

  # Process based on chart type
  if [ "$CHART_NAME" == "kubeslice-controller-egs" ]; then
    echo "Processing kubeslice-controller-egs chart..."
    
    # Extract images from main chart
    (helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      --set kubeslice.controller.endpoint="your-endpoint" \
      | yq '... | select(.image? // (tag == "!!str" and (. | contains("--") and . | contains("-image=")))) | .image? // (split(" ") | .[] | select(contains("--") and contains("-image=")) | split("=") | .[1])') | sort -u | sed '/^---/d' >> "$OUTPUT_FILE"
    
    (helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      --set kubeslice.controller.endpoint="your-endpoint" \
      | yq '... | select(.image? // (tag == "!!str" and (. | contains("--") and . | contains("-image=")))) | .image? // (split(" ") | .[] | select(contains("--") and contains("-image=")) | split("=") | .[1])') | sort -u | sed '/^---/d' >> "$OUTPUT_DIR/helm-chart-images.txt"
    
    # Process kubetally subchart if it exists
    if [ -f "$CHART_NAME/charts/kubetally/Chart.yaml" ]; then
      echo "Processing kubetally subchart..."
      KUBETALLY_CHART_VERSION=$(yq -r '.version' "$CHART_NAME/charts/kubetally/Chart.yaml")
      # Extract global.imageRegistry and dev.imageRegistry from parent chart values.yaml
      GLOBAL_IMAGE_REGISTRY=$(yq -r '.global.imageRegistry' ./$CHART_NAME/values.yaml)
      DEV_IMAGE_REGISTRY=$(yq -r '.dev.imageRegistry // .global.imageRegistry' ./$CHART_NAME/values.yaml)
      
      (helm template "$CHART_NAME/charts/kubetally/" \
        --version "$KUBETALLY_CHART_VERSION" \
        -f $CHART_NAME/charts/kubetally/values.yaml \
        -f ./$CHART_NAME/values.yaml \
        --set global.imageRegistry="$GLOBAL_IMAGE_REGISTRY" \
        --set dev.imageRegistry="$DEV_IMAGE_REGISTRY" \
        --set global.kubeTally.postgresSecretName="my-postgres-secret" \
        --set global.kubeTally.postgresUser="my-postgres-user" \
        --set global.kubeTally.postgresPassword="my-password" \
        --set global.kubeTally.postgresAddr="localhost" \
        --set global.kubeTally.postgresPort="5432" \
        --set global.kubeTally.postgresDB="mydb" \
        --set global.kubeTally.postgresSslmode="disable" \
        --set global.kubeTally.prometheusUrl="http://dummy-prometheus:9090" \
        --set global.kubeTally.pricingUpdaterSchedule="0 0 * * *" \
        --set global.kubeTally.priceUpdaterWorkers="5" \
        --set-string global.kubeTally.pricingUpdaterCloudProviders="aws\,azure\,gcp" \
        --set global.kubeTally.dataProcessingHoursAgo="24" \
        | yq '... | select(.image? // (tag == "!!str" and (. | contains("--") and . | contains("-image=")))) | .image? // (split(" ") | .[] | select(contains("--") and contains("-image=")) | split("=") | .[1])') | sort -u | sed '/^---/d' >> "$OUTPUT_FILE"
      
      (helm template "$CHART_NAME/charts/kubetally/" \
        --version "$KUBETALLY_CHART_VERSION" \
        -f $CHART_NAME/charts/kubetally/values.yaml \
        -f ./$CHART_NAME/values.yaml \
        --set global.imageRegistry="$GLOBAL_IMAGE_REGISTRY" \
        --set dev.imageRegistry="$DEV_IMAGE_REGISTRY" \
        --set global.kubeTally.postgresSecretName="my-postgres-secret" \
        --set global.kubeTally.postgresUser="my-postgres-user" \
        --set global.kubeTally.postgresPassword="my-password" \
        --set global.kubeTally.postgresAddr="localhost" \
        --set global.kubeTally.postgresPort="5432" \
        --set global.kubeTally.postgresDB="mydb" \
        --set global.kubeTally.postgresSslmode="disable" \
        --set global.kubeTally.prometheusUrl="http://dummy-prometheus:9090" \
        --set global.kubeTally.pricingUpdaterSchedule="0 0 * * *" \
        --set global.kubeTally.priceUpdaterWorkers="5" \
        --set-string global.kubeTally.pricingUpdaterCloudProviders="aws\,azure\,gcp" \
        --set global.kubeTally.dataProcessingHoursAgo="24" \
        | yq '... | select(.image? // (tag == "!!str" and (. | contains("--") and . | contains("-image=")))) | .image? // (split(" ") | .[] | select(contains("--") and contains("-image=")) | split("=") | .[1])') | sort -u | sed '/^---/d' >> "$OUTPUT_DIR/helm-chart-images.txt"
    fi

    # Deduplicate images (prefer aveshadev over docker.io)
    awk -F'/' '{image_name=$NF;if(!seen[image_name]++){order[NR]=$0}else if($0~/^aveshadev\//){for(i in order){if(order[i]~image_name&&order[i]~/^docker\.io\//){order[i]=$0;next}}}}END{for(i=1;i<=NR;i++){if(order[i]!=""){print order[i]}}}' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    
    awk -F'/' '{image_name=$NF;if(!seen[image_name]++){order[NR]=$0}else if($0~/^aveshadev\//){for(i in order){if(order[i]~image_name&&order[i]~/^docker\.io\//){order[i]=$0;next}}}}END{for(i=1;i<=NR;i++){if(order[i]!=""){print order[i]}}}' "$OUTPUT_DIR/helm-chart-images.txt" > "$OUTPUT_DIR/helm-chart-images.txt.tmp"
    mv "$OUTPUT_DIR/helm-chart-images.txt.tmp" "$OUTPUT_DIR/helm-chart-images.txt"

  elif [ "$CHART_NAME" == "kubeslice-worker-egs" ]; then
    echo "Processing kubeslice-worker-egs chart..."
    
    # Check if imagePullSecrets has valid keys or values
    has_keys=$(yq '.imagePullSecrets | type' ./$CHART_NAME/values.yaml 2>/dev/null)
    
    if [ "$has_keys" = "!!null" ] || [ -z "$has_keys" ]; then
      echo "imagePullSecrets is empty/null. Adding dummy values."
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set imagePullSecrets.username=dummyuser \
        --set imagePullSecrets.password=dummypassword \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test(".*/.*:.+"))) or (. | tostring | test(".*/.*:.+"))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$' | grep -vE '^[a-zA-Z0-9._/-]*:[a-zA-Z]+$' | sort -u >> "$OUTPUT_FILE"
      
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set imagePullSecrets.username=dummyuser \
        --set imagePullSecrets.password=dummypassword \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test(".*/.*:.+"))) or (. | tostring | test(".*/.*:.+"))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$' | grep -vE '^[a-zA-Z0-9._/-]*:[a-zA-Z]+$' | sort -u >> "$OUTPUT_DIR/helm-chart-images.txt"
      
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set imagePullSecrets.username=dummyuser \
        --set imagePullSecrets.password=dummypassword \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test("^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)+(:[a-zA-Z0-9._-]+)?$")))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+(:[a-zA-Z0-9._-]+)?$' | grep -vE ':(true|false|[a-zA-Z]+)$' | sort -u >> "$OUTPUT_FILE"
      
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set imagePullSecrets.username=dummyuser \
        --set imagePullSecrets.password=dummypassword \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test("^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)+(:[a-zA-Z0-9._-]+)?$")))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+(:[a-zA-Z0-9._-]+)?$' | grep -vE ':(true|false|[a-zA-Z]+)$' | sort -u >> "$OUTPUT_DIR/helm-chart-images.txt"
    else
      echo "imagePullSecrets has valid keys. Proceeding without dummy values."
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test(".*/.*:.+"))) or (. | tostring | test(".*/.*:.+"))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$' | grep -vE '^[a-zA-Z0-9._/-]*:[a-zA-Z]+$' | sort -u >> "$OUTPUT_FILE"
      
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test(".*/.*:.+"))) or (. | tostring | test(".*/.*:.+"))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$' | grep -vE '^[a-zA-Z0-9._/-]*:[a-zA-Z]+$' | sort -u >> "$OUTPUT_DIR/helm-chart-images.txt"
      
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test("^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)+(:[a-zA-Z0-9._-]+)?$")))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+(:[a-zA-Z0-9._-]+)?$' | grep -vE ':(true|false|[a-zA-Z]+)$' | sort -u >> "$OUTPUT_FILE"
      
      helm template "$REPO_NAME/$CHART_NAME" \
        --version "$CHART_VERSION" \
        -f ./$CHART_NAME/values.yaml \
        --set cluster.name=dummy-cluster \
        --set cluster.endpoint=https://dummy-endpoint.example.com \
        | yq '... | select(.image? or (.value? and (.value | tostring | test("^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)+(:[a-zA-Z0-9._-]+)?$")))) | (.image? // .value? // .)' | grep -E '^[a-zA-Z0-9._/-]+/[a-zA-Z0-9._-]+(:[a-zA-Z0-9._-]+)?$' | grep -vE ':(true|false|[a-zA-Z]+)$' | sort -u >> "$OUTPUT_DIR/helm-chart-images.txt"
    fi
    
    # Extract metrics-server images from preinstall configmap
    helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      --set cluster.name=dummy-cluster \
      --set cluster.endpoint=https://dummy-endpoint.example.com \
      | yq '.. | select(has("data") and has("metadata") and .metadata.name == "release-name-preinstall-configmap") | .data["metrics-server.yaml"]' | yq '.. | select(has("image") and (.image | contains("metrics-server"))) | .image' >> "$OUTPUT_FILE"
    
    helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      --set cluster.name=dummy-cluster \
      --set cluster.endpoint=https://dummy-endpoint.example.com \
      | yq '.. | select(has("data") and has("metadata") and .metadata.name == "release-name-preinstall-configmap") | .data["metrics-server.yaml"]' | yq '.. | select(has("image") and (.image | contains("metrics-server"))) | .image' >> "$OUTPUT_DIR/helm-chart-images.txt"
    
    # Process NSM subchart if it exists
    if [ -f "$CHART_NAME/charts/nsm/Chart.yaml" ]; then
      echo "Processing NSM subchart..."
      NSM_CHART_VERSION=$(yq -r '.version' "$CHART_NAME/charts/nsm/Chart.yaml")
      (helm template "$CHART_NAME/charts/nsm/" \
        --version "$NSM_CHART_VERSION" \
        -f $CHART_NAME/charts/nsm/values.yaml \
        --set global.profile.openshift="false" \
        | yq '... | select(.image? or (.value? and (.value | type == "!!str") and (.value | test("docker.io/"))) or (has("env") and (.env[] | select(.value? and (.value | test("docker.io/")))))) | (.image? // .value // (.env[]?.value? // "")) | select(.)' | grep -Eo 'docker\.io\/[^:]+:[^"]+'| sort -u) >> "$OUTPUT_FILE"
      
      (helm template "$CHART_NAME/charts/nsm/" \
        --version "$NSM_CHART_VERSION" \
        -f $CHART_NAME/charts/nsm/values.yaml \
        --set global.profile.openshift="false" \
        | yq '... | select(.image? or (.value? and (.value | type == "!!str") and (.value | test("docker.io/"))) or (has("env") and (.env[] | select(.value? and (.value | test("docker.io/")))))) | (.image? // .value // (.env[]?.value? // "")) | select(.)' | grep -Eo 'docker\.io\/[^:]+:[^"]+'| sort -u) >> "$OUTPUT_DIR/helm-chart-images.txt"
    fi

    # Deduplicate images
    awk -F'/' '{image_name=$NF;if(!seen[image_name]++){order[NR]=$0}else if($0~/^aveshadev\//){for(i in order){if(order[i]~image_name&&order[i]~/^docker\.io\//){order[i]=$0;next}}}}END{for(i=1;i<=NR;i++){if(order[i]!=""){print order[i]}}}' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    
    awk -F'/' '{image_name=$NF;if(!seen[image_name]++){order[NR]=$0}else if($0~/^aveshadev\//){for(i in order){if(order[i]~image_name&&order[i]~/^docker\.io\//){order[i]=$0;next}}}}END{for(i=1;i<=NR;i++){if(order[i]!=""){print order[i]}}}' "$OUTPUT_DIR/helm-chart-images.txt" > "$OUTPUT_DIR/helm-chart-images.txt.tmp"
    mv "$OUTPUT_DIR/helm-chart-images.txt.tmp" "$OUTPUT_DIR/helm-chart-images.txt"

  elif [ "$CHART_NAME" == "kubeslice-ui-egs" ]; then
    echo "Processing kubeslice-ui-egs chart..."
    
    # Default extraction for UI chart
    helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      | yq '.. | select(has("image")).image // select(has("value")).value | select(test("^[^:]+/[^:]+:[^:]+$"))' | sort -u | sed '/^---/d' >> "$OUTPUT_FILE"
    
    helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      | yq '.. | select(has("image")).image // select(has("value")).value | select(test("^[^:]+/[^:]+:[^:]+$"))' | sort -u | sed '/^---/d' >> "$OUTPUT_DIR/helm-chart-images.txt"
  else
    echo "Warning: Unknown chart type '$CHART_NAME'. Using default extraction method."
    helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      | yq '.. | select(has("image")).image // select(has("value")).value | select(test("^[^:]+/[^:]+:[^:]+$"))' | sort -u | sed '/^---/d' >> "$OUTPUT_FILE"
    
    helm template "$REPO_NAME/$CHART_NAME" \
      --version "$CHART_VERSION" \
      -f ./$CHART_NAME/values.yaml \
      | yq '.. | select(has("image")).image // select(has("value")).value | select(test("^[^:]+/[^:]+:[^:]+$"))' | sort -u | sed '/^---/d' >> "$OUTPUT_DIR/helm-chart-images.txt"
  fi

  # Cleanup
  echo "Cleaning up..."
  helm repo remove "$REPO_NAME" || true
  rm -rf "./$CHART_NAME"
  
  PROCESSED_CHARTS+=("$CHART_NAME v$CHART_VERSION")
  echo "✅ Completed processing $CHART_NAME"
  echo ""

done < <(tail -n +2 "$input_file")

# Final deduplication and sorting
echo "========================================="
echo "Finalizing output..."
sort -u "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

IMAGE_COUNT=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo "0")
echo "========================================="
echo "Script Execution Summary"
echo "========================================="
echo "✅ Successfully processed charts: ${#PROCESSED_CHARTS[@]}"
if [ ${#PROCESSED_CHARTS[@]} -gt 0 ]; then
  for chart in "${PROCESSED_CHARTS[@]}"; do
    echo "   - $chart"
  done
fi

if [ ${#FAILED_CHARTS[@]} -gt 0 ]; then
  echo ""
  echo "❌ Failed charts: ${#FAILED_CHARTS[@]}"
  for chart in "${FAILED_CHARTS[@]}"; do
    echo "   - $chart"
  done
fi

if [ ${#SKIPPED_CHARTS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Skipped charts: ${#SKIPPED_CHARTS[@]}"
  for chart in "${SKIPPED_CHARTS[@]}"; do
    echo "   - $chart"
  done
fi

echo ""
echo "Total unique images found: $IMAGE_COUNT"
echo "Output file: $OUTPUT_FILE"
if [ -d "kubeslice-egs-helm-ent-prod/$DATE" ]; then
  echo "Output directories: kubeslice-egs-helm-ent-prod/$DATE/"
  echo ""
  echo "Per-chart output files:"
  find "kubeslice-egs-helm-ent-prod/$DATE" -name "helm-chart-images.txt" -type f | while read file; do
    count=$(wc -l < "$file" 2>/dev/null || echo "0")
    echo "   - $file ($count images)"
  done
fi
echo "========================================="

