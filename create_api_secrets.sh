#!/bin/bash

# Check if the script is running in Bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Error: This script must be run in a Bash shell."
    echo "Please run the script using: bash $0"
    exit 1
else
    echo "✅ Bash shell detected. Version: $BASH_VERSION"
fi

# Extract major and minor version numbers
BASH_MAJOR_VERSION=$(echo "$BASH_VERSION" | cut -d'.' -f1)
BASH_MINOR_VERSION=$(echo "$BASH_VERSION" | cut -d'.' -f2)

# Check if Bash version is at least 5.0.0
if [ "$BASH_MAJOR_VERSION" -lt 5 ] || { [ "$BASH_MAJOR_VERSION" -eq 5 ] && [ "$BASH_MINOR_VERSION" -lt 0 ]; }; then
    echo "❌ Error: Bash version 5.0.0 or higher is required."
    echo "You are using Bash $BASH_VERSION"
    echo "Please install a newer version of Bash."
    exit 1
else
    echo "✅ Bash version is sufficient: $BASH_VERSION"
fi


# Function to determine saName based on role
generate_sa_name() {
    local role="$1"
    local slice_name="$2"

    case "$role" in
        Editor)
            echo "kubeslice-rbac-rw-slice-${slice_name}"
            ;;
        Viewer)
            echo "kubeslice-rbac-ro-slice-${slice_name}"
            ;;
        Owner)
            echo "kubeslice-rbac-rw-external-apis"
            ;;
        *)
            echo "❌ Error: Invalid role '$role'. Expected 'Editor', 'Viewer', or 'Owner'."
            exit 1
            ;;
    esac
}

# Function to generate MD5 hash of a string
generate_md5() {
    echo -n "$1" | md5sum | awk '{print $1}'
}

# Function: Check prerequisites
prerequisite_check() {
    echo "🚀 Starting prerequisite check..."
    local prerequisites_met=true

    # Minimum required versions
    local MIN_YQ_VERSION="4.44.2"
    local MIN_HELM_VERSION="3.15.0"
    local MIN_JQ_VERSION="1.6"
    local MIN_KUBECTL_VERSION="1.23.6"

    # Function to check versions
    check_version() {
        local tool="$1"
        local min_version="$2"
        local installed_version="$3"

        if [[ $(echo -e "$min_version\n$installed_version" | sort -V | head -n1) != "$min_version" ]]; then
            echo -e "\n❌ Error: $tool version $installed_version is below the required version $min_version."
            prerequisites_met=false
        else
            echo "✔️ $tool version $installed_version meets or exceeds the requirement."
        fi
    }

    # Check yq
    if ! command -v yq &>/dev/null; then
        echo "❌ Error: yq is not installed."
        prerequisites_met=false
    else
        installed_version=$(yq --version | awk '{print $NF}')
        check_version "yq" "$MIN_YQ_VERSION" "$installed_version"
    fi

    # Check helm
    if ! command -v helm &>/dev/null; then
        echo "❌ Error: helm is not installed."
        prerequisites_met=false
    else
        installed_version=$(helm version --short | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tr -d 'v')
        check_version "helm" "$MIN_HELM_VERSION" "$installed_version"
    fi

    # Check jq
    if ! command -v jq &>/dev/null; then
        echo "❌ Error: jq is not installed."
        prerequisites_met=false
    else
        installed_version=$(jq --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
        check_version "jq" "$MIN_JQ_VERSION" "$installed_version"
    fi

    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        echo "❌ Error: kubectl is not installed."
        prerequisites_met=false
    else
        installed_version=$(kubectl version --client --output=json | jq -r .clientVersion.gitVersion | tr -d 'v')
        check_version "kubectl" "$MIN_KUBECTL_VERSION" "$installed_version"
    fi

    if [ "$prerequisites_met" = false ]; then
        echo "❌ Please install or update the required tools and try again."
        exit 1
    fi

    echo "✔️ All prerequisites met."
}

# Help function
print_help() {
    echo "Usage: $0 -f <input-yaml-file> -n <namespace> -k <kubeconfig> -c <kubecontext>"
    echo "Mandatory Parameters:"
    echo "  -f <input-yaml-file>   Path to the YAML file containing secret definitions"
    echo "  -n <namespace>         Kubernetes namespace where secrets should be created"
    echo "  -k <kubeconfig>        Path to the Kubernetes kubeconfig file (must be provided)"
    echo "  -c <kubecontext>       Kubernetes context to use (must be provided)"
    echo "Example:"
    echo "  ./create_k8s_secrets.sh -f input.yaml -n my-namespace -k ~/.kube/config -c my-context"
    exit 1
}

# Parse command-line arguments
while getopts "f:n:k:c:h" opt; do
    case ${opt} in
        f) INPUT_YAML="${OPTARG}" ;;
        n) NAMESPACE="${OPTARG}" ;;
        k) CMD_KUBECONFIG="${OPTARG}" ;;
        c) CMD_KUBECONTEXT="${OPTARG}" ;;
        h) print_help ;;
        *) print_help ;;
    esac
