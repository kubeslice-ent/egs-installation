#!/bin/bash

# Script to update fake-gpu-operator topology configuration
# This script handles the complete update process including fixing stale per-node topology ConfigMaps

# Don't exit on error - we'll handle errors explicitly
set -o pipefail

# Configuration
NAMESPACE="${NAMESPACE:-egs-gpu-operator}"
KUBECONFIG_FILE="${KUBECONFIG_FILE:-controller}"
CHART_DIR="${CHART_DIR:-charts/fake-gpu-operator/}"
VALUES_FILE="${VALUES_FILE:-fake-gpu-operator-values.yaml}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-60}"

echo "=========================================="
echo "GPU Operator Topology Update Script"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Kubeconfig: $KUBECONFIG_FILE"
echo "Chart: $CHART_DIR"
echo "Values: $VALUES_FILE"
echo "=========================================="

# Step 1: Validate values.yaml exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: Values file '$VALUES_FILE' not found!"
    exit 1
fi

# Step 2: Helm upgrade
echo ""
echo "📦 Step 1: Running Helm upgrade..."
helm upgrade -i gpu-operator "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    -f "$VALUES_FILE" \
    --kubeconfig "$KUBECONFIG_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Helm upgrade completed successfully"
else
    echo "❌ Helm upgrade failed"
    exit 1
fi

# Step 3: Delete stale per-node topology ConfigMaps
echo ""
echo "🗑️  Step 2: Deleting per-node topology ConfigMaps..."
PER_NODE_CMS=$(kubectl get configmap -n "$NAMESPACE" \
    -l node-topology=true \
    --kubeconfig "$KUBECONFIG_FILE" \
    --no-headers 2>/dev/null | wc -l)

if [ "$PER_NODE_CMS" -gt 0 ]; then
    kubectl delete configmap -n "$NAMESPACE" \
        -l node-topology=true \
        --kubeconfig "$KUBECONFIG_FILE" || true
    echo "✅ Deleted $PER_NODE_CMS per-node topology ConfigMap(s)"
else
    echo "ℹ️  No per-node topology ConfigMaps found (may be first run or already deleted)"
fi

# Step 4: Ensure status-updater is running
echo ""
echo "🔄 Step 3: Ensuring status-updater is running..."

# Delete any pending/failed status-updater pods
PENDING_PODS=$(kubectl get pods -n "$NAMESPACE" \
    -l app=status-updater \
    --field-selector=status.phase=Pending \
    --kubeconfig "$KUBECONFIG_FILE" \
    --no-headers 2>/dev/null | awk '{print $1}')

if [ -n "$PENDING_PODS" ]; then
    echo "ℹ️  Cleaning up pending status-updater pods..."
    echo "$PENDING_PODS" | xargs -r kubectl delete pod -n "$NAMESPACE" --kubeconfig "$KUBECONFIG_FILE" || true
fi

# Restart running status-updater
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" \
    -l app=status-updater \
    --field-selector=status.phase=Running \
    --kubeconfig "$KUBECONFIG_FILE" \
    --no-headers 2>/dev/null | awk '{print $1}')

if [ -n "$RUNNING_PODS" ]; then
    echo "ℹ️  Restarting running status-updater pod..."
    echo "$RUNNING_PODS" | xargs -r kubectl delete pod -n "$NAMESPACE" --kubeconfig "$KUBECONFIG_FILE" || true
else
    echo "ℹ️  No running status-updater pods found"
fi

# Wait for status-updater to be ready
echo ""
echo "⏳ Step 4: Waiting for status-updater to be ready..."
WAIT_COUNT=0
MAX_WAIT=12  # 12 * 5 = 60 seconds

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    READY_PODS=$(kubectl get pods -n "$NAMESPACE" \
        -l app=status-updater \
        --field-selector=status.phase=Running \
        --kubeconfig "$KUBECONFIG_FILE" \
        --no-headers 2>/dev/null | grep "1/1" | wc -l)
    
    if [ "$READY_PODS" -gt 0 ]; then
        echo "✅ Status-updater is ready"
        break
    fi
    
    echo "   Waiting... (${WAIT_COUNT}/${MAX_WAIT})"
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "⚠️  Warning: status-updater did not become ready in time"
    echo "   Continuing anyway, but per-node topology ConfigMaps may not be created"
fi

# Wait additional time for topology ConfigMaps to be created
echo ""
echo "⏳ Waiting for topology ConfigMaps to be recreated (10s)..."
sleep 10

# Verify topology ConfigMaps were recreated
TOPOLOGY_CMS=$(kubectl get configmap -n "$NAMESPACE" \
    -l node-topology=true \
    --kubeconfig "$KUBECONFIG_FILE" \
    --no-headers 2>/dev/null | wc -l)

if [ "$TOPOLOGY_CMS" -gt 0 ]; then
    echo "✅ Topology ConfigMaps recreated ($TOPOLOGY_CMS found)"
