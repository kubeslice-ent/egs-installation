#!/bin/bash

YAML_FILE="custom-pricing-data.yaml"
CSV_FILE="custom-pricing-data.csv"

# Extract Kubernetes config from YAML
KUBECONFIG=$(yq '.kubernetes.kubeconfig' "$YAML_FILE" | tr -d '"')
KUBECONTEXT=$(yq '.kubernetes.kubecontext' "$YAML_FILE" | tr -d '"')
NAMESPACE=$(yq '.kubernetes.namespace' "$YAML_FILE" | tr -d '"')
SERVICE=$(yq '.kubernetes.service' "$YAML_FILE" | tr -d '"')

# Validate input
if [[ -z "$KUBECONFIG" || -z "$KUBECONTEXT" || -z "$NAMESPACE" || -z "$SERVICE" ]]; then
  echo "❌ Missing required Kubernetes configuration in YAML."
  exit 1
fi

# Get service port from the cluster
SERVICE_PORT=$(kubectl --kubeconfig="$KUBECONFIG" --context="$KUBECONTEXT" -n "$NAMESPACE" get svc "$SERVICE" -o jsonpath='{.spec.ports[0].port}')
if [[ -z "$SERVICE_PORT" ]]; then
  echo "❌ Could not fetch service port for $SERVICE"
  exit 1
fi

# Pick a random free local port
LOCAL_PORT=$(shuf -i 30000-39999 -n 1)

# Start port-forward (leave running in background)
echo "🔄 Port-forwarding $SERVICE:$SERVICE_PORT to localhost:$LOCAL_PORT ..."
kubectl --kubeconfig="$KUBECONFIG" --context="$KUBECONTEXT" -n "$NAMESPACE" port-forward "svc/$SERVICE" "$LOCAL_PORT:$SERVICE_PORT" >/dev/null 2>&1 &

sleep 2

# Set pricing API endpoint
PRICING_API_ENDPOINT="http://localhost:$LOCAL_PORT/api/v1/prices"

# Convert YAML to CSV
echo "cloud_provider,region,component,instance_type,vcpu,price,gpu" > "$CSV_FILE"

yq -o=json '.cloud_providers[]' "$YAML_FILE" | jq -c '.' | while read -r provider; do
  name=$(echo "$provider" | jq -r '.name')
  echo "$provider" | jq -c '.instances[]' | while read -r instance; do
    region=$(echo "$instance" | jq -r '.region')
    component=$(echo "$instance" | jq -r '.component')
    instance_type=$(echo "$instance" | jq -r '.instance_type')
    vcpu=$(echo "$instance" | jq -r '.vcpu')
    price=$(echo "$instance" | jq -r '.price')
    gpu=$(echo "$instance" | jq -r '.gpu')
    echo "$name,$region,$component,$instance_type,$vcpu,$price,$gpu" >> "$CSV_FILE"
  done
done

echo "✅ CSV file created: $CSV_FILE"

# Upload the CSV
echo "📤 Uploading CSV to $PRICING_API_ENDPOINT ..."
curl --location --request POST "$PRICING_API_ENDPOINT" \
--form "file=@$CSV_FILE"

echo "✅ Upload complete. Port-forward will remain active in background."