done

# Run prerequisite check
prerequisite_check

# Validate input arguments
if [[ -z "$INPUT_YAML" || -z "$NAMESPACE" || -z "$CMD_KUBECONFIG" || -z "$CMD_KUBECONTEXT" ]]; then
    echo "❌ Error: Missing required parameters."
    print_help
fi

# Validate if the input YAML file exists
if [[ ! -f "$INPUT_YAML" ]]; then
    echo "❌ Error: Input YAML file '$INPUT_YAML' does not exist."
    exit 1
fi

# Read global values from YAML
global_controller_namespace=$(yq e '.global_controller_namespace // "kubeslice-controller"' "$INPUT_YAML")
global_project_namespace=$(yq e '.global_project_namespace // "kubeslice-avesha"' "$INPUT_YAML")
global_role=$(yq e '.global_role // "Viewer"' "$INPUT_YAML")
global_sliceName=$(yq e '.global_sliceName // "devops"' "$INPUT_YAML")
global_tokenTtlSeconds=$(yq e '.global_tokenTtlSeconds // "900"' "$INPUT_YAML")
global_userName=$(yq e '.global_userName // "Admin"' "$INPUT_YAML")
global_validUntil=$(yq e '.global_validUntil // "2025-02-28"' "$INPUT_YAML")

# Build kubectl command
KUBECTL_CMD="kubectl --kubeconfig=$CMD_KUBECONFIG --context=$CMD_KUBECONTEXT"

# Process secrets from YAML
num_secrets=$(yq e '.secrets | length' "$INPUT_YAML")
if [ "$num_secrets" -eq 0 ]; then
    echo "❌ Error: No secrets found in the input YAML."
    exit 1
fi

# Iterate over each secret
for i in $(seq 0 $((num_secrets - 1))); do
    name=$(yq e ".secrets[$i].name" "$INPUT_YAML")
    apiKey=$(uuidgen)
    secret_name=$(generate_md5 "$apiKey")
    namespace=$(yq e ".secrets[$i].namespace // \"$global_controller_namespace\"" "$INPUT_YAML")
    project_namespace=$(yq e ".secrets[$i].project_namespace // \"$global_project_namespace\"" "$INPUT_YAML")
    role=$(yq e ".secrets[$i].role // \"$global_role\"" "$INPUT_YAML")
    saName=$(generate_sa_name "$role" "$global_sliceName")
    sliceName=$(yq e ".secrets[$i].sliceName // \"$global_sliceName\"" "$INPUT_YAML")
    tokenTtlSeconds=$(yq e ".secrets[$i].tokenTtlSeconds // \"$global_tokenTtlSeconds\"" "$INPUT_YAML")
    userName=$(yq e ".secrets[$i].userName // \"$global_userName\"" "$INPUT_YAML")
    validUntil=$(yq e ".secrets[$i].validUntil // \"$global_validUntil\"" "$INPUT_YAML")


    # Create Kubernetes secret with labels
    $KUBECTL_CMD create secret generic "$secret_name" \
        --from-literal=apiKey="$apiKey" \
        --from-literal=name="$name" \
        --from-literal=role="$role" \
        --from-literal=saName="$saName" \
        --from-literal=sliceName="$sliceName" \
        --from-literal=tokenTtlSeconds="$tokenTtlSeconds" \
        --from-literal=userName="$userName" \
        --from-literal=validUntil="$validUntil" \
        -n "$NAMESPACE" --dry-run=client -o yaml | $KUBECTL_CMD apply -f -

    # Apply label separately to avoid validation errors
    $KUBECTL_CMD label secret "$secret_name" \
        "kubeslice.io/project-namespace=$project_namespace" \
        "kubeslice.io/sliceName=$sliceName" \
        "kubeslice.io/type=api-key" \
        --overwrite -n "$NAMESPACE"


    echo "✅ Secret '$secret_name' created successfully in namespace '$NAMESPACE'."
done