else
    echo "❌ Warning: No per-node topology ConfigMaps found!"
    echo "   This may be because:"
    echo "   - status-updater is not running (check for node taints/tolerations)"
    echo "   - status-updater hasn't processed nodes yet (wait longer)"
    echo "   - No nodes match the node pool label"
    echo ""
    echo "   Checking status-updater pods..."
    kubectl get pods -n "$NAMESPACE" -l app=status-updater --kubeconfig "$KUBECONFIG_FILE"
fi

# Step 5: Restart device-plugin DaemonSet (only if topology ConfigMaps exist)
echo ""
if [ "$TOPOLOGY_CMS" -gt 0 ]; then
    echo "🔄 Step 5: Restarting device-plugin pods..."
    
    # Clean up any crash-looping or failed device-plugin pods
    FAILED_PODS=$(kubectl get pods -n "$NAMESPACE" \
        -l app=device-plugin \
        --kubeconfig "$KUBECONFIG_FILE" \
        --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error" | awk '{print $1}')
    
    if [ -n "$FAILED_PODS" ]; then
        echo "ℹ️  Cleaning up failed device-plugin pods..."
        echo "$FAILED_PODS" | xargs -r kubectl delete pod -n "$NAMESPACE" --kubeconfig "$KUBECONFIG_FILE" || true
    fi
    
    # Delete all device-plugin pods to restart with new topology
    kubectl delete pod -n "$NAMESPACE" \
        -l app=device-plugin \
        --kubeconfig "$KUBECONFIG_FILE" || true
    
    echo "✅ Device-plugin pods deleted, waiting for recreation..."
    
    # Wait for device-plugin pods to stabilize
    echo ""
    echo "⏳ Step 6: Waiting for device-plugin pods to start (15s)..."
    sleep 15
else
    echo "⚠️  Step 5: Skipping device-plugin restart (no topology ConfigMaps exist)"
    echo "   Fix the topology ConfigMap issue first, then restart device-plugin manually:"
    echo "   kubectl delete pod -n $NAMESPACE -l app=device-plugin --kubeconfig $KUBECONFIG_FILE"
fi

# Step 6: Verify all pods are running
echo ""
echo "🔍 Step 7: Verifying pod status..."
echo ""
kubectl get pods -n "$NAMESPACE" --kubeconfig "$KUBECONFIG_FILE"

# Step 7: Show updated node labels
echo ""
echo "🏷️  Step 8: Checking updated node GPU labels..."
echo ""

NODES_WITH_GPUS=$(kubectl get nodes --kubeconfig "$KUBECONFIG_FILE" \
    -l "nvidia.com/gpu.present=true" \
    --no-headers 2>/dev/null | awk '{print $1}')

if [ -z "$NODES_WITH_GPUS" ]; then
    echo "⚠️  No nodes with GPU labels found yet"
else
    for NODE in $NODES_WITH_GPUS; do
        echo "Node: $NODE"
        kubectl get node "$NODE" --kubeconfig "$KUBECONFIG_FILE" \
            -o jsonpath='{range .metadata.labels}{@}{"\n"}{end}' 2>/dev/null | \
            grep "nvidia.com/gpu" || echo "  (No GPU labels found)"
        echo ""
    done
fi

echo "=========================================="
echo "✅ Update process completed!"
echo "=========================================="
echo ""

# Final status check
DEVICE_PLUGIN_READY=$(kubectl get pods -n "$NAMESPACE" \
    -l app=device-plugin \
    --field-selector=status.phase=Running \
    --kubeconfig "$KUBECONFIG_FILE" \
    --no-headers 2>/dev/null | grep "1/1" | wc -l)

STATUS_UPDATER_READY=$(kubectl get pods -n "$NAMESPACE" \
    -l app=status-updater \
    --field-selector=status.phase=Running \
    --kubeconfig "$KUBECONFIG_FILE" \
    --no-headers 2>/dev/null | grep "1/1" | wc -l)

if [ "$STATUS_UPDATER_READY" -eq 0 ]; then
    echo "⚠️  WARNING: status-updater is NOT running!"
    echo "   This may be due to node taints. Check with:"
    echo "   kubectl describe pod -n $NAMESPACE -l app=status-updater --kubeconfig $KUBECONFIG_FILE"
fi

if [ "$DEVICE_PLUGIN_READY" -eq 0 ]; then
    echo "⚠️  WARNING: No device-plugin pods are ready!"
    echo "   Check logs with:"
    echo "   kubectl logs -n $NAMESPACE -l app=device-plugin --kubeconfig $KUBECONFIG_FILE"
fi

if [ "$STATUS_UPDATER_READY" -gt 0 ] && [ "$DEVICE_PLUGIN_READY" -gt 0 ]; then
    echo "✅ All critical pods are running!"
fi

echo ""
echo "💡 Tips:"
echo "  - Check logs: kubectl logs -n $NAMESPACE <pod-name> --kubeconfig $KUBECONFIG_FILE"
echo "  - View GPU labels: kubectl get nodes --show-labels --kubeconfig $KUBECONFIG_FILE | grep gpu.count"
echo "  - If labels haven't updated, wait 30s and run this script again"
echo "  - To manually restart: kubectl delete pod -n $NAMESPACE -l app=device-plugin --kubeconfig $KUBECONFIG_FILE"


