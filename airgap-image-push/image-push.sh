#!/bin/bash

# Define the target repository
REPO="kubeslice.aveshalabs.io"

# List of Docker images with their tags (from version 1.15.4)
# Images are from docker.io/aveshasystems/ registry
IMAGES=(
"docker.io/aveshasystems/alpine-k8s:1.0.1"
"docker.io/aveshasystems/alpine-k8s:1.22.9"
"docker.io/aveshasystems/brancz-kube-rbac-proxy:v0.18.0"
"docker.io/aveshasystems/cmd-admission-webhook-k8s:1.7.3"
"docker.io/aveshasystems/cmd-exclude-prefixes-k8s:1.5.5"
"docker.io/aveshasystems/cmd-forwarder-kernel:1.0.9"
"docker.io/aveshasystems/cmd-nsc:1.5.14"
"docker.io/aveshasystems/cmd-nsc-init:1.5.9"
"docker.io/aveshasystems/cmd-nse-vl3:1.0.6"
"docker.io/aveshasystems/cmd-nsmgr:1.5.7"
"docker.io/aveshasystems/cmd-registry-k8s:1.5.6"
"docker.io/aveshasystems/dns:0.1.4"
"docker.io/aveshasystems/egs-agent:1.0.3"
"docker.io/aveshasystems/egs-core-apis:1.14.4"
"docker.io/aveshasystems/egs-gpu-agent:1.0.0"
"docker.io/aveshasystems/envoygateway:v1.0.3"
"docker.io/aveshasystems/envoyproxy-distroless:1.30.4"
"docker.io/aveshasystems/gateway-certs-generator:0.8.0"
"docker.io/aveshasystems/gpr-manager:1.14.3"
"docker.io/aveshasystems/gw-sidecar:1.0.5"
"docker.io/aveshasystems/inventory-manager:1.14.3"
"docker.io/aveshasystems/kserve-controller:v0.14.0"
"docker.io/aveshasystems/kserve-huggingfaceserver:v0.14.0"
"docker.io/aveshasystems/kserve-lgbserver:v0.14.0"
"docker.io/aveshasystems/kserve-modelmesh-controller:v0.12.0"
"docker.io/aveshasystems/kserve-paddleserver:v0.14.0"
"docker.io/aveshasystems/kserve-pmmlserver:v0.14.1"
"docker.io/aveshasystems/kserve-sklearnserver:v0.14.0"
"docker.io/aveshasystems/kserve-storage-initializer:v0.14.0"
"docker.io/aveshasystems/kserve-xgbserver:v0.14.0"
"docker.io/aveshasystems/kube-aiops-operator:1.15.3"
"docker.io/aveshasystems/kubebuilder-kube-rbac-proxy:0.18.2"
"docker.io/aveshasystems/kubeslice-api-gw-ent-egs:1.15.4"
"docker.io/aveshasystems/kubeslice-controller-ent-egs:1.15.4"
"docker.io/aveshasystems/kubeslice-router-sidecar:1.4.6"
"docker.io/aveshasystems/kubeslice-ui-ent-egs:1.15.4"
"docker.io/aveshasystems/kubeslice-ui-proxy:1.12.0"
"docker.io/aveshasystems/kubeslice-ui-v2-ent-egs:1.15.4"
"docker.io/aveshasystems/kubetally-report:1.13.5"
"docker.io/aveshasystems/metrics-server:v0.6.2"
"docker.io/aveshasystems/minio:RELEASE.2025-09-07T16-13-09Z-cpuv1"
"docker.io/aveshasystems/netops:0.2.2"
"docker.io/aveshasystems/nvidia-tritonserver:23.04-py3"
"docker.io/aveshasystems/nvidia-tritonserver:23.05-py3"
"docker.io/aveshasystems/openvino-model_server:2022.2"
"docker.io/aveshasystems/openvpn-client.alpine:1.0.4"
"docker.io/aveshasystems/openvpn-server.alpine:1.0.4"
"docker.io/aveshasystems/price-updater:1.12.3"
"docker.io/aveshasystems/pricing-service:1.13.3"
"docker.io/aveshasystems/proxyv2:1.16.1"
"docker.io/aveshasystems/pytorch-torchserve:0.7.1-cpu"
"docker.io/aveshasystems/pytorch-torchserve-kfs:0.9.0"
"docker.io/aveshasystems/queue-manager:1.13.3"
"docker.io/aveshasystems/seldonio-mlserver:1.3.2"
"docker.io/aveshasystems/seldonio-mlserver:1.5.0"
"docker.io/aveshasystems/sig-storage-csi-node-driver-registrar:v2.8.1"
"docker.io/aveshasystems/slicegw-edge:1.0.6"
"docker.io/aveshasystems/spiffe-csi-driver:0.2.7"
"docker.io/aveshasystems/spiffe-spire-controller-manager:0.2.3"
"docker.io/aveshasystems/spire-agent:1.9.2"
"docker.io/aveshasystems/spire-server:1.9.2"
"docker.io/aveshasystems/tensorflow-serving:2.6.2"
"docker.io/aveshasystems/wait-for-it:1.0.2"
"docker.io/aveshasystems/wireguard-client.alpine:1.0.0"
"docker.io/aveshasystems/wireguard-server.alpine:1.0.0"
"docker.io/aveshasystems/worker-installer:1.9.0"
"docker.io/aveshasystems/worker-operator-ent-egs:1.15.4"
)

# Define the dry-run flag
DRY_RUN=false

# Process command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --dry-run)
        DRY_RUN=true
        shift
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Function to pull, tag, and push the images
function pull_tag_and_push_image() {
    local IMAGE="$1"
    local TAGGED_IMAGE="$REPO/$(echo $IMAGE | cut -d '/' -f 3-)"
    echo "Pulling $IMAGE"
    if ! $DRY_RUN; then
        docker pull $IMAGE
    fi
    echo "Tagging $IMAGE as $TAGGED_IMAGE"
    if ! $DRY_RUN; then
        docker tag $IMAGE $TAGGED_IMAGE
        docker push $TAGGED_IMAGE
    fi
}

# Loop through the images, pull, tag, and push them to the repository
for IMAGE in "${IMAGES[@]}"; do
    pull_tag_and_push_image "$IMAGE"
done
