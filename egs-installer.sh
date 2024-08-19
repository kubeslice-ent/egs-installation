#!/bin/bash

# Check if the script is running in Bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Error: This script must be run in a Bash shell."
    echo "Please run the script using: bash script_name.sh"
    exit 1
else
    echo "✅ Bash shell detected. Version: $BASH_VERSION"
fi

# Exit immediately if a command exits with a non-zero status
set -e

# Print introductory statement
echo "========================================="
echo "           EGS Installer Script          "
echo "========================================="
echo ""

# Function to show a waiting indicator with a timeout
wait_with_dots() {
    local duration=${1:-30}
    local message="$2"
    echo -n "$message"
    trap "exit" INT
    for ((i=0; i<$duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo ""
    trap - INT
}

prerequisite_check() {
    echo "🚀 Starting prerequisite check..."
    echo "Checking prerequisites..."
    local prerequisites_met=true

    # Minimum required versions
    local MIN_YQ_VERSION="4.0.0"
    local MIN_HELM_VERSION="3.15.0"
    local MIN_JQ_VERSION="1.6"
    local MIN_KUBECTL_VERSION="1.20.0"

    # Check yq
    if ! command -v yq &> /dev/null; then
        echo -e "\n❌ Error: yq is not installed or not available in PATH."
        prerequisites_met=false
    else
        echo "✔️ yq is installed."
        installed_version=$(yq --version | awk '{print $NF}')
        if [[ $(echo -e "$MIN_YQ_VERSION\n$installed_version" | sort -V | head -n1) != "$MIN_YQ_VERSION" ]]; then
            echo -e "\n❌ Error: yq version $installed_version is below the minimum required version $MIN_YQ_VERSION."
            prerequisites_met=false
        else
            echo "✔️ yq version $installed_version meets or exceeds the requirement."
        fi
    fi

    # Check helm
    if ! command -v helm &> /dev/null; then
        echo -e "\n❌ Error: helm is not installed or not available in PATH."
        prerequisites_met=false
    else
        echo "✔️ helm is installed."
        installed_version=$(helm version --short | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tr -d 'v')
        if [[ $(echo -e "$MIN_HELM_VERSION\n$installed_version" | sort -V | head -n1) != "$MIN_HELM_VERSION" ]]; then
            echo -e "\n❌ Error: helm version $installed_version is below the minimum required version $MIN_HELM_VERSION."
            prerequisites_met=false
        else
            echo "✔️ helm version $installed_version meets or exceeds the requirement."
        fi
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        echo -e "\n❌ Error: jq is not installed or not available in PATH."
        prerequisites_met=false
    else
        echo "✔️ jq is installed."
        installed_version=$(jq --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
        if [[ $(echo -e "$MIN_JQ_VERSION\n$installed_version" | sort -V | head -n1) != "$MIN_JQ_VERSION" ]]; then
            echo -e "\n❌ Error: jq version $installed_version is below the minimum required version $MIN_JQ_VERSION."
            prerequisites_met=false
        else
            echo "✔️ jq version $installed_version meets or exceeds the requirement."
        fi
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "\n❌ Error: kubectl is not installed or not available in PATH."
        prerequisites_met=false
    else
        echo "✔️ kubectl is installed."
        installed_version=$(kubectl version --client --output=json | jq -r .clientVersion.gitVersion | tr -d 'v')
        if [[ $(echo -e "$MIN_KUBECTL_VERSION\n$installed_version" | sort -V | head -n1) != "$MIN_KUBECTL_VERSION" ]]; then
            echo -e "\n❌ Error: kubectl version $installed_version is below the minimum required version $MIN_KUBECTL_VERSION."
            prerequisites_met=false
        else
            echo "✔️ kubectl version $installed_version meets or exceeds the requirement."
        fi
    fi

    if [ "$prerequisites_met" = false ]; then
        echo "❌ Please install the missing prerequisites or update to the required versions and try again."
        exit 1
    fi

    echo "✔️ All prerequisites are met."
    echo "✔️ Prerequisite check complete."
    echo ""
}




# Function to validate if a given kubecontext is valid
validate_kubecontext() {
    local kubeconfig_path=$1
    local kubecontext=$2

    # Check if the context exists in the kubeconfig file
    if ! kubectl config get-contexts --kubeconfig "$kubeconfig_path" -o name | grep -q "^$kubecontext$"; then
        echo "❌ Error: Kubecontext '$kubecontext' does not exist in the kubeconfig file '$kubeconfig_path'."
        exit 1
    fi

    # Try to use the context to connect to the cluster
    cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" --context "$kubecontext" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "❌ Error: Kubecontext '$kubecontext' is invalid or cannot connect to the cluster."
        echo "Details: $cluster_info"
        exit 1
    fi

    echo "✔️ Kubecontext '$kubecontext' is valid and can connect to the cluster."
}

# Kubeslice pre-checks function with context validation
kubeslice_pre_check() {
    echo "🚀 Starting Kubeslice pre-checks..."

    # Validate access to the kubeslice-controller cluster if installation is not skipped
    if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ] && [ "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" = "false" ]; then
        local kubeconfig_path="$KUBESLICE_CONTROLLER_KUBECONFIG"
        if [ -z "$kubeconfig_path" ] || [ "$kubeconfig_path" = "null" ]; then
            kubeconfig_path="$GLOBAL_KUBECONFIG"
        fi

        local kubecontext=""
        if [ "$USE_GLOBAL_CONTEXT" = "true" ]; then
            kubecontext="$GLOBAL_KUBECONTEXT"
        elif [ -n "$KUBESLICE_CONTROLLER_KUBECONTEXT" ] && [ "$KUBESLICE_CONTROLLER_KUBECONTEXT" != "null" ]; then
            kubecontext="$KUBESLICE_CONTROLLER_KUBECONTEXT"
        fi

        if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        fi

        local context_arg=""
        if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
            context_arg="--context $kubecontext"
        fi

        echo "-----------------------------------------"
        echo "🔍 Validating access to the kubeslice-controller cluster using kubeconfig '$kubeconfig_path'..."
        echo "🔧 Variables:"
        echo "  ENABLE_INSTALL_CONTROLLER=$ENABLE_INSTALL_CONTROLLER"
        echo "  KUBESLICE_CONTROLLER_SKIP_INSTALLATION=$KUBESLICE_CONTROLLER_SKIP_INSTALLATION"
        echo "  KUBESLICE_CONTROLLER_KUBECONFIG=$kubeconfig_path"
        echo "  KUBESLICE_CONTROLLER_KUBECONTEXT=$kubecontext"
        echo "  USE_GLOBAL_CONTEXT=$USE_GLOBAL_CONTEXT"
        echo "  GLOBAL_KUBECONFIG=$GLOBAL_KUBECONFIG"
        echo "  GLOBAL_KUBECONTEXT=$GLOBAL_KUBECONTEXT"
        echo "-----------------------------------------"

        cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "❌ Error: Unable to access the kubeslice-controller cluster using kubeconfig '$kubeconfig_path'."
            echo "Details: $cluster_info"
            exit 1
        fi

        controller_cluster_endpoint=$(kubectl config view --kubeconfig "$kubeconfig_path" $context_arg -o jsonpath='{.clusters[0].cluster.server}')
        echo "✔️  Successfully accessed kubeslice-controller cluster. Kubernetes endpoint: $controller_cluster_endpoint"
        echo "-----------------------------------------"
    else
        echo "⏩ Skipping kubeslice-controller cluster validation as installation is skipped or not enabled."
    fi

    # Validate access to the kubeslice-ui cluster if installation is not skipped
    if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$KUBESLICE_UI_SKIP_INSTALLATION" = "false" ]; then
        local kubeconfig_path="$KUBESLICE_UI_KUBECONFIG"
        if [ -z "$kubeconfig_path" ] || [ "$kubeconfig_path" = "null" ]; then
            kubeconfig_path="$GLOBAL_KUBECONFIG"
        fi

        local kubecontext=""
        if [ "$USE_GLOBAL_CONTEXT" = "true" ]; then
            kubecontext="$GLOBAL_KUBECONTEXT"
        elif [ -n "$KUBESLICE_UI_KUBECONTEXT" ] && [ "$KUBESLICE_UI_KUBECONTEXT" != "null" ]; then
            kubecontext="$KUBESLICE_UI_KUBECONTEXT"
        fi

        if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        fi

        local context_arg=""
        if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
            context_arg="--context $kubecontext"
        fi

        echo "-----------------------------------------"
        echo "🔍 Validating access to the kubeslice-ui cluster using kubeconfig '$kubeconfig_path'..."
        echo "🔧 Variables:"
        echo "  ENABLE_INSTALL_UI=$ENABLE_INSTALL_UI"
        echo "  KUBESLICE_UI_SKIP_INSTALLATION=$KUBESLICE_UI_SKIP_INSTALLATION"
        echo "  KUBESLICE_UI_KUBECONFIG=$kubeconfig_path"
        echo "  KUBESLICE_UI_KUBECONTEXT=$kubecontext"
        echo "  USE_GLOBAL_CONTEXT=$USE_GLOBAL_CONTEXT"
        echo "  GLOBAL_KUBECONFIG=$GLOBAL_KUBECONFIG"
        echo "  GLOBAL_KUBECONTEXT=$GLOBAL_KUBECONTEXT"
        echo "-----------------------------------------"

        cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "❌ Error: Unable to access the kubeslice-ui cluster using kubeconfig '$kubeconfig_path'."
            echo "Details: $cluster_info"
            exit 1
        fi

        ui_cluster_endpoint=$(kubectl config view --kubeconfig "$kubeconfig_path" $context_arg -o jsonpath='{.clusters[0].cluster.server}')
        echo "✔️  Successfully accessed kubeslice-ui cluster. Kubernetes endpoint: $ui_cluster_endpoint"
        echo "-----------------------------------------"
    else
        echo "⏩ Skipping kubeslice-ui cluster validation as installation is skipped or not enabled."
    fi

    # Iterate through each worker configuration and validate access if installation is not skipped
    for worker in "${KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<< "$worker"

        if [ "$skip_installation" = "false" ]; then
            local kubeconfig_path="$kubeconfig"
            if [ -z "$kubeconfig_path" ] || [ "$kubeconfig_path" = "null" ]; then
                kubeconfig_path="$GLOBAL_KUBECONFIG"
            fi

            local kubecontext="$kubecontext"
            if [ -z "$kubecontext" ] || [ "$kubecontext" = "null" ]; then
                kubecontext="$GLOBAL_KUBECONTEXT"
            fi

            if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
                validate_kubecontext "$kubeconfig_path" "$kubecontext"
            fi

            local context_arg=""
            if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
                context_arg="--context $kubecontext"
            fi

            echo "-----------------------------------------"
            echo "🔍 Validating access to the worker cluster '$worker_name' using kubeconfig '$kubeconfig_path'..."
            echo "🔧 Variables:"
            echo "  worker_name=$worker_name"
            echo "  skip_installation=$skip_installation"
            echo "  use_global_kubeconfig=$use_global_kubeconfig"
            echo "  kubeconfig=$kubeconfig_path"
            echo "  kubecontext=$kubecontext"
            echo "  namespace=$namespace"
            echo "  release_name=$release_name"
            echo "  chart_name=$chart_name"
            echo "  repo_url=$repo_url"
            echo "  username=$username"
            echo "  password=$password"
            echo "-----------------------------------------"

            cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
            if [[ $? -ne 0 ]]; then
                echo "❌ Error: Unable to access the worker cluster '$worker_name' using kubeconfig '$kubeconfig_path'."
                echo "Details: $cluster_info"
                exit 1
            fi

            worker_cluster_endpoint=$(kubectl config view --kubeconfig "$kubeconfig_path" $context_arg -o jsonpath='{.clusters[0].cluster.server}')
            echo "✔️  Successfully accessed worker cluster '$worker_name'. Kubernetes endpoint: $worker_cluster_endpoint"
            
            # Check for nodes labeled with 'kubeslice.io/node-type=gateway'
            echo "🔍 Checking for nodes labeled 'kubeslice.io/node-type=gateway' in worker cluster '$worker_name'..."
            gateway_node_count=$(kubectl get nodes --kubeconfig $kubeconfig_path $context_arg -l kubeslice.io/node-type=gateway --no-headers | wc -l)

            if [ "$gateway_node_count" -lt 1 ]; then
                if [ "$ADD_NODE_LABEL" = "true" ]; then
                    echo "⚠️  No nodes labeled with 'kubeslice.io/node-type=gateway' found. Attempting to label nodes..."
                    
                    # Attempt to label nodes with external IPs first
                    nodes_with_external_ips=$(kubectl get nodes --kubeconfig $kubeconfig_path $context_arg -o jsonpath='{range .items[*]}{@.metadata.name} {@.status.addresses[?(@.type=="ExternalIP")].address}{"\n"}{end}' | grep -v '^\s*$' | awk '{print $1}' | head -n 2)
                    
                    if [ -n "$nodes_with_external_ips" ]; then
                        echo "✔️  Nodes with external IPs found: $nodes_with_external_ips"
                        nodes_to_label=$nodes_with_external_ips
                    else
                        echo "⚠️  No nodes with external IPs found. Falling back to any available nodes."
                        nodes_to_label=$(kubectl get nodes --kubeconfig $kubeconfig_path $context_arg --no-headers | awk '{print $1}' | head -n 2)
                    fi
                    
                    if [ -z "$nodes_to_label" ]; then
                        echo "❌ Error: No nodes available to label."
                        exit 1
                    fi
                    
                    for node in $nodes_to_label; do
                        echo "🔧 Labeling node '$node' with 'kubeslice.io/node-type=gateway'..."
                        kubectl label node "$node" kubeslice.io/node-type=gateway --kubeconfig $kubeconfig_path $context_arg --overwrite
                    done
                    echo "✔️  Nodes labeled successfully."
                else
                    echo "❌ Error: ADD_NODE_LABEL is not enabled, and no nodes are labeled with 'kubeslice.io/node-type=gateway'."
                    exit 1
                fi
            else
                echo "✔️  Worker cluster '$worker_name' has at least one node labeled with 'kubeslice.io/node-type=gateway'."
            fi
            echo "-----------------------------------------"
        else
            echo "⏩ Skipping validation for worker cluster '$worker_name' as installation is skipped."
        fi
    done

    echo "✔️ Kubeslice pre-checks completed successfully."
    echo ""
}

validate_paths() {
    echo "🚀 Validating paths..."
    local error_found=false

    # Check BASE_PATH
    if [ ! -d "$BASE_PATH" ]; then
        echo "❌ Error: BASE_PATH '$BASE_PATH' does not exist or is not a directory."
        error_found=true
    fi

    # Check GLOBAL_KUBECONFIG
    if [ ! -f "$GLOBAL_KUBECONFIG" ]; then
        echo "❌ Error: GLOBAL_KUBECONFIG '$GLOBAL_KUBECONFIG' does not exist or is not a file."
        error_found=true
    fi

    # Check KUBESLICE_CONTROLLER_KUBECONFIG if controller installation is enabled
    if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ]; then
        if [ ! -f "$KUBESLICE_CONTROLLER_KUBECONFIG" ]; then
            echo "❌ Error: KUBESLICE_CONTROLLER_KUBECONFIG '$KUBESLICE_CONTROLLER_KUBECONFIG' does not exist or is not a file."
            error_found=true
        fi
    fi

    # Check KUBESLICE_UI_KUBECONFIG if UI installation is enabled and global config is not being used
    if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" != "true" ]; then
        if [ -z "$KUBESLICE_UI_KUBECONFIG" ] || [ "$KUBESLICE_UI_KUBECONFIG" = "null" ] || [ ! -f "$KUBESLICE_UI_KUBECONFIG" ]; then
            echo "❌ Error: KUBESLICE_UI_KUBECONFIG '$KUBESLICE_UI_KUBECONFIG' does not exist or is not a file."
            error_found=true
        fi
    fi

    # Check each worker's kubeconfig if worker installation is enabled
    if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
        for worker in "${KUBESLICE_WORKERS[@]}"; do
            IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<< "$worker"

            if [ "$skip_installation" = "false" ] && [ "$use_global_kubeconfig" != "true" ]; then
                if [ -z "$kubeconfig" ] || [ "$kubeconfig" = "null" ] || [ ! -f "$kubeconfig" ]; then
                    echo "❌ Error: Worker '$worker_name' kubeconfig '$kubeconfig' does not exist or is not a file."
                    error_found=true
                fi
            fi
        done
    fi

    # Check LOCAL_CHARTS_PATH if local charts are used
    if [ "$USE_LOCAL_CHARTS" = "true" ]; then
        if [ ! -d "$LOCAL_CHARTS_PATH" ]; then
            echo "❌ Error: LOCAL_CHARTS_PATH '$LOCAL_CHARTS_PATH' does not exist or is not a directory."
            error_found=true
        fi
    fi

    # If any errors were found, exit the script
    if [ "$error_found" = "true" ]; then
        echo "❌ One or more critical errors were found in the paths. Please correct them and try again."
        exit 1
    else
        echo "✔️ All required paths are valid."
    fi
}

# Function to parse YAML using yq


parse_yaml() {
    local yaml_file=$1

    echo "🚀 Parsing input YAML file '$yaml_file'..."
    wait_with_dots 5 " "

    # Extract BASE_PATH
    BASE_PATH=$(yq e '.base_path' "$yaml_file")
    if [ -z "$BASE_PATH" ] || [ "$BASE_PATH" = "null" ]; then
        echo "⚠️  BASE_PATH not specified. Defaulting to script directory."
        BASE_PATH=$(dirname "$(realpath "$0")")  # Default to the script's directory
    fi

    # Ensure BASE_PATH is absolute
    BASE_PATH=$(realpath "$BASE_PATH")

    # Create installation-files directory if not exists
    INSTALLATION_FILES_PATH="$BASE_PATH/installation-files"
    mkdir -p "$INSTALLATION_FILES_PATH"

    # Extract precheck flag
    PRECHECK=$(yq e '.precheck' "$yaml_file")
    if [ -z "$PRECHECK" ] || [ "$PRECHECK" = "null" ]; then
        PRECHECK="true"  # Default to true if not specified
    fi

    # Extract Kubeslice pre-check flag
    KUBESLICE_PRECHECK=$(yq e '.kubeslice_precheck' "$yaml_file")
    if [ -z "$KUBESLICE_PRECHECK" ] || [ "$KUBESLICE_PRECHECK" = "null" ]; then
        KUBESLICE_PRECHECK="false"  # Default to false if not specified
    fi


	# Extract the add_node_label setting
	ADD_NODE_LABEL=$(yq e '.add_node_label' "$yaml_file")
	if [ -z "$ADD_NODE_LABEL" ] || [ "$ADD_NODE_LABEL" = "null" ]; then
    	ADD_NODE_LABEL="false"  # Default to false if not specified
	fi

 # Extract cloud_install configuration
    CLOUD_INSTALL=$(yq e '.cloud_install' "$yaml_file")
    if [ -z "$CLOUD_INSTALL" ] || [ "$CLOUD_INSTALL" = "null" ]; then
       # echo "⚠️  CLOUD_INSTALL not specified. Skipping cloud-specific installations."
        CLOUD_INSTALL=""
    fi

    # Extract global Helm repo settings
    GLOBAL_HELM_REPO_URL=$(yq e '.global_helm_repo_url' "$yaml_file")
    GLOBAL_HELM_USERNAME=$(yq e '.global_helm_username' "$yaml_file")
    GLOBAL_HELM_PASSWORD=$(yq e '.global_helm_password' "$yaml_file")
    READD_HELM_REPOS=$(yq e '.readd_helm_repos' "$yaml_file")

    # Extract global imagePullSecrets settings
    GLOBAL_IMAGE_PULL_SECRET_REPO=$(yq e '.global_image_pull_secret.repository' "$yaml_file")
    GLOBAL_IMAGE_PULL_SECRET_USERNAME=$(yq e '.global_image_pull_secret.username' "$yaml_file")
    GLOBAL_IMAGE_PULL_SECRET_PASSWORD=$(yq e '.global_image_pull_secret.password' "$yaml_file")
    GLOBAL_IMAGE_PULL_SECRET_EMAIL=$(yq e '.global_image_pull_secret.email' "$yaml_file")

    # Verify install settings
    GLOBAL_VERIFY_INSTALL=$(yq e '.verify_install' "$yaml_file")
    if [ -z "$GLOBAL_VERIFY_INSTALL" ] || [ "$GLOBAL_VERIFY_INSTALL" = "null" ]; then
        GLOBAL_VERIFY_INSTALL="true"  # Default to true if not specified
    fi

    GLOBAL_VERIFY_INSTALL_TIMEOUT=$(yq e '.verify_install_timeout' "$yaml_file")
    if [ -z "$GLOBAL_VERIFY_INSTALL_TIMEOUT" ] || [ "$GLOBAL_VERIFY_INSTALL_TIMEOUT" = "null" ]; then
        GLOBAL_VERIFY_INSTALL_TIMEOUT="600"  # Default to 10 minutes if not specified
    fi

    GLOBAL_SKIP_ON_VERIFY_FAIL=$(yq e '.skip_on_verify_fail' "$yaml_file")
    if [ -z "$GLOBAL_SKIP_ON_VERIFY_FAIL" ] || [ "$GLOBAL_SKIP_ON_VERIFY_FAIL" = "null" ]; then
        GLOBAL_SKIP_ON_VERIFY_FAIL="false"  # Default to error out if not specified
    fi

    # Extract the list of required binaries
    REQUIRED_BINARIES=($(yq e '.required_binaries[]' "$yaml_file"))
    if [ ${#REQUIRED_BINARIES[@]} -eq 0 ]; then
        REQUIRED_BINARIES=("yq" "helm" "kubectl" "kubectx")  # Default list if none specified
    fi

    # Extract global settings with defaults
    GLOBAL_KUBECONFIG=$(yq e '.global_kubeconfig' "$yaml_file")
    if [ -z "$GLOBAL_KUBECONFIG" ] || [ "$GLOBAL_KUBECONFIG" = "null" ]; then
        echo -e "\n❌ Error: global_kubeconfig is not specified in the YAML file."
        exit 1
    fi
    GLOBAL_KUBECONFIG="$BASE_PATH/$GLOBAL_KUBECONFIG"

    GLOBAL_KUBECONTEXT=$(yq e '.global_kubecontext' "$yaml_file")
    if [ -z "$GLOBAL_KUBECONTEXT" ] || [ "$GLOBAL_KUBECONTEXT" = "null" ]; then
        echo -e "\n❌ Error: global_kubecontext is not specified in the YAML file."
        exit 1
    fi

    USE_LOCAL_CHARTS=$(yq e '.use_local_charts' "$yaml_file")
    if [ -z "$USE_LOCAL_CHARTS" ] || [ "$USE_LOCAL_CHARTS" = "null" ]; then
        USE_LOCAL_CHARTS="false"
    fi

    LOCAL_CHARTS_PATH=$(yq e '.local_charts_path' "$yaml_file")
    if [ -z "$LOCAL_CHARTS_PATH" ] || [ "$LOCAL_CHARTS_PATH" = "null" ]; then
        LOCAL_CHARTS_PATH="./charts"
    fi
    LOCAL_CHARTS_PATH="$BASE_PATH/$LOCAL_CHARTS_PATH"

    # Extract global context usage flag
    USE_GLOBAL_CONTEXT=$(yq e '.use_global_context' "$yaml_file")
    if [ -z "$USE_GLOBAL_CONTEXT" ] || [ "$USE_GLOBAL_CONTEXT" = "null" ]; then
        USE_GLOBAL_CONTEXT="true"  # Default to true if not specified
    fi

    echo "DEBUG: BASE_PATH=$BASE_PATH"
    echo "DEBUG: LOCAL_CHARTS_PATH=$LOCAL_CHARTS_PATH"

    # Global enable/disable flags for different stages
    ENABLE_FETCH_CONTROLLER_SECRETS=$(yq e '.enable_fetch_controller_secrets' "$yaml_file")
    if [ -z "$ENABLE_FETCH_CONTROLLER_SECRETS" ] || [ "$ENABLE_FETCH_CONTROLLER_SECRETS" = "null" ]; then
        ENABLE_FETCH_CONTROLLER_SECRETS="true"
    fi

    ENABLE_PREPARE_WORKER_VALUES_FILE=$(yq e '.enable_prepare_worker_values_file' "$yaml_file")
    if [ -z "$ENABLE_PREPARE_WORKER_VALUES_FILE" ] || [ "$ENABLE_PREPARE_WORKER_VALUES_FILE" = "null" ]; then
        ENABLE_PREPARE_WORKER_VALUES_FILE="true"
    fi

    ENABLE_INSTALL_CONTROLLER=$(yq e '.enable_install_controller' "$yaml_file")
    if [ -z "$ENABLE_INSTALL_CONTROLLER" ] || [ "$ENABLE_INSTALL_CONTROLLER" = "null" ]; then
        ENABLE_INSTALL_CONTROLLER="true"
    fi

    ENABLE_INSTALL_UI=$(yq e '.enable_install_ui' "$yaml_file")
    if [ -z "$ENABLE_INSTALL_UI" ] || [ "$ENABLE_INSTALL_UI" = "null" ]; then
        ENABLE_INSTALL_UI="true"
    fi

    ENABLE_INSTALL_WORKER=$(yq e '.enable_install_worker' "$yaml_file")
    if [ -z "$ENABLE_INSTALL_WORKER" ] || [ "$ENABLE_INSTALL_WORKER" = "null" ]; then
        ENABLE_INSTALL_WORKER="true"
    fi

    # Extract values for kubeslice-controller-egs
    KUBESLICE_CONTROLLER_SKIP_INSTALLATION=$(yq e '.kubeslice_controller_egs.skip_installation' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" ] || [ "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" = "null" ]; then
        KUBESLICE_CONTROLLER_SKIP_INSTALLATION="false"
    fi

    KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG=$(yq e '.kubeslice_controller_egs.use_global_kubeconfig' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" ] || [ "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" = "null" ]; then
        KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG="true"
    fi

    KUBESLICE_CONTROLLER_KUBECONFIG=$(yq e '.kubeslice_controller_egs.kubeconfig' "$yaml_file")
    KUBESLICE_CONTROLLER_KUBECONFIG="${KUBESLICE_CONTROLLER_KUBECONFIG:-$GLOBAL_KUBECONFIG}"

    KUBESLICE_CONTROLLER_KUBECONTEXT=$(yq e '.kubeslice_controller_egs.kubecontext' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_KUBECONTEXT" ] || [ "$KUBESLICE_CONTROLLER_KUBECONTEXT" = "null" ]; then
        KUBESLICE_CONTROLLER_KUBECONTEXT="$GLOBAL_KUBECONTEXT"
    fi

    KUBESLICE_CONTROLLER_NAMESPACE=$(yq e '.kubeslice_controller_egs.namespace' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_NAMESPACE" ] || [ "$KUBESLICE_CONTROLLER_NAMESPACE" = "null" ]; then
        KUBESLICE_CONTROLLER_NAMESPACE="kubeslice-controller"
    fi

    KUBESLICE_CONTROLLER_RELEASE_NAME=$(yq e '.kubeslice_controller_egs.release' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_RELEASE_NAME" ] || [ "$KUBESLICE_CONTROLLER_RELEASE_NAME" = "null" ]; then
        KUBESLICE_CONTROLLER_RELEASE_NAME="$KUBESLICE_CONTROLLER_NAMESPACE-release"
    fi

    KUBESLICE_CONTROLLER_CHART_NAME=$(yq e '.kubeslice_controller_egs.chart' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_CHART_NAME" ] || [ "$KUBESLICE_CONTROLLER_CHART_NAME" = "null" ]; then
        KUBESLICE_CONTROLLER_CHART_NAME="kubeslice-controller"
    fi

    KUBESLICE_CONTROLLER_REPO_URL=$(yq e '.kubeslice_controller_egs.repo_url' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_REPO_URL" ] || [ "$KUBESLICE_CONTROLLER_REPO_URL" = "null" ]; then
        KUBESLICE_CONTROLLER_REPO_URL="$GLOBAL_HELM_REPO_URL"
    fi

    KUBESLICE_CONTROLLER_USERNAME=$(yq e '.kubeslice_controller_egs.username' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_USERNAME" ] || [ "$KUBESLICE_CONTROLLER_USERNAME" = "null" ]; then
        KUBESLICE_CONTROLLER_USERNAME="$GLOBAL_HELM_USERNAME"
    fi

    KUBESLICE_CONTROLLER_PASSWORD=$(yq e '.kubeslice_controller_egs.password' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_PASSWORD" ] || [ "$KUBESLICE_CONTROLLER_PASSWORD" = "null" ]; then
        KUBESLICE_CONTROLLER_PASSWORD="$GLOBAL_HELM_PASSWORD"
    fi

    KUBESLICE_CONTROLLER_VALUES_FILE=$(yq e '.kubeslice_controller_egs.values_file' "$yaml_file")
    KUBESLICE_CONTROLLER_VALUES_FILE="$BASE_PATH/$KUBESLICE_CONTROLLER_VALUES_FILE"

    KUBESLICE_CONTROLLER_INLINE_VALUES=$(yq e '.kubeslice_controller_egs.inline_values // {}' "$yaml_file")

    KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO=$(yq e '.kubeslice_controller_egs.imagePullSecrets.repository' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO" ] || [ "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO" = "null" ]; then
        KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO="$GLOBAL_IMAGE_PULL_SECRET_REPO"
    fi

    KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME=$(yq e '.kubeslice_controller_egs.imagePullSecrets.username' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME" ] || [ "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME" = "null" ]; then
        KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME="$GLOBAL_IMAGE_PULL_SECRET_USERNAME"
    fi

    KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD=$(yq e '.kubeslice_controller_egs.imagePullSecrets.password' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD" ] || [ "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD" = "null" ]; then
        KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD="$GLOBAL_IMAGE_PULL_SECRET_PASSWORD"
    fi

    KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL=$(yq e '.kubeslice_controller_egs.imagePullSecrets.email' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL" ] || [ "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL" = "null" ]; then
        KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL="$GLOBAL_IMAGE_PULL_SECRET_EMAIL"
    fi

    KUBESLICE_CONTROLLER_HELM_FLAGS=$(yq e '.kubeslice_controller_egs.helm_flags' "$yaml_file")

    KUBESLICE_CONTROLLER_VERIFY_INSTALL=$(yq e '.kubeslice_controller_egs.verify_install' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_VERIFY_INSTALL" ] || [ "$KUBESLICE_CONTROLLER_VERIFY_INSTALL" = "null" ]; then
        KUBESLICE_CONTROLLER_VERIFY_INSTALL="$GLOBAL_VERIFY_INSTALL"
    fi

    KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT=$(yq e '.kubeslice_controller_egs.verify_install_timeout' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT" ] || [ "$KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT" = "null" ]; then
        KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT="$GLOBAL_VERIFY_INSTALL_TIMEOUT"
    fi

    KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL=$(yq e '.kubeslice_controller_egs.skip_on_verify_fail' "$yaml_file")
    if [ -z "$KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL" ] || [ "$KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL" = "null" ]; then
        KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL="$GLOBAL_SKIP_ON_VERIFY_FAIL"
    fi

    # Extract values for kubeslice-ui-egs
    KUBESLICE_UI_SKIP_INSTALLATION=$(yq e '.kubeslice_ui_egs.skip_installation' "$yaml_file")
    if [ -z "$KUBESLICE_UI_SKIP_INSTALLATION" ] || [ "$KUBESLICE_UI_SKIP_INSTALLATION" = "null" ]; then
        KUBESLICE_UI_SKIP_INSTALLATION="false"
    fi

    KUBESLICE_UI_USE_GLOBAL_KUBECONFIG=$(yq e '.kubeslice_ui_egs.use_global_kubeconfig' "$yaml_file")
    if [ -z "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" ] || [ "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" = "null" ]; then
        KUBESLICE_UI_USE_GLOBAL_KUBECONFIG="true"
    fi

    KUBESLICE_UI_KUBECONFIG=$(yq e '.kubeslice_ui_egs.kubeconfig' "$yaml_file")
    KUBESLICE_UI_KUBECONFIG="${KUBESLICE_UI_KUBECONFIG:-$GLOBAL_KUBECONFIG}"

    KUBESLICE_UI_KUBECONTEXT=$(yq e '.kubeslice_ui_egs.kubecontext' "$yaml_file")
    if [ -z "$KUBESLICE_UI_KUBECONTEXT" ] || [ "$KUBESLICE_UI_KUBECONTEXT" = "null" ]; then
        KUBESLICE_UI_KUBECONTEXT="$GLOBAL_KUBECONTEXT"
    fi

    KUBESLICE_UI_NAMESPACE=$(yq e '.kubeslice_ui_egs.namespace' "$yaml_file")
    if [ -z "$KUBESLICE_UI_NAMESPACE" ] || [ "$KUBESLICE_UI_NAMESPACE" = "null" ]; then
        KUBESLICE_UI_NAMESPACE="kubeslice-ui"
    fi

    KUBESLICE_UI_RELEASE_NAME=$(yq e '.kubeslice_ui_egs.release' "$yaml_file")
    if [ -z "$KUBESLICE_UI_RELEASE_NAME" ] || [ "$KUBESLICE_UI_RELEASE_NAME" = "null" ]; then
        KUBESLICE_UI_RELEASE_NAME="$KUBESLICE_UI_NAMESPACE-release"
    fi

    KUBESLICE_UI_CHART_NAME=$(yq e '.kubeslice_ui_egs.chart' "$yaml_file")
    if [ -z "$KUBESLICE_UI_CHART_NAME" ] || [ "$KUBESLICE_UI_CHART_NAME" = "null" ]; then
        KUBESLICE_UI_CHART_NAME="kubeslice-ui"
    fi

    KUBESLICE_UI_REPO_URL=$(yq e '.kubeslice_ui_egs.repo_url' "$yaml_file")
    if [ -z "$KUBESLICE_UI_REPO_URL" ] || [ "$KUBESLICE_UI_REPO_URL" = "null" ]; then
        KUBESLICE_UI_REPO_URL="$GLOBAL_HELM_REPO_URL"
    fi

    KUBESLICE_UI_USERNAME=$(yq e '.kubeslice_ui_egs.username' "$yaml_file")
    if [ -z "$KUBESLICE_UI_USERNAME" ] || [ "$KUBESLICE_UI_USERNAME" = "null" ]; then
        KUBESLICE_UI_USERNAME="$GLOBAL_HELM_USERNAME"
    fi

    KUBESLICE_UI_PASSWORD=$(yq e '.kubeslice_ui_egs.password' "$yaml_file")
    if [ -z "$KUBESLICE_UI_PASSWORD" ] || [ "$KUBESLICE_UI_PASSWORD" = "null" ]; then
        KUBESLICE_UI_PASSWORD="$GLOBAL_HELM_PASSWORD"
    fi

    KUBESLICE_UI_VALUES_FILE=$(yq e '.kubeslice_ui_egs.values_file' "$yaml_file")
    KUBESLICE_UI_VALUES_FILE="$BASE_PATH/$KUBESLICE_UI_VALUES_FILE"

    KUBESLICE_UI_INLINE_VALUES=$(yq e '.kubeslice_ui_egs.inline_values // {}' "$yaml_file")

    KUBESLICE_UI_IMAGE_PULL_SECRET_REPO=$(yq e '.kubeslice_ui_egs.imagePullSecrets.repository' "$yaml_file")
    if [ -z "$KUBESLICE_UI_IMAGE_PULL_SECRET_REPO" ] || [ "$KUBESLICE_UI_IMAGE_PULL_SECRET_REPO" = "null" ]; then
        KUBESLICE_UI_IMAGE_PULL_SECRET_REPO="$GLOBAL_IMAGE_PULL_SECRET_REPO"
    fi

    KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME=$(yq e '.kubeslice_ui_egs.imagePullSecrets.username' "$yaml_file")
    if [ -z "$KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME" ] || [ "$KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME" = "null" ]; then
        KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME="$GLOBAL_IMAGE_PULL_SECRET_USERNAME"
    fi

    KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD=$(yq e '.kubeslice_ui_egs.imagePullSecrets.password' "$yaml_file")
    if [ -z "$KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD" ] || [ "$KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD" = "null" ]; then
        KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD="$GLOBAL_IMAGE_PULL_SECRET_PASSWORD"
    fi

    KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL=$(yq e '.kubeslice_ui_egs.imagePullSecrets.email' "$yaml_file")
    if [ -z "$KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL" ] || [ "$KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL" = "null" ]; then
        KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL="$GLOBAL_IMAGE_PULL_SECRET_EMAIL"
    fi

    KUBESLICE_UI_HELM_FLAGS=$(yq e '.kubeslice_ui_egs.helm_flags' "$yaml_file")

    KUBESLICE_UI_VERIFY_INSTALL=$(yq e '.kubeslice_ui_egs.verify_install' "$yaml_file")
    if [ -z "$KUBESLICE_UI_VERIFY_INSTALL" ] || [ "$KUBESLICE_UI_VERIFY_INSTALL" = "null" ]; then
        KUBESLICE_UI_VERIFY_INSTALL="$GLOBAL_VERIFY_INSTALL"
    fi

    KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT=$(yq e '.kubeslice_ui_egs.verify_install_timeout' "$yaml_file")
    if [ -z "$KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT" ] || [ "$KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT" = "null" ]; then
        KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT="$GLOBAL_VERIFY_INSTALL_TIMEOUT"
    fi

    KUBESLICE_UI_SKIP_ON_VERIFY_FAIL=$(yq e '.kubeslice_ui_egs.skip_on_verify_fail' "$yaml_file")
    if [ -z "$KUBESLICE_UI_SKIP_ON_VERIFY_FAIL" ] || [ "$KUBESLICE_UI_SKIP_ON_VERIFY_FAIL" = "null" ]; then
        KUBESLICE_UI_SKIP_ON_VERIFY_FAIL="$GLOBAL_SKIP_ON_VERIFY_FAIL"
    fi

    # Extract values for kubeslice-worker-egs
    WORKERS_COUNT=$(yq e '.kubeslice_worker_egs | length' "$yaml_file")

    KUBESLICE_WORKERS=()
    for ((i=0; i<WORKERS_COUNT; i++)); do
        WORKER_NAME=$(yq e ".kubeslice_worker_egs[$i].name" "$yaml_file")
        WORKER_SKIP_INSTALLATION=$(yq e ".kubeslice_worker_egs[$i].skip_installation" "$yaml_file")
        WORKER_USE_GLOBAL_KUBECONFIG=$(yq e ".kubeslice_worker_egs[$i].use_global_kubeconfig" "$yaml_file")
        if [ -z "$WORKER_USE_GLOBAL_KUBECONFIG" ] || [ "$WORKER_USE_GLOBAL_KUBECONFIG" = "null" ]; then
            WORKER_USE_GLOBAL_KUBECONFIG="true"
        fi
        WORKER_KUBECONFIG=$(yq e ".kubeslice_worker_egs[$i].kubeconfig" "$yaml_file")
        WORKER_KUBECONFIG="${WORKER_KUBECONFIG:-$GLOBAL_KUBECONFIG}"

        WORKER_KUBECONTEXT=$(yq e ".kubeslice_worker_egs[$i].kubecontext" "$yaml_file")
        if [ -z "$WORKER_KUBECONTEXT" ] || [ "$WORKER_KUBECONTEXT" = "null" ]; then
            WORKER_KUBECONTEXT="$GLOBAL_KUBECONTEXT"
        fi

        WORKER_NAMESPACE=$(yq e ".kubeslice_worker_egs[$i].namespace" "$yaml_file")
        WORKER_RELEASE_NAME=$(yq e ".kubeslice_worker_egs[$i].release" "$yaml_file")
        WORKER_CHART_NAME=$(yq e ".kubeslice_worker_egs[$i].chart" "$yaml_file")
        WORKER_REPO_URL=$(yq e ".kubeslice_worker_egs[$i].repo_url" "$yaml_file")
        if [ -z "$WORKER_REPO_URL" ] || [ "$WORKER_REPO_URL" = "null" ]; then
            WORKER_REPO_URL="$GLOBAL_HELM_REPO_URL"
        fi

        WORKER_USERNAME=$(yq e ".kubeslice_worker_egs[$i].username" "$yaml_file")
        if [ -z "$WORKER_USERNAME" ] || [ "$WORKER_USERNAME" = "null" ]; then
            WORKER_USERNAME="$GLOBAL_HELM_USERNAME"
        fi

        WORKER_PASSWORD=$(yq e ".kubeslice_worker_egs[$i].password" "$yaml_file")
        if [ -z "$WORKER_PASSWORD" ] || [ "$WORKER_PASSWORD" = "null" ]; then
            WORKER_PASSWORD="$GLOBAL_HELM_PASSWORD"
        fi

        WORKER_VALUES_FILE=$(yq e ".kubeslice_worker_egs[$i].values_file" "$yaml_file")
        WORKER_VALUES_FILE="$BASE_PATH/$WORKER_VALUES_FILE"

        WORKER_INLINE_VALUES=$(yq e ".kubeslice_worker_egs[$i].inline_values // {}" "$yaml_file")

        WORKER_IMAGE_PULL_SECRET_REPO=$(yq e ".kubeslice_worker_egs[$i].imagePullSecrets.repository" "$yaml_file")
        if [ -z "$WORKER_IMAGE_PULL_SECRET_REPO" ] || [ "$WORKER_IMAGE_PULL_SECRET_REPO" = "null" ]; then
            WORKER_IMAGE_PULL_SECRET_REPO="$GLOBAL_IMAGE_PULL_SECRET_REPO"
        fi

        WORKER_IMAGE_PULL_SECRET_USERNAME=$(yq e ".kubeslice_worker_egs[$i].imagePullSecrets.username" "$yaml_file")
        if [ -z "$WORKER_IMAGE_PULL_SECRET_USERNAME" ] || [ "$WORKER_IMAGE_PULL_SECRET_USERNAME" = "null" ]; then
            WORKER_IMAGE_PULL_SECRET_USERNAME="$GLOBAL_IMAGE_PULL_SECRET_USERNAME"
        fi

        WORKER_IMAGE_PULL_SECRET_PASSWORD=$(yq e ".kubeslice_worker_egs[$i].imagePullSecrets.password" "$yaml_file")
        if [ -z "$WORKER_IMAGE_PULL_SECRET_PASSWORD" ] || [ "$WORKER_IMAGE_PULL_SECRET_PASSWORD" = "null" ]; then
            WORKER_IMAGE_PULL_SECRET_PASSWORD="$GLOBAL_IMAGE_PULL_SECRET_PASSWORD"
        fi

        WORKER_IMAGE_PULL_SECRET_EMAIL=$(yq e ".kubeslice_worker_egs[$i].imagePullSecrets.email" "$yaml_file")
        if [ -z "$WORKER_IMAGE_PULL_SECRET_EMAIL" ] || [ "$WORKER_IMAGE_PULL_SECRET_EMAIL" = "null" ]; then
            WORKER_IMAGE_PULL_SECRET_EMAIL="$GLOBAL_IMAGE_PULL_SECRET_EMAIL"
        fi

        WORKER_HELM_FLAGS=$(yq e ".kubeslice_worker_egs[$i].helm_flags" "$yaml_file")

        WORKER_VERIFY_INSTALL=$(yq e ".kubeslice_worker_egs[$i].verify_install" "$yaml_file")
        if [ -z "$WORKER_VERIFY_INSTALL" ] || [ "$WORKER_VERIFY_INSTALL" = "null" ]; then
            WORKER_VERIFY_INSTALL="$GLOBAL_VERIFY_INSTALL"
        fi

        WORKER_VERIFY_INSTALL_TIMEOUT=$(yq e ".kubeslice_worker_egs[$i].verify_install_timeout" "$yaml_file")
        if [ -z "$WORKER_VERIFY_INSTALL_TIMEOUT" ] || [ "$WORKER_VERIFY_INSTALL_TIMEOUT" = "null" ]; then
            WORKER_VERIFY_INSTALL_TIMEOUT="$GLOBAL_VERIFY_INSTALL_TIMEOUT"
        fi

        if [ -z "$WORKER_SKIP_INSTALLATION" ] || [ "$WORKER_SKIP_INSTALLATION" = "null" ]; then
            WORKER_SKIP_INSTALLATION="false"
        fi

        WORKER_SKIP_ON_VERIFY_FAIL=$(yq e ".kubeslice_worker_egs[$i].skip_on_verify_fail" "$yaml_file")
        if [ -z "$WORKER_SKIP_ON_VERIFY_FAIL" ] || [ "$WORKER_SKIP_ON_VERIFY_FAIL" = "null" ]; then
            WORKER_SKIP_ON_VERIFY_FAIL="$GLOBAL_SKIP_ON_VERIFY_FAIL"
        fi

        KUBESLICE_WORKERS+=("$WORKER_NAME|$WORKER_SKIP_INSTALLATION|$WORKER_USE_GLOBAL_KUBECONFIG|$WORKER_KUBECONFIG|$WORKER_KUBECONTEXT|$WORKER_NAMESPACE|$WORKER_RELEASE_NAME|$WORKER_CHART_NAME|$WORKER_REPO_URL|$WORKER_USERNAME|$WORKER_PASSWORD|$WORKER_VALUES_FILE|$WORKER_INLINE_VALUES|$WORKER_IMAGE_PULL_SECRET_REPO|$WORKER_IMAGE_PULL_SECRET_USERNAME|$WORKER_IMAGE_PULL_SECRET_PASSWORD|$WORKER_IMAGE_PULL_SECRET_EMAIL|$WORKER_HELM_FLAGS|$WORKER_VERIFY_INSTALL|$WORKER_VERIFY_INSTALL_TIMEOUT|$WORKER_SKIP_ON_VERIFY_FAIL")
    done

    # Extract values for projects
    ENABLE_PROJECT_CREATION=$(yq e '.enable_project_creation' "$yaml_file")
    if [ -z "$ENABLE_PROJECT_CREATION" ] || [ "$ENABLE_PROJECT_CREATION" = "null" ]; then
        ENABLE_PROJECT_CREATION="false"
    fi

    PROJECTS_COUNT=$(yq e '.projects | length' "$yaml_file")

    KUBESLICE_PROJECTS=()
    for ((i=0; i<PROJECTS_COUNT; i++)); do
        PROJECT_NAME=$(yq e ".projects[$i].name" "$yaml_file")
        PROJECT_USERNAME=$(yq e ".projects[$i].username" "$yaml_file")
        KUBESLICE_PROJECTS+=("$PROJECT_NAME|$PROJECT_USERNAME")
    done

    # Extract values for cluster registration
    ENABLE_CLUSTER_REGISTRATION=$(yq e '.enable_cluster_registration' "$yaml_file")
    if [ -z "$ENABLE_CLUSTER_REGISTRATION" ] || [ "$ENABLE_CLUSTER_REGISTRATION" = "null" ]; then
        ENABLE_CLUSTER_REGISTRATION="false"
    fi

    CLUSTER_REGISTRATION_COUNT=$(yq e '.cluster_registration | length' "$yaml_file")

    KUBESLICE_CLUSTER_REGISTRATIONS=()
    for ((i=0; i<CLUSTER_REGISTRATION_COUNT; i++)); do
        CLUSTER_NAME=$(yq e ".cluster_registration[$i].cluster_name" "$yaml_file")
        PROJECT_NAME=$(yq e ".cluster_registration[$i].project_name" "$yaml_file")
        TELEMETRY_ENABLED=$(yq e ".cluster_registration[$i].telemetry.enabled" "$yaml_file")
        TELEMETRY_ENDPOINT=$(yq e ".cluster_registration[$i].telemetry.endpoint" "$yaml_file")
        TELEMETRY_PROVIDER=$(yq e ".cluster_registration[$i].telemetry.telemetryProvider" "$yaml_file")
        GEO_LOCATION_PROVIDER=$(yq e ".cluster_registration[$i].geoLocation.cloudProvider" "$yaml_file")
        GEO_LOCATION_REGION=$(yq e ".cluster_registration[$i].geoLocation.cloudRegion" "$yaml_file")
        KUBESLICE_CLUSTER_REGISTRATIONS+=("$CLUSTER_NAME|$PROJECT_NAME|$TELEMETRY_ENABLED|$TELEMETRY_ENDPOINT|$TELEMETRY_PROVIDER|$GEO_LOCATION_PROVIDER|$GEO_LOCATION_REGION")
    done

# Extract global enable/disable flag for additional apps installation
    ENABLE_INSTALL_ADDITIONAL_APPS=$(yq e '.enable_install_additional_apps' "$yaml_file")
    if [ -z "$ENABLE_INSTALL_ADDITIONAL_APPS" ] || [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "null" ]; then
        ENABLE_INSTALL_ADDITIONAL_APPS="true"  # Default to true if not specified
    fi

 # Extract values for additional applications
    ADDITIONAL_APPS_COUNT=$(yq e '.additional_apps | length' "$yaml_file")

    ADDITIONAL_APPS=()
    for ((i=0; i<ADDITIONAL_APPS_COUNT; i++)); do
        APP_NAME=$(yq e ".additional_apps[$i].name" "$yaml_file")
        APP_SKIP_INSTALLATION=$(yq e ".additional_apps[$i].skip_installation" "$yaml_file")
        APP_USE_GLOBAL_KUBECONFIG=$(yq e ".additional_apps[$i].use_global_kubeconfig" "$yaml_file")
        if [ -z "$APP_USE_GLOBAL_KUBECONFIG" ] || [ "$APP_USE_GLOBAL_KUBECONFIG" = "null" ]; then
            APP_USE_GLOBAL_KUBECONFIG="true"
        fi
        APP_KUBECONFIG=$(yq e ".additional_apps[$i].kubeconfig" "$yaml_file")
        APP_KUBECONFIG="${APP_KUBECONFIG:-$GLOBAL_KUBECONFIG}"

        APP_KUBECONTEXT=$(yq e ".additional_apps[$i].kubecontext" "$yaml_file")
        if [ -z "$APP_KUBECONTEXT" ] || [ "$APP_KUBECONTEXT" = "null" ]; then
            APP_KUBECONTEXT="$GLOBAL_KUBECONTEXT"
        fi

        APP_NAMESPACE=$(yq e ".additional_apps[$i].namespace" "$yaml_file")
        APP_RELEASE_NAME=$(yq e ".additional_apps[$i].release" "$yaml_file")
        APP_CHART_NAME=$(yq e ".additional_apps[$i].chart" "$yaml_file")
        APP_REPO_URL=$(yq e ".additional_apps[$i].repo_url" "$yaml_file")
        if [ -z "$APP_REPO_URL" ] || [ "$APP_REPO_URL" = "null" ]; then
            APP_REPO_URL="$GLOBAL_HELM_REPO_URL"
        fi

        APP_USERNAME=$(yq e ".additional_apps[$i].username" "$yaml_file")
        if [ -z "$APP_USERNAME" ] || [ "$APP_USERNAME" = "null" ]; then
            APP_USERNAME="$GLOBAL_HELM_USERNAME"
        fi

        APP_PASSWORD=$(yq e ".additional_apps[$i].password" "$yaml_file")
        if [ -z "$APP_PASSWORD" ] || [ "$APP_PASSWORD" = "null" ]; then
            APP_PASSWORD="$GLOBAL_HELM_PASSWORD"
        fi

        APP_VALUES_FILE=$(yq e ".additional_apps[$i].values_file" "$yaml_file")
        APP_VALUES_FILE="$BASE_PATH/$APP_VALUES_FILE"

        APP_INLINE_VALUES=$(yq e ".additional_apps[$i].inline_values // {}" "$yaml_file")

        APP_IMAGE_PULL_SECRET_REPO=$(yq e ".additional_apps[$i].imagePullSecrets.repository" "$yaml_file")
        if [ -z "$APP_IMAGE_PULL_SECRET_REPO" ] || [ "$APP_IMAGE_PULL_SECRET_REPO" = "null" ]; then
            APP_IMAGE_PULL_SECRET_REPO="$GLOBAL_IMAGE_PULL_SECRET_REPO"
        fi

        APP_IMAGE_PULL_SECRET_USERNAME=$(yq e ".additional_apps[$i].imagePullSecrets.username" "$yaml_file")
        if [ -z "$APP_IMAGE_PULL_SECRET_USERNAME" ] || [ "$APP_IMAGE_PULL_SECRET_USERNAME" = "null" ]; then
            APP_IMAGE_PULL_SECRET_USERNAME="$GLOBAL_IMAGE_PULL_SECRET_USERNAME"
        fi

        APP_IMAGE_PULL_SECRET_PASSWORD=$(yq e ".additional_apps[$i].imagePullSecrets.password" "$yaml_file")
        if [ -z "$APP_IMAGE_PULL_SECRET_PASSWORD" ] || [ "$APP_IMAGE_PULL_SECRET_PASSWORD" = "null" ]; then
            APP_IMAGE_PULL_SECRET_PASSWORD="$GLOBAL_IMAGE_PULL_SECRET_PASSWORD"
        fi

        APP_IMAGE_PULL_SECRET_EMAIL=$(yq e ".additional_apps[$i].imagePullSecrets.email" "$yaml_file")
        if [ -z "$APP_IMAGE_PULL_SECRET_EMAIL" ] || [ "$APP_IMAGE_PULL_SECRET_EMAIL" = "null" ]; then
            APP_IMAGE_PULL_SECRET_EMAIL="$GLOBAL_IMAGE_PULL_SECRET_EMAIL"
        fi

        APP_HELM_FLAGS=$(yq e ".additional_apps[$i].helm_flags" "$yaml_file")

        APP_VERIFY_INSTALL=$(yq e ".additional_apps[$i].verify_install" "$yaml_file")
        if [ -z "$APP_VERIFY_INSTALL" ] || [ "$APP_VERIFY_INSTALL" = "null" ]; then
            APP_VERIFY_INSTALL="$GLOBAL_VERIFY_INSTALL"
        fi

        APP_VERIFY_INSTALL_TIMEOUT=$(yq e ".additional_apps[$i].verify_install_timeout" "$yaml_file")
        if [ -z "$APP_VERIFY_INSTALL_TIMEOUT" ] || [ "$APP_VERIFY_INSTALL_TIMEOUT" = "null" ]; then
            APP_VERIFY_INSTALL_TIMEOUT="$GLOBAL_VERIFY_INSTALL_TIMEOUT"
        fi

        if [ -z "$APP_SKIP_INSTALLATION" ] || [ "$APP_SKIP_INSTALLATION" = "null" ]; then
            APP_SKIP_INSTALLATION="false"
        fi

        APP_SKIP_ON_VERIFY_FAIL=$(yq e ".additional_apps[$i].skip_on_verify_fail" "$yaml_file")
        if [ -z "$APP_SKIP_ON_VERIFY_FAIL" ] || [ "$APP_SKIP_ON_VERIFY_FAIL" = "null" ]; then
            APP_SKIP_ON_VERIFY_FAIL="$GLOBAL_SKIP_ON_VERIFY_FAIL"
        fi

        ADDITIONAL_APPS+=("$APP_NAME|$APP_SKIP_INSTALLATION|$APP_USE_GLOBAL_KUBECONFIG|$APP_KUBECONFIG|$APP_KUBECONTEXT|$APP_NAMESPACE|$APP_RELEASE_NAME|$APP_CHART_NAME|$APP_REPO_URL|$APP_USERNAME|$APP_PASSWORD|$APP_VALUES_FILE|$APP_INLINE_VALUES|$APP_IMAGE_PULL_SECRET_REPO|$APP_IMAGE_PULL_SECRET_USERNAME|$APP_IMAGE_PULL_SECRET_PASSWORD|$APP_IMAGE_PULL_SECRET_EMAIL|$APP_HELM_FLAGS|$APP_VERIFY_INSTALL|$APP_VERIFY_INSTALL_TIMEOUT|$APP_SKIP_ON_VERIFY_FAIL")
    done

    echo "✔️ Parsing completed."
}

# Function to verify all pods in a namespace are running
verify_pods_running() {
    local namespace=$1
    local kubeconfig_path=$2
    local kubecontext=$3
    local pod_check_timeout=$4
    local skip_on_fail=$5

    echo "🚀 Starting verification of resources in namespace '$namespace'..."
    echo "🔧 Variables:"
    echo "  namespace=$namespace"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  kubecontext=$kubecontext"
    echo "  pod_check_timeout=$pod_check_timeout seconds"
    echo "  skip_on_fail=$skip_on_fail"
    echo "-----------------------------------------"
    
    # Print all resources in the namespace
    echo "📋 Listing all resources in namespace '$namespace'..."
    kubectl get all -n $namespace --kubeconfig $kubeconfig_path --context $kubecontext
    echo "-----------------------------------------"

    echo "Verifying all pods are running in namespace '$namespace' with a timeout of $((pod_check_timeout / 60)) minutes..."
    local end_time=$((SECONDS + pod_check_timeout))

    while [ $SECONDS -lt $end_time ]; do
        non_running_pods=$(kubectl get pods -n $namespace --kubeconfig $kubeconfig_path --context $kubecontext --no-headers | awk '{print $3}' | grep -vE 'Running|Completed' | wc -l)

        if [ $non_running_pods -eq 0 ]; then
            echo "✔️ All pods are running in namespace '$namespace'."
            echo "✔️ Verification of pods in namespace '$namespace' complete."
            return 0
        else
            echo -n "⏳ Waiting for all pods to be running in namespace '$namespace'..."
            wait_with_dots 5 " "
        fi
    done

    if [ "$skip_on_fail" = "true" ]; then
        echo "⚠️  Warning: Timed out waiting for all pods to be running in namespace '$namespace'. Skipping to the next chart."
    else
        echo "❌ Error: Timed out waiting for all pods to be running in namespace '$namespace'."
        exit 1
    fi
}

# Simulated wait_with_dots function for demonstration purposes
wait_with_dots() {
    local seconds=$1
    local message=$2
    for ((i=0; i<seconds; i++)); do
        echo -n "⏳"
        sleep 1
    done
    echo " $message"
}

manage_helm_repo() {
    echo "🚀 Starting Helm repository management..."
    local repo_name="temp-repo"
    local repo_url=$1
    local username=$2
    local password=$3

    echo "🔧 Variables:"
    echo "  repo_name=$repo_name"
    echo "  repo_url=$repo_url"
    echo "  username=$username"
    echo "-----------------------------------------"

    # Function to handle retries
    retry() {
        local n=1
        local max=3
        local delay=5
        while true; do
            "$@" && break || {
                if [[ $n -lt $max ]]; then
                    ((n++))
                    echo "⚠️  Command failed. Attempt $n/$max:"
                    sleep $delay;
                else
                    echo "❌ Command failed after $n attempts."
                    return 1
                fi
            }
        done
    }

    # Check if repo already exists
    if helm repo list | grep -q "$repo_name"; then
        echo "🔍 Helm repository '$repo_name' already exists."
        if [ "$READD_HELM_REPOS" = "true" ]; then
            echo "♻️  Removing and re-adding Helm repository '$repo_name'..."
            retry helm repo remove $repo_name || {
                echo "❌ Failed to remove existing Helm repo '$repo_name'. Exiting."
                exit 1
            }
            retry helm repo add $repo_name $repo_url --username $username --password $password || {
                echo "❌ Failed to re-add Helm repo '$repo_name'. Exiting."
                exit 1
            }
        fi
    else
        echo "➕ Adding Helm repository '$repo_name'..."
        retry helm repo add $repo_name $repo_url --username $username --password $password || {
            echo "❌ Failed to add Helm repo '$repo_name'. Exiting."
            exit 1
        }
    fi

    echo "🔄 Updating Helm repositories..."
    retry helm repo update $repo_name || {
        echo "❌ Failed to update Helm repo '$repo_name'. Exiting."
        exit 1
    }

    echo "✔️ Helm repository management complete."
}
# Function to identify the cloud provider
identify_cloud_provider() {
    local cloud_provider=""
    local node_labels=$(kubectl get nodes -o json | jq -r '.items[].metadata.labels')

    if echo "$node_labels" | grep -q "eks.amazonaws.com"; then
        cloud_provider="AWS EKS"
    elif echo "$node_labels" | grep -q "cloud.google.com/gke-nodepool"; then
        cloud_provider="Google GKE"
    elif echo "$node_labels" | grep -q "kubernetes.azure.com"; then
        cloud_provider="Azure AKS"
    elif echo "$node_labels" | grep -q "oke.oraclecloud.com"; then
        cloud_provider="Oracle OKE"
    else
        echo "⚠️  Cloud provider not identified. Exiting..."
        exit 1
    fi

    echo "$cloud_provider"
}

# Function to handle the cloud-specific installation process
handle_cloud_installation() {
    local cloud_provider="$1"
    shift
    local cloud_install_array=("$@")

    echo "🌩️  Handling installation for $cloud_provider..."

    # Iterate over the cloud_install array
    for item in "${cloud_install_array[@]}"; do
        local type=$(echo "$item" | cut -d':' -f1)
        local name=$(echo "$item" | cut -d':' -f2)

        case "$type" in
            "manifest")
                install_manifest "$name"
                ;;
            "app")
                install_additional_apps "$name"
                ;;
            *)
                echo "⚠️  Unrecognized installation type: $type"
                ;;
        esac
    done
}

# Function to load cloud_install configuration from YAML
load_cloud_install_config() {
    local cloud_provider="$1"
    local yaml_file="$2"
    local installs=()

    # Check if the cloud_install section exists
    cloud_install_exists=$(yq e '.cloud_install' "$yaml_file")

    if [ "$cloud_install_exists" == "null" ]; then
        echo "⚠️  No 'cloud_install' section found in the YAML file. Skipping cloud-specific installations."
        return  # Return empty array
    fi

    # Get installs array for the specific cloud provider
    installs=($(yq e ".cloud_install[] | select(.provider == \"$cloud_provider\") | .installs[] | .type + \":\" + .name" "$yaml_file"))

    if [ ${#installs[@]} -eq 0 ]; then
        echo "⚠️  No installations defined for cloud provider '$cloud_provider' in 'cloud_install'. Skipping cloud-specific installations."
    fi

    echo "${installs[@]}"
}

apply_manifests_from_yaml() {
    local yaml_file=$1
    local global_kubeconfig_path="${KUBECONFIG:-$GLOBAL_KUBECONFIG}"
    local global_kubecontext="${KUBECONTEXT:-$GLOBAL_KUBECONTEXT}"
    local base_path=$(yq e '.base_path' "$yaml_file")

    # Ensure base_path is absolute
    base_path=$(realpath "${base_path:-.}")

    echo "🚀 Starting the application of Kubernetes manifests from YAML file: $yaml_file"
    echo "🔧 Global Variables:"
    echo "  🗂️  global_kubeconfig_path=$global_kubeconfig_path"
    echo "  🌐 global_kubecontext=$global_kubecontext"
    echo "  🗂️  base_path=$base_path"
    echo "  🗂️  installation_files_path=$INSTALLATION_FILES_PATH"
    echo "-----------------------------------------"

    # Check if the manifests section exists
    manifests_exist=$(yq e '.manifests' "$yaml_file")

    if [ "$manifests_exist" == "null" ]; then
        echo "⚠️  Warning: No 'manifests' section found in the YAML file. Skipping manifest application."
        return
    fi

    # Extract manifests from the YAML file
    manifests_length=$(yq e '.manifests | length' "$yaml_file")

    if [ "$manifests_length" -eq 0 ]; then
        echo "⚠️  Warning: 'manifests' section is defined, but no manifests found. Skipping manifest application."
        return
    fi

    for index in $(seq 0 $((manifests_length - 1))); do
        echo "🔄 Processing manifest $((index + 1)) of $manifests_length"

        appname=$(yq e ".manifests[$index].appname" "$yaml_file")
        base_manifest=$(yq e ".manifests[$index].manifest" "$yaml_file")
        overrides_yaml=$(yq e ".manifests[$index].overrides_yaml" "$yaml_file")
        inline_yaml=$(yq e ".manifests[$index].inline_yaml" "$yaml_file")
        use_global_kubeconfig=$(yq e ".manifests[$index].use_global_kubeconfig" "$yaml_file")
        kubeconfig=$(yq e ".manifests[$index].kubeconfig" "$yaml_file")
        kubecontext=$(yq e ".manifests[$index].kubecontext" "$yaml_file")
        skip_installation=$(yq e ".manifests[$index].skip_installation" "$yaml_file")
        verify_install=$(yq e ".manifests[$index].verify_install" "$yaml_file")
        verify_install_timeout=$(yq e ".manifests[$index].verify_install_timeout" "$yaml_file")
        skip_on_verify_fail=$(yq e ".manifests[$index].skip_on_verify_fail" "$yaml_file")
        namespace=$(yq e ".manifests[$index].namespace" "$yaml_file")

        # Determine kubeconfig path and context
        local kubeconfig_path=""
        local context_arg=""
        
        if [ "$use_global_kubeconfig" = true ]; then
            kubeconfig_path="$global_kubeconfig_path"
            context_arg="--context $global_kubecontext"
        else
            if [ -n "$kubeconfig" ] && [ "$kubeconfig" != "null" ]; then
                kubeconfig_path="$base_path/$kubeconfig"
            fi
            if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
                context_arg="--context $kubecontext"
            fi
        fi

        echo "🔧 App Variables for '$appname':"
        echo "  🗂️  base_manifest=$base_manifest"
        echo "  🗂️  overrides_yaml=$overrides_yaml"
        echo "  📄 inline_yaml=${inline_yaml:+Provided}"
        echo "  🌐 use_global_kubeconfig=$use_global_kubeconfig"
        echo "  🗂️  kubeconfig_path=$kubeconfig_path"
        echo "  🌐 kubecontext=$kubecontext"
        echo "  🚫 skip_installation=$skip_installation"
        echo "  🔍 verify_install=$verify_install"
        echo "  ⏰ verify_install_timeout=$verify_install_timeout"
        echo "  ❌ skip_on_verify_fail=$skip_on_verify_fail"
        echo "  🏷️  namespace=$namespace"
        echo "-----------------------------------------"

        # Handle HTTPS file URLs or local base manifest files
        if [ -n "$base_manifest" ] && [ "$base_manifest" != "null" ]; then
            if [[ "$base_manifest" =~ ^https:// ]]; then
                echo "🌐 Downloading manifest from URL: $base_manifest"
                temp_manifest="$INSTALLATION_FILES_PATH/${appname}_manifest.yaml"
                curl -sL "$base_manifest" -o "$temp_manifest"
                if [ $? -ne 0 ]; then
                    echo "❌ Error: Failed to download manifest from URL: $base_manifest"
                    exit 1
                fi
            else
                base_manifest="$base_path/$base_manifest"
                temp_manifest="$INSTALLATION_FILES_PATH/${appname}_manifest.yaml"
                cp "$base_manifest" "$temp_manifest"
            fi
        else
            # If no base manifest, start with inline YAML if provided
            if [ -n "$inline_yaml" ] && [ "$inline_yaml" != "null" ]; then
                echo "📄 Using inline YAML as the base manifest for $appname"
                temp_manifest="$INSTALLATION_FILES_PATH/${appname}_manifest.yaml"
                echo "$inline_yaml" > "$temp_manifest"
            else
                echo "❌ Error: Neither base manifest nor inline YAML provided for app: $appname"
                exit 1
            fi
        fi

        # Convert overrides_yaml to absolute paths
        if [ -n "$overrides_yaml" ] && [ "$overrides_yaml" != "null" ]; then
            overrides_yaml="$base_path/$overrides_yaml"
        fi

        # Merge inline YAML with the base manifest if provided
        if [ -n "$inline_yaml" ] && [ "$inline_yaml" != "null" ] && [ -f "$temp_manifest" ]; then
            echo "🔄 Merging inline YAML for $appname into the base manifest"
            echo "$inline_yaml" | yq eval-all 'select(filename == "'"$temp_manifest"'") * select(filename == "-")' - "$temp_manifest" > "${temp_manifest}_merged"
            mv "${temp_manifest}_merged" "$temp_manifest"
        fi

        # Merge overrides if provided
        if [ -f "$overrides_yaml" ]; then
            echo "🔄 Merging overrides from $overrides_yaml into $temp_manifest"
            yq eval-all 'select(filename == "'"$temp_manifest"'") * select(filename == "'"$overrides_yaml"'")' "$temp_manifest" "$overrides_yaml" > "${temp_manifest}_merged"
            mv "${temp_manifest}_merged" "$temp_manifest"
        else
            echo "⚠️  No overrides YAML file found for app: $appname. Proceeding with base/inline manifest."
        fi

        echo "📄 Applying manifest for app: $appname in namespace: ${namespace:-default}"
        kubectl apply -f "$temp_manifest" --namespace "${namespace:-default}" --kubeconfig "$kubeconfig_path" $context_arg
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to apply manifest for app: $appname"
            exit 1
        fi
        echo "✔️ Successfully applied manifest for app: $appname"

        if [ "$verify_install" = true ]; then
            echo "🔍 Verifying installation of app: $appname in namespace: ${namespace:-default}"
            end_time=$((SECONDS + verify_install_timeout))
            while [ $SECONDS -lt $end_time ]; do
                non_running_pods=$(kubectl get pods -n "${namespace:-default}" --kubeconfig "$kubeconfig_path" $context_arg --no-headers | awk '{print $3}' | grep -vE 'Running|Completed' | wc -l)
                if [ "$non_running_pods" -eq 0 ]; then
                    echo "✔️ All pods for app: $appname are running in namespace: ${namespace:-default}."
                    break
                else
                    echo "⏳ Waiting for all pods to be running in namespace: ${namespace:-default} for app: $appname..."
                    sleep 5
                fi
            done

            if [ "$non_running_pods" -ne 0 ]; then
                if [ "$skip_on_verify_fail" = true ]; then
                    echo "⚠️  Warning: Verification failed for app: $appname, but skipping as per configuration."
                else
                    echo "❌ Error: Verification failed for app: $appname in namespace: ${namespace:-default}."
                    exit 1
                fi
            fi
        fi

        # Clean up the temporary manifest file
        rm -f "$temp_manifest"
    done

    echo "✅ All applicable manifests applied successfully."
    echo "-----------------------------------------"
}


# Function to install manifest-based apps
install_manifest() {
    local manifest_name="$1"
    echo "🚀 Applying manifest: $manifest_name"
    # Placeholder for applying the manifest
    echo "⚠️  Placeholder: Add commands to apply manifest $manifest_name here."
    # Example:
    # kubectl apply -f path-to-$manifest_name.yaml
    echo "✅ Manifest $manifest_name applied successfully."
}

# Function to install additional apps
install_additional_apps() {
    local app_name="$1"
    echo "🚀 Deploying additional app: $app_name"
    # Placeholder for deploying additional apps
    echo "⚠️  Placeholder: Add commands to deploy additional app $app_name here."
    # Example:
    # kubectl apply -f path-to-$app_name.yaml
    echo "✅ Additional app $app_name deployed successfully."
}

run_k8s_commands_from_yaml() {
    local yaml_file=$1
    local global_kubeconfig_path="${KUBECONFIG:-$GLOBAL_KUBECONFIG}"
    local global_kubecontext="${KUBECONTEXT:-$GLOBAL_KUBE_CONTEXT}"
    local base_path=$(yq e '.base_path' "$yaml_file")

    # Ensure base_path is absolute
    base_path=$(realpath "${base_path:-.}")

    # Check if the run_commands flag is set to true
    local run_commands=$(yq e '.run_commands // "false"' "$yaml_file")

    if [ "$run_commands" != "true" ]; then
        echo "⏩ Command execution is disabled (run_commands is not true). Skipping."
        return
    fi

    echo "🚀 Starting execution of Kubernetes commands from YAML file: $yaml_file"
    echo "🔧 Global Variables:"
    echo "  🗂️  global_kubeconfig_path=$global_kubeconfig_path"
    echo "  🌐 global_kubecontext=$global_kubecontext"
    echo "  🗂️  base_path=$base_path"
    echo "  🗂️  installation_files_path=$INSTALLATION_FILES_PATH"
    echo "-----------------------------------------"

    # Check if the commands section exists
    commands_exist=$(yq e '.commands' "$yaml_file")

    if [ "$commands_exist" == "null" ]; then
        echo "⚠️  Warning: No 'commands' section found in the YAML file. Skipping command execution."
        return
    fi

    # Extract commands from the YAML file
    commands_length=$(yq e '.commands | length' "$yaml_file")

    if [ "$commands_length" -eq 0 ]; then
        echo "⚠️  Warning: 'commands' section is defined, but no commands found. Skipping command execution."
        return
    fi

    for index in $(seq 0 $((commands_length - 1))); do
        echo "🔄 Executing command set $((index + 1)) of $commands_length"

        # Write the command stream to a temporary file in the installation files directory
        command_stream_file="$INSTALLATION_FILES_PATH/command_stream_$index.sh"
        yq e ".commands[$index].command_stream" "$yaml_file" > "$command_stream_file"
        command_stream=$(<"$command_stream_file")
        rm "$command_stream_file"

        use_global_kubeconfig=$(yq e ".commands[$index].use_global_kubeconfig // false" "$yaml_file")
        skip_installation=$(yq e ".commands[$index].skip_installation // false" "$yaml_file")
        verify_install=$(yq e ".commands[$index].verify_install // false" "$yaml_file")
        verify_install_timeout=$(yq e ".commands[$index].verify_install_timeout // 200" "$yaml_file")
        skip_on_verify_fail=$(yq e ".commands[$index].skip_on_verify_fail // false" "$yaml_file")
        namespace=$(yq e ".commands[$index].namespace // \"default\"" "$yaml_file")

        # Determine kubeconfig path and context
        local kubeconfig_path=""
        local context_arg=""
        
        if [ "$use_global_kubeconfig" = true ]; then
            kubeconfig_path="$global_kubeconfig_path"
            context_arg="--context $global_kubecontext"
        else
            kubeconfig=$(yq e ".commands[$index].kubeconfig" "$yaml_file")
            kubecontext=$(yq e ".commands[$index].kubecontext" "$yaml_file")
            if [ -n "$kubeconfig" ] && [ "$kubeconfig" != "null" ]; then
                kubeconfig_path="$base_path/$kubeconfig"
            fi
            if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
                context_arg="--context $kubecontext"
            fi
        fi

        # Print all variables
        echo "🔧 Command Set Variables:"
        echo "  📜 command_stream=$command_stream"
        echo "  🌐 use_global_kubeconfig=$use_global_kubeconfig"
        echo "  🗂️  kubeconfig_path=$kubeconfig_path"
        echo "  🌐 context_arg=$context_arg"
        echo "  🚫 skip_installation=$skip_installation"
        echo "  🔍 verify_install=$verify_install"
        echo "  ⏰ verify_install_timeout=$verify_install_timeout"
        echo "  ❌ skip_on_verify_fail=$skip_on_verify_fail"
        echo "  🏷️  namespace=$namespace"
        echo "-----------------------------------------"

        # Validate command_stream
        if [ -z "$command_stream" ] || [ "$command_stream" == "null" ]; then
            echo "⚠️  Warning: No commands provided in command_stream for set $((index + 1)). Skipping."
            continue
        fi

        # Skip installation if required
        if [ "$skip_installation" = true ]; then
            echo "⏩ Skipping command execution as per configuration."
            continue
        fi

        # Handle the command as a whole without appending namespace or kubeconfig
        full_cmd="KUBECONFIG=\"$kubeconfig_path\" $command_stream"
        echo "🔄 Executing command: $full_cmd"
        eval "$full_cmd"
        if [ $? -ne 0 ]; then
            echo "❌ Error: Command failed: $command_stream"
            if [ "$skip_on_verify_fail" = true ]; then
                echo "⚠️  Skipping further commands in this set due to failure."
                break
            else
                echo "❌ Exiting due to command failure."
                exit 1
            fi
        fi

        if [ "$verify_install" = true ]; then
            echo "🔍 Verifying installation in namespace: $namespace"
            end_time=$((SECONDS + verify_install_timeout))
            while [ $SECONDS -lt $end_time ]; do
                non_running_pods=$(kubectl get pods -n "$namespace" --kubeconfig "$kubeconfig_path" $context_arg --no-headers | awk '{print $3}' | grep -vE 'Running|Completed' | wc -l)
                if [ "$non_running_pods" -eq 0 ]; then
                    echo "✔️ All pods are running in namespace: $namespace."
                    break
                else
                    echo "⏳ Waiting for all pods to be running in namespace: $namespace..."
                    sleep 5
                fi
            done

            if [ "$non_running_pods" -ne 0 ]; then
                if [ "$skip_on_verify_fail" = true ]; then
                    echo "⚠️  Warning: Verification failed, but skipping as per configuration."
                else
                    echo "❌ Error: Verification failed in namespace: $namespace. Exiting."
                    exit 1
                fi
            fi
        fi
    done

    echo "✅ All commands executed successfully."
    echo "-----------------------------------------"
}

# Function to fetch and display summary information
display_summary() {
    echo "========================================="
    echo "           📋 Summary - Installations    "
    echo "========================================="

    # Summary of all Helm chart installations (including controller, UI, workers, and additional apps)
    echo "🛠️ **Application Installations Summary**:"

    # Helper function to check Helm release status and list Helm releases
    check_helm_release_status() {
        local release_name=$1
        local namespace=$2
        local kubeconfig=$3
        local kubecontext=$4

        echo "-----------------------------------------"
        echo "🚀 **Helm Release: $release_name**"
        if helm status "$release_name" --namespace "$namespace" --kubeconfig "$kubeconfig" --kube-context "$kubecontext" > /dev/null 2>&1; then
            echo "✔️ Release '$release_name' in namespace '$namespace' is successfully installed."
            echo "🔍 **Helm List Output**:"
            helm list --namespace "$namespace" --kubeconfig "$kubeconfig" --kube-context "$kubecontext" || echo "⚠️ Warning: Failed to list Helm releases in namespace '$namespace'."
        else
            echo "⚠️ Warning: Release '$release_name' in namespace '$namespace' encountered an issue."
        fi
        echo "-----------------------------------------"
    }

    # Kubeslice Controller Installation
    if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ] && [ "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" = "false" ]; then
        check_helm_release_status "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT"
    else
        echo "⏩ **Kubeslice Controller** installation was skipped or disabled."
    fi

    # Worker Cluster Installations
    if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
        for ((i=0; i<${#KUBESLICE_WORKERS[@]}; i++)); do
            # Extract variables for each worker cluster
            worker_name=$(yq e ".kubeslice_worker_egs[$i].name" "$EGS_INPUT_YAML")
            skip_installation=$(yq e ".kubeslice_worker_egs[$i].skip_installation" "$EGS_INPUT_YAML")
            kubeconfig=$(yq e ".kubeslice_worker_egs[$i].kubeconfig" "$EGS_INPUT_YAML")
            kubecontext=$(yq e ".kubeslice_worker_egs[$i].kubecontext" "$EGS_INPUT_YAML")

            # Use global kubeconfig and kubecontext if specific ones are null
            if [ -z "$kubeconfig" ] || [ "$kubeconfig" = "null" ]; then
                kubeconfig="$GLOBAL_KUBECONFIG"
            fi
            if [ -z "$kubecontext" ] || [ "$kubecontext" = "null" ]; then
                kubecontext="$GLOBAL_KUBECONTEXT"
            fi

            namespace=$(yq e ".kubeslice_worker_egs[$i].namespace" "$EGS_INPUT_YAML")
            release_name=$(yq e ".kubeslice_worker_egs[$i].release" "$EGS_INPUT_YAML")
            chart_name=$(yq e ".kubeslice_worker_egs[$i].chart" "$EGS_INPUT_YAML")

            if [ "$skip_installation" = "false" ]; then
                check_helm_release_status "$release_name" "$namespace" "$kubeconfig" "$kubecontext"
            else
                echo "⏩ **Worker Cluster '$worker_name'** installation was skipped."
            fi
        done
    else
        echo "⏩ **Worker installation was skipped or disabled.**"
    fi

    # Additional Application Installations
    if [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "true" ]; then
        for ((i=0; i<${#ADDITIONAL_APPS[@]}; i++)); do
            # Extract variables for each additional application
            app_name=$(yq e ".additional_apps[$i].name" "$EGS_INPUT_YAML")
            skip_installation=$(yq e ".additional_apps[$i].skip_installation" "$EGS_INPUT_YAML")
            kubeconfig=$(yq e ".additional_apps[$i].kubeconfig" "$EGS_INPUT_YAML")
            kubecontext=$(yq e ".additional_apps[$i].kubecontext" "$EGS_INPUT_YAML")

            # Use global kubeconfig and kubecontext if specific ones are null
            if [ -z "$kubeconfig" ] || [ "$kubeconfig" = "null" ]; then
                kubeconfig="$GLOBAL_KUBECONFIG"
            fi
            if [ -z "$kubecontext" ] || [ "$kubecontext" = "null" ]; then
                kubecontext="$GLOBAL_KUBECONTEXT"
            fi

            namespace=$(yq e ".additional_apps[$i].namespace" "$EGS_INPUT_YAML")
            release_name=$(yq e ".additional_apps[$i].release" "$EGS_INPUT_YAML")
            chart_name=$(yq e ".additional_apps[$i].chart" "$EGS_INPUT_YAML")

            if [ "$skip_installation" = "false" ]; then
                check_helm_release_status "$release_name" "$namespace" "$kubeconfig" "$kubecontext"
            else
                echo "⏩ **Additional Application '$app_name'** installation was skipped."
            fi
        done
    else
        echo "⏩ **Additional application installation was skipped or disabled.**"
    fi

    echo "========================================="
    echo "           📋 Summary - Details          "
    echo "========================================="

    # Fetch the kubeslice-ui-proxy service LoadBalancer URL using the controller's kubeconfig and context
    if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$KUBESLICE_UI_SKIP_INSTALLATION" = "false" ]; then
        echo "🔍 **Service Information for Kubeslice UI**:"
        kubectl get svc kubeslice-ui-proxy -n "$KUBESLICE_UI_NAMESPACE" --kubeconfig "$KUBESLICE_CONTROLLER_KUBECONFIG" --context "$KUBESLICE_CONTROLLER_KUBECONTEXT" || echo "⚠️ Warning: Failed to get services in namespace '$KUBESLICE_UI_NAMESPACE'."

        ui_proxy_url=$(kubectl get svc kubeslice-ui-proxy -n "$KUBESLICE_UI_NAMESPACE" --kubeconfig "$KUBESLICE_CONTROLLER_KUBECONFIG" --context "$KUBESLICE_CONTROLLER_KUBECONTEXT" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -z "$ui_proxy_url" ]; then
            ui_proxy_url=$(kubectl get svc kubeslice-ui-proxy -n "$KUBESLICE_UI_NAMESPACE" --kubeconfig "$KUBESLICE_CONTROLLER_KUBECONFIG" --context "$KUBESLICE_CONTROLLER_KUBECONTEXT" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        fi
        if [ -n "$ui_proxy_url" ]; then
            echo "🔗 **Kubeslice UI Proxy LoadBalancer URL**: $ui_proxy_url"
        else
            echo "⚠️ Warning: Kubeslice UI Proxy LoadBalancer URL not available."
        fi
    else
        echo "⏩ **Kubeslice UI installation was skipped or disabled.**"
    fi

    # Fetch the token for each project provided in the input YAML
    if [ "$ENABLE_PROJECT_CREATION" = "true" ]; then
        for project in "${KUBESLICE_PROJECTS[@]}"; do
            IFS="|" read -r project_name project_username <<< "$project"
            token=$(kubectl get secret "kubeslice-rbac-rw-$project_username" -o jsonpath="{.data.token}" -n "kubeslice-$project_name" --kubeconfig "$KUBESLICE_CONTROLLER_KUBECONFIG" --context "$KUBESLICE_CONTROLLER_KUBECONTEXT" 2>/dev/null | base64 --decode || echo "")
            if [ -n "$token" ]; then
                echo "🔑 **Token for project '$project_name' (username: $project_username)**: $token"
            else
                echo "⚠️ Warning: Token for project '$project_name' (username: $project_username) not available."
            fi
        done
    else
        echo "⏩ **Project creation was skipped or disabled.**"
    fi

    echo "========================================="
    echo "           📋 Helm List - All Namespaces "
    echo "========================================="

    # Run helm list -A to list all releases across all namespaces
    if helm list -A --kubeconfig "$KUBESLICE_CONTROLLER_KUBECONFIG" --kube-context "$KUBESLICE_CONTROLLER_KUBECONTEXT" > /dev/null 2>&1; then
        echo "🔍 **Helm List Output (All Namespaces)**:"
        helm list -A --kubeconfig "$KUBESLICE_CONTROLLER_KUBECONFIG" --kube-context "$KUBESLICE_CONTROLLER_KUBECONTEXT" || echo "⚠️ Warning: Failed to list Helm releases across all namespaces."
    else
        echo "⚠️ Warning: Unable to run helm list -A."
    fi

    echo "========================================="
    echo "          🏁 Summary Output Complete      "
    echo "========================================="
}

fetch_k8s_cluster_endpoint() {
    local kubeconfig=$1
    local kubecontext=$2

    echo "🔍 Fetching Kubernetes cluster endpoint..."
    echo "  kubeconfig: $kubeconfig"
    echo "  kubecontext: $kubecontext"

    if [ -z "$kubecontext" ]; then
        echo "⚠️ Warning: kubecontext is empty. Using default context."
        kubecontext=$(kubectl --kubeconfig="$kubeconfig" config current-context)
    fi

    echo "  Using kubecontext: $kubecontext"

    # Extract the cluster name associated with the context
    local cluster_name
    cluster_name=$(kubectl --kubeconfig="$kubeconfig" --context="$kubecontext" config view -o jsonpath='{.contexts[?(@.name == "'$kubecontext'")].context.cluster}')

    echo "  Extracted cluster name from context: $cluster_name"

    # Now fetch the endpoint for that cluster
    local endpoint
    echo "🔍 Attempting to fetch endpoint from kubeconfig..."
    endpoint=$(kubectl --kubeconfig="$kubeconfig" config view -o jsonpath='{.clusters[?(@.name == "'$cluster_name'")].cluster.server}')
    echo "  Output from kubectl config view: '$endpoint'"

    if [ -z "$endpoint" ]; then
        echo "⚠️ Warning: Failed to fetch the Kubernetes cluster endpoint from kubeconfig for cluster '$cluster_name'."

        echo "🔍 Attempting to fetch the endpoint using 'kubectl cluster-info'..."
        local cluster_info_output
        cluster_info_output=$(kubectl --kubeconfig="$kubeconfig" --context="$kubecontext" cluster-info)
        echo "  Full output from kubectl cluster-info: '$cluster_info_output'"

        # Extract the first occurrence of a URL in the cluster-info output
        endpoint=$(echo "$cluster_info_output" | grep -oP '(?<=Kubernetes control plane is running at )https?://[^ ]+')

        if [ -z "$endpoint" ]; then
            echo "⚠️ Warning: Failed to fetch the Kubernetes cluster endpoint using 'kubectl cluster-info'."

            # Fallback: Check the first cluster entry in kubeconfig as a last resort
            echo "🔍 Attempting fallback to first cluster entry in kubeconfig..."
            endpoint=$(kubectl --kubeconfig="$kubeconfig" config view -o jsonpath='{.clusters[0].cluster.server}')
            echo "  Fallback kubeconfig view output: '$endpoint'"

            if [ -z "$endpoint" ]; then
                echo "❌ Critical: All methods to fetch the Kubernetes cluster endpoint have failed."
            else
                echo "✔️ Fallback successful: Fetched endpoint: $endpoint"
            fi
        else
            echo "✔️ Successfully fetched endpoint using 'kubectl cluster-info': $endpoint"
        fi
    else
        echo "✔️ Successfully fetched endpoint from kubeconfig: $endpoint"
    fi

    echo "$endpoint"
}


install_or_upgrade_helm_chart() {
    local skip_installation=$1
    local release_name=$2
    local chart_name=$3
    local namespace=$4
    local specific_use_global_kubeconfig=$5
    local specific_kubeconfig_path=$6
    local specific_kubecontext=$7
    local repo_url=$8
    local username=$9
    local password=${10}
    local values_file=${11}
    local inline_values=${12}
    local image_pull_secret_repo=${13}
    local image_pull_secret_username=${14}
    local image_pull_secret_password=${15}
    local image_pull_secret_email=${16}
    local helm_flags=${17}
    local specific_use_local_charts=${18}
    local local_charts_path=${19}
    local version=${20}
    local verify_install=${21}
    local verify_install_timeout=${22}
    local skip_on_verify_fail=${23}

    echo "-----------------------------------------"
    echo "🚀 Processing Helm chart installation"
    echo "Release Name: $release_name"
    echo "Chart Name: $chart_name"
    echo "Namespace: $namespace"
    echo "-----------------------------------------"

    # Get the directory where the script is located
    local script_dir=$(dirname "$(realpath "$0")")

    local kubeconfig_path="$specific_kubeconfig_path"
    if [ -z "$kubeconfig_path" ] || [ "$kubeconfig_path" = "null" ]; then
        kubeconfig_path="$GLOBAL_KUBECONFIG"
    fi

    local kubecontext="$specific_kubecontext"
    if [ -z "$kubecontext" ] || [ "$kubecontext" = "null" ]; then
        kubecontext="$GLOBAL_KUBECONTEXT"
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--kube-context $kubecontext"
    fi

    # Create a unique directory for this run relative to the script's directory
    local run_dir="$script_dir/installation-files/run/helm_run_$(date +%Y%m%d_%H%M%S)_${release_name}"
    mkdir -p "$run_dir"
    echo "🗂️  Created run directory: $run_dir"

    echo "🔧 Variables:"
    echo "  skip_installation=$skip_installation"
    echo "  release_name=$release_name"
    echo "  chart_name=$chart_name"
    echo "  namespace=$namespace"
    echo "  specific_use_global_kubeconfig=$specific_use_global_kubeconfig"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  kubecontext=$kubecontext"
    echo "  repo_url=$repo_url"
    echo "  username=$username"
    echo "  password=$password"
    echo "  values_file=$values_file"
    echo "  inline_values=$inline_values"
    echo "  image_pull_secret_repo=$image_pull_secret_repo"
    echo "  image_pull_secret_username=$image_pull_secret_username"
    echo "  image_pull_secret_password=$image_pull_secret_password"
    echo "  image_pull_secret_email=$image_pull_secret_email"
    echo "  helm_flags=$helm_flags"
    echo "  specific_use_local_charts=$specific_use_local_charts"
    echo "  local_charts_path=$local_charts_path"
    echo "  version=$version"
    echo "  verify_install=$verify_install"
    echo "  verify_install_timeout=$verify_install_timeout"
    echo "  skip_on_verify_fail=$skip_on_verify_fail"
    echo "-----------------------------------------"

    # Check if installation should be skipped
    if [ "$skip_installation" = "true" ]; then
        echo "⏩ Skipping installation of Helm chart '$chart_name' in namespace '$namespace' as per configuration."
        return
    fi

    # Determine the chart path based on whether local charts are used
    local use_local_charts_effective="${specific_use_local_charts:-$USE_LOCAL_CHARTS}"
    if [ "$use_local_charts_effective" = "true" ]; then
        chart_name="$local_charts_path/$chart_name"
        echo "🗂️  Using local chart at path '$chart_name'..."
    elif [ -n "$repo_url" ]; then
        manage_helm_repo "$repo_url" "$username" "$password"
        chart_name="temp-repo/$chart_name"
    fi

    # Create the namespace if it doesn't exist
    echo "🔍 Checking if namespace '$namespace' exists..."
    kubectl get namespace $namespace --kubeconfig $kubeconfig_path --context $kubecontext || kubectl create namespace $namespace --kubeconfig $kubeconfig_path --context $kubecontext
    echo "✔️ Namespace '$namespace' is ready."


# Determine if the current release is the KubeSlice controller
if [[ "$release_name" == *"controller"* ]]; then
    if [ -z "$inline_values" ] || [ "$inline_values" = "{}" ]; then
        echo "⚠️ Warning: Inline values are empty or not provided."
        echo "🔍 Attempting to fetch the cluster endpoint..."
        
        local cluster_endpoint
        cluster_endpoint=$(fetch_k8s_cluster_endpoint "$kubeconfig_path" "$kubecontext")
        
        if [ -z "$cluster_endpoint" ]; then
            echo "⚠️ Warning: Failed to fetch cluster endpoint. Proceeding without setting the controller endpoint."
        else
            # Clean and sanitize the endpoint
            cluster_endpoint=$(echo "$cluster_endpoint" | grep -oP 'https?://[^ ]+' | head -n 1 | sed "s/[']$//")
            # Initialize inline_values with the fetched endpoint
            inline_values=$(echo "{}" | yq e ".kubeslice.controller.endpoint = \"$cluster_endpoint\"" -)
            echo "✔️ Inline values created with fetched cluster endpoint: $cluster_endpoint"
        fi
    elif [ -z "$(echo "$inline_values" | yq e '.kubeslice.controller.endpoint' -)" ]; then
        echo "🔍 No endpoint found in inline values. Attempting to fetch the cluster endpoint..."
        
        local cluster_endpoint
        cluster_endpoint=$(fetch_k8s_cluster_endpoint "$kubeconfig_path" "$kubecontext")
        
        if [ -z "$cluster_endpoint" ]; then
            echo "⚠️ Warning: Failed to fetch cluster endpoint. Proceeding without setting the controller endpoint."
        else
            # Clean and sanitize the endpoint
            cluster_endpoint=$(echo "$cluster_endpoint" | grep -oP 'https?://[^ ]+' | head -n 1 | sed "s/[']$//")
            # Merge the fetched endpoint into the existing inline_values
            inline_values=$(echo "$inline_values" | yq e ".kubeslice.controller.endpoint = \"$cluster_endpoint\"" -)
            echo "✔️ Inline values updated with fetched cluster endpoint: $cluster_endpoint"
        fi
    else
        # Double-check the endpoint actually exists
        local existing_endpoint=$(echo "$inline_values" | yq e '.kubeslice.controller.endpoint' -)
        if [ -z "$existing_endpoint" ]; then
            echo "⚠️ Warning: Detected an empty endpoint in inline values, fetching again."
            local cluster_endpoint
            cluster_endpoint=$(fetch_k8s_cluster_endpoint "$kubeconfig_path" "$kubecontext")
            
            if [ -z "$cluster_endpoint" ]; then
                echo "⚠️ Warning: Failed to fetch cluster endpoint. Proceeding without setting the controller endpoint."
            else
                # Clean and sanitize the endpoint
                cluster_endpoint=$(echo "$cluster_endpoint" | grep -oP 'https?://[^ ]+' | head -n 1 | sed "s/[']$//")
                inline_values=$(echo "$inline_values" | yq e ".kubeslice.controller.endpoint = \"$cluster_endpoint\"" -)
                echo "✔️ Inline values updated with fetched cluster endpoint: $cluster_endpoint"
            fi
        else
            echo "✔️ Endpoint is already provided in inline values. No need to override."
        fi
    fi

    # Final sanity check to ensure inline_values is correctly formed
    echo "🛠 Final inline_values:"
    echo "$inline_values" | yq e
fi


    # Function to create a values file from inline values, ensuring uniqueness
    create_values_file() {
        local inline_values=$1
        local base_name=$2
        local values_file_path="$run_dir/${base_name}.yaml"
        local counter=1

        # Ensure the file name is unique by appending an incremental number if needed
        while [ -f "$values_file_path" ]; do
            values_file_path="$run_dir/${base_name}_$counter.yaml"
            counter=$((counter + 1))
        done

        # Use yq to parse and create a valid YAML file
        echo "$inline_values" | yq eval -P - > "$values_file_path"
        
        # Return only the file path
        echo "$values_file_path"
    }



# Print the entire inline_values for debugging
echo "🔍 Debugging: Full inline_values content"
echo "$inline_values"

# Extract the values from inline_values using yq
image_pull_secret_repo=$(echo "$inline_values" | yq e '.imagePullSecrets.repository' -)
image_pull_secret_username=$(echo "$inline_values" | yq e '.imagePullSecrets.username' -)
image_pull_secret_password=$(echo "$inline_values" | yq e '.imagePullSecrets.password' -)

# Handle cases where yq might return 'null' or an empty value
if [ "$image_pull_secret_repo" = "null" ] || [ -z "$image_pull_secret_repo" ]; then
    image_pull_secret_repo=""
fi

if [ "$image_pull_secret_username" = "null" ] || [ -z "$image_pull_secret_username" ]; then
    image_pull_secret_username=""
fi

if [ "$image_pull_secret_password" = "null" ] || [ -z "$image_pull_secret_password" ]; then
    image_pull_secret_password=""
fi

# Debugging print to confirm parsed inline values
echo "🔍 Debugging: Parsed inline chart values"
echo "   Parsed Repository: $image_pull_secret_repo"
echo "   Parsed Username: $image_pull_secret_username"
echo "   Parsed Password: [Hidden for security]"

# Determine which image pull secrets to use (global or chart-level)
# If the inline values exist and are non-empty, use them; otherwise, fall back to global values

# Check and assign the repository URL
if [ -n "$image_pull_secret_repo" ]; then
    image_pull_secret_repo_used=$image_pull_secret_repo
    echo "✔️ Using inline repository URL: $image_pull_secret_repo_used"
else
    image_pull_secret_repo_used=$GLOBAL_IMAGE_PULL_SECRET_REPO
    if [ -n "$image_pull_secret_repo_used" ]; then
        echo "✔️ Using global repository URL: $image_pull_secret_repo_used"
    else
        echo "❌ Error: Repository URL is missing!"
        echo "🔗 You can generate the required image pull secrets using the following URL:"
        echo "   https://avesha.io/kubeslice-registration"
        exit 1
    fi
fi

# Check and assign the username
if [ -n "$image_pull_secret_username" ]; then
    image_pull_secret_username_used=$image_pull_secret_username
    echo "✔️ Using inline username: $image_pull_secret_username_used"
else
    image_pull_secret_username_used=$GLOBAL_IMAGE_PULL_SECRET_USERNAME
    if [ -n "$image_pull_secret_username_used" ]; then
        echo "✔️ Using global username: $image_pull_secret_username_used"
    else
        echo "❌ Error: Username is missing!"
        echo "🔗 You can generate the required image pull secrets using the following URL:"
	echo "   https://avesha.io/kubeslice-registration"
        exit 1
    fi
fi

# Check and assign the password
if [ -n "$image_pull_secret_password" ]; then
    image_pull_secret_password_used=$image_pull_secret_password
    echo "✔️ Using inline password: [Hidden for security]"
else
    image_pull_secret_password_used=$GLOBAL_IMAGE_PULL_SECRET_PASSWORD
    if [ -n "$image_pull_secret_password_used" ]; then
        echo "✔️ Using global password: [Hidden for security]"
    else
        echo "❌ Error: Password is missing!"
        echo "🔗 You can generate the required image pull secrets using the following URL:"
	echo "   https://avesha.io/kubeslice-registration"
        exit 1
    fi
fi

# Final debugging print to confirm values used
echo "📋 Final values being used:"
echo "   Repository: $image_pull_secret_repo_used"
echo "   Username: $image_pull_secret_username_used"
echo "   Password: [Hidden for security]"

# Create inline values for imagePullSecrets
image_pull_secrets_inline=$(cat <<EOF
imagePullSecrets:
  repository: $image_pull_secret_repo_used
  username: $image_pull_secret_username_used
  password: $image_pull_secret_password_used
EOF
)

echo "✅ Image pull secrets configured successfully."



    # Define the base Helm command
    helm_cmd="helm --namespace $namespace --kubeconfig $kubeconfig_path"

    # Determine whether to install or upgrade
    if helm status $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
        operation="upgrade"
        echo "🔄 Helm release '$release_name' already exists. Preparing to upgrade..."
    else
        operation="install"
        echo "📦 Helm release '$release_name' does not exist. Preparing to install..."
    fi

    # Construct the Helm command
    helm_cmd="$helm_cmd $operation $release_name $chart_name"

    # Add chart version if specified
    if [ -n "$version" ] && [ "$version" != "null" ]; then
        helm_cmd="$helm_cmd --version $version"
        echo "🗂️  Using chart version: $version"
    fi

    # Add the primary values file if specified and valid
    if [ -n "$values_file" ] && [ "$values_file" != "null" ] && [ -f "$values_file" ]; then
        helm_cmd="$helm_cmd -f $values_file"
        echo "🗂  Using primary values file: $values_file"
    else
        echo "⚠️  Skipping primary values file as it is not valid: $values_file"
    fi

    # Add the imagePullSecrets inline values if they exist
    if [ -n "$image_pull_secrets_inline" ]; then
        image_pull_secrets_file=$(create_values_file "$image_pull_secrets_inline" "generated-imagepullsecret-values")
        helm_cmd="$helm_cmd -f $image_pull_secrets_file"
        echo "🔐 Using imagePullSecrets from $image_pull_secret_repo_used"
    fi

    # Prepare and add inline values if provided (these should be last)
    if [ -n "$inline_values" ] && [ "$inline_values" != "null" ]; then
        inline_values_file=$(create_values_file "$inline_values" "generated-inline-values")
        helm_cmd="$helm_cmd -f $inline_values_file"
        echo "🗂  Using inline values file: $inline_values_file"
    fi


    # Use the merged values file
    if [ -n "$values_file" ] && [ "$values_file" != "null" ] && [ -f "$values_file" ]; then
        helm_cmd="$helm_cmd -f $values_file"
        echo "Using merged values file: $values_file"
    else
        echo "Skipping values file as it is not valid: $values_file"
    fi

    # Append additional Helm flags
    if [ -n "$helm_flags" ] && [ "$helm_flags" != "null" ]; then
        helm_cmd="$helm_cmd $helm_flags"
        echo "🔧 Additional Helm flags: $helm_flags"
    fi

    # Print the final Helm command to be executed
    echo "🔧 Final Helm command: $helm_cmd"

    # Execute the Helm command
    eval $helm_cmd

    # Verify that all pods are running if the flag is enabled
    if [ "$verify_install" = "true" ]; then
        verify_pods_running $namespace $kubeconfig_path $kubecontext $verify_install_timeout $skip_on_verify_fail
    fi

    echo "✅ Helm chart '$release_name' processed successfully in namespace '$namespace'."
    echo ""

    # Remove the temporary Helm repository if added
    if [ "$use_local_charts_effective" != "true" ] && [ -n "$repo_url" ]; then
        helm repo remove temp-repo
    fi

    # Save the values file used in the installation
    if [ -n "$values_file" ] && [ "$values_file" != "null" ] && [ -f "$values_file" ]; then
        cp "$values_file" "$INSTALLATION_FILES_PATH/${release_name}_values.yaml"
    fi

    echo "-----------------------------------------"
    echo "✔️  Completed processing for release: $release_name"
    echo "-----------------------------------------"
    echo "✔️ Helm chart installation or upgrade complete."
}

create_projects_in_controller() {
    echo "🚀 Starting project creation in controller cluster..."
    local kubeconfig_path="$KUBESLICE_CONTROLLER_KUBECONFIG"
    local context_arg=""
    
    if [ -n "$KUBESLICE_CONTROLLER_KUBECONTEXT" ]; then
        context_arg="--context $KUBESLICE_CONTROLLER_KUBECONTEXT"
    fi
    
    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  context_arg=$context_arg"
    echo "  namespace=$namespace"
    echo "-----------------------------------------"

    for project in "${KUBESLICE_PROJECTS[@]}"; do
        IFS="|" read -r project_name project_username <<< "$project"
        
        echo "-----------------------------------------"
        echo "🚀 Creating project '$project_name' in namespace '$namespace'"
        echo "-----------------------------------------"
        
        cat <<EOF > "$INSTALLATION_FILES_PATH/${project_name}_project.yaml"
apiVersion: controller.kubeslice.io/v1alpha1
kind: Project
metadata:
  name: $project_name
  namespace: $namespace
spec:
  serviceAccount:
    readWrite:
      - $project_username
EOF

        kubectl apply -f "$INSTALLATION_FILES_PATH/${project_name}_project.yaml" --kubeconfig $kubeconfig_path $context_arg -n $namespace
        echo "🔍 Verifying project '$project_name' creation..."
        kubectl get project -n $namespace --kubeconfig $kubeconfig_path $context_arg | grep $project_name

        echo "-----------------------------------------"
        echo "✔️  Project '$project_name' created successfully in namespace '$namespace'."
        echo "-----------------------------------------"
    done
    echo "✔️ Project creation in controller cluster complete."
}

# Function to register clusters in the controller namespace
register_clusters_in_controller() {
    echo "🚀 Starting cluster registration in controller cluster..."
    local kubeconfig_path="$KUBESLICE_CONTROLLER_KUBECONFIG"
    local context_arg=""
    
    if [ -n "$KUBESLICE_CONTROLLER_KUBECONTEXT" ]; then
        context_arg="--context $KUBESLICE_CONTROLLER_KUBECONTEXT"
    fi
    
    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  context_arg=$context_arg"
    echo "  namespace=$namespace"
    echo "-----------------------------------------"

    for registration in "${KUBESLICE_CLUSTER_REGISTRATIONS[@]}"; do
        IFS="|" read -r cluster_name project_name telemetry_enabled telemetry_endpoint telemetry_provider geo_location_provider geo_location_region <<< "$registration"
        
        echo "-----------------------------------------"
        echo "🚀 Registering cluster '$cluster_name' in project '$project_name' within namespace '$namespace'"
        echo "-----------------------------------------"
        
        cat <<EOF > "$INSTALLATION_FILES_PATH/${cluster_name}_cluster.yaml"
apiVersion: controller.kubeslice.io/v1alpha1
kind: Cluster
metadata:
  name: $cluster_name
  namespace: kubeslice-$project_name
spec:
  clusterProperty:
    telemetry:
      enabled: $telemetry_enabled
      endpoint: $telemetry_endpoint
      telemetryProvider: $telemetry_provider
    geoLocation:
      cloudProvider: "$geo_location_provider"
      cloudRegion: "$geo_location_region"
EOF

        kubectl apply -f "$INSTALLATION_FILES_PATH/${cluster_name}_cluster.yaml" --kubeconfig $kubeconfig_path $context_arg -n kubeslice-$project_name
        echo "🔍 Verifying cluster registration for '$cluster_name'..."
        kubectl get clusters -n kubeslice-$project_name --kubeconfig $kubeconfig_path $context_arg | grep $cluster_name

        echo "-----------------------------------------"
        echo "✔️  Cluster '$cluster_name' registered successfully in project '$project_name'."
        echo "-----------------------------------------"
    done
    echo "✔️ Cluster registration in controller cluster complete."
}

# Function to fetch secrets from the worker clusters and create worker values file
prepare_worker_values_file() {

    echo "🚀 fetching controller context"
    local controller_kubeconfig_path="$KUBESLICE_CONTROLLER_KUBECONFIG"
    local controller_context_arg=""

    if [ -n "$KUBESLICE_CONTROLLER_KUBECONTEXT" ]; then
        controller_context_arg="--context $KUBESLICE_CONTROLLER_KUBECONTEXT"
    fi
    

    echo "🚀 Starting worker values file preparation..."
    for worker in "${KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<< "$worker"

        echo "🔧 Variables:"
        echo "  worker_name=$worker_name"
        echo "  skip_installation=$skip_installation"
        echo "  use_global_kubeconfig=$use_global_kubeconfig"
        echo "  kubeconfig=$kubeconfig"
        echo "  kubecontext=$kubecontext"
        echo "  namespace=$namespace"
        echo "  release_name=$release_name"
        echo "  chart_name=$chart_name"
	echo "  controller_kubeconfig_path=$controller_kubeconfig_path"
	echo "  controller_context_arg=$controller_context_arg"
	echo "  project_ns=kubeslice-$project_name"
        echo "-----------------------------------------"

        echo "-----------------------------------------"
        echo "🚀 Preparing values file for worker '$worker_name'"
        echo "-----------------------------------------"





        local secret_name="kubeslice-rbac-worker-$worker_name"
        local controller_secret_file="$INSTALLATION_FILES_PATH/${secret_name}.yaml"

        # Fetch the secret from the worker cluster
        echo "🔍 Fetching secret '$project_name' from worker cluster..."

        # Print the command that will be executed
        echo "kubectl get secret $secret_name -n "kubeslice-$project_name" --kubeconfig $controller_kubeconfig_path $controller_context_arg -o yaml"

        worker_secret=$(kubectl get secret $secret_name -n "kubeslice-$project_name" --kubeconfig $controller_kubeconfig_path $controller_context_arg -o yaml)
        
        # Decode the relevant fields from the controller secret
        ca_crt=$(echo "$worker_secret" | yq e '.data["ca.crt"]')
        token=$(echo "$worker_secret" | yq e '.data.token')
        namespace=$(echo "$worker_secret" | yq e '.data.namespace')
        endpoint=$(echo "$worker_secret" | yq e '.data.controllerEndpoint')
	cluster_name=$(echo "$worker_secret" | yq e '.data.clusterName' - | base64 --decode)

        # Prepare the worker values file
        cat <<EOF > "$INSTALLATION_FILES_PATH/${worker_name}_final_values.yaml"
controllerSecret:
  namespace: $namespace
  endpoint: $endpoint
  ca.crt: $ca_crt
  token: $token

cluster:
  name: $cluster_name

EOF

        echo "✔️  Worker values file prepared and saved as '${worker_name}_final_values.yaml'."
        echo "-----------------------------------------"
    done
    echo "✔️ Worker values file preparation complete."
}

# Parse command-line arguments for options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --input-yaml) EGS_INPUT_YAML="$2"; shift ;;
        --help) 
            echo "Usage: $0 --input-yaml <yaml_file>"
            exit 0 ;;
        *) 
            echo "Unknown parameter passed: $1"; 
            echo "Use --help for usage information."
            exit 1 ;;
    esac
    shift
done

# Validation for input-yaml flag
if [ -z "$EGS_INPUT_YAML" ]; then
    echo "❌ Error: --input-yaml flag is required."
    echo "Use --help for usage information."
    exit 1
fi

# If an input YAML file is provided, parse it
if [ -n "$EGS_INPUT_YAML" ]; then
   # Run prerequisite checks if precheck is enabled
     prerequisite_check
    if command -v yq &> /dev/null; then
        parse_yaml "$EGS_INPUT_YAML"
	echo " calling validate_paths..."
    	validate_paths
    else
        echo "❌ yq command not found. Please install yq to use the --input-yaml option."
        exit 1
    fi
fi

# Run Kubeslice pre-checks if enabled
if [ "$KUBESLICE_PRECHECK" = "true" ]; then
    kubeslice_pre_check
fi


# Process kubeslice-controller installation if enabled
if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ]; then
    install_or_upgrade_helm_chart "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_CHART_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT" "$KUBESLICE_CONTROLLER_REPO_URL" "$KUBESLICE_CONTROLLER_USERNAME" "$KUBESLICE_CONTROLLER_PASSWORD" "$KUBESLICE_CONTROLLER_VALUES_FILE" "$KUBESLICE_CONTROLLER_INLINE_VALUES" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL" "$KUBESLICE_CONTROLLER_HELM_FLAGS" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$KUBESLICE_CONTROLLER_VERSION" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL"
fi


# Process kubeslice-ui installation if enabled
if [ "$ENABLE_INSTALL_UI" = "true" ]; then
    install_or_upgrade_helm_chart "$KUBESLICE_UI_SKIP_INSTALLATION" "$KUBESLICE_UI_RELEASE_NAME" "$KUBESLICE_UI_CHART_NAME" "$KUBESLICE_UI_NAMESPACE" "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_UI_KUBECONFIG" "$KUBESLICE_UI_KUBECONTEXT" "$KUBESLICE_UI_REPO_URL" "$KUBESLICE_UI_USERNAME" "$KUBESLICE_UI_PASSWORD" "$KUBESLICE_UI_VALUES_FILE" "$KUBESLICE_UI_INLINE_VALUES" "$KUBESLICE_UI_IMAGE_PULL_SECRET_REPO" "$KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME" "$KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD" "$KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL" "$KUBESLICE_UI_HELM_FLAGS" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$KUBESLICE_UI_VERSION" "$KUBESLICE_UI_VERIFY_INSTALL" "$KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_UI_SKIP_ON_VERIFY_FAIL"
fi



# Create projects in the controller cluster before deploying workers
if [ "$ENABLE_PROJECT_CREATION" = "true" ]; then
    create_projects_in_controller
fi

# Register clusters in the controller cluster after projects have been created
if [ "$ENABLE_CLUSTER_REGISTRATION" = "true" ]; then
    register_clusters_in_controller
fi

# Fetch secrets from the controller cluster if enabled
#if [ "$ENABLE_FETCH_CONTROLLER_SECRETS" = "true" ]; then
#    fetch_controller_secrets
#fi


# Function to merge inline values and handle any missing flags

# Function to create a unique directory for each run
create_unique_run_dir() {
    local base_dir="$INSTALLATION_FILES_PATH/run"
    local release_name=$1
    local run_dir="$base_dir/helm_run_$(date +%Y%m%d_%H%M%S)_${release_name}"

    mkdir -p "$run_dir"
    echo "$run_dir"
}

# Function to merge prepared values and inline values into the final combined file



merge_inline_values() {
    local prepared_values_file=$1
    local inline_values=$2
    local base_name=$3
    local run_dir=$4
    local combined_values_file="$run_dir/${base_name}_combined_values.yaml"

    # Copy the prepared values file to the combined file
    if [ -n "$prepared_values_file" ] && [ -f "$prepared_values_file" ]; then
        cp "$prepared_values_file" "$combined_values_file"
    else
        touch "$combined_values_file"
    fi

    # Merge the inline values into the combined values file
    if [ -n "$inline_values" ]; then
        echo "$inline_values" | yq eval -P - >> "$combined_values_file"
    fi

    echo "$combined_values_file"
}

# Inside the loop where you process each worker
if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
    for worker_index in "${!KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<< "${KUBESLICE_WORKERS[$worker_index]}"

        if [ "$ENABLE_PREPARE_WORKER_VALUES_FILE" = "true" ]; then
             prepare_worker_values_file
         fi
         
        # Prepare the path to the prepared values file
        prepared_values_file="$INSTALLATION_FILES_PATH/${worker_name}_final_values.yaml"

        # Extract and output inline values
        inline_values=$(yq e ".kubeslice_worker_egs[$worker_index].inline_values | select(. != null)" "$EGS_INPUT_YAML")
        echo "Inline values extracted for worker $worker_name:"
        echo "$inline_values"

        # Extract worker-specific values for the new parameters
        worker=$(yq e ".kubeslice_worker_egs[$worker_index]" "$EGS_INPUT_YAML")
        worker_name=$(echo "$worker" | yq e '.name' -)
        skip_installation=$(echo "$worker" | yq e '.skip_installation' -)
        use_global_kubeconfig=$(echo "$worker" | yq e '.use_global_kubeconfig' -)
        namespace=$(echo "$worker" | yq e '.namespace' -)
        release_name=$(echo "$worker" | yq e '.release' -)
        chart_name=$(echo "$worker" | yq e '.chart' -)
        values_file=$(echo "$worker" | yq e '.values_file' -)
        helm_flags=$(echo "$worker" | yq e '.helm_flags' -)
        verify_install=$(echo "$worker" | yq e '.verify_install' -)
        verify_install_timeout=$(echo "$worker" | yq e '.verify_install_timeout' -)
        skip_on_verify_fail=$(echo "$worker" | yq e '.skip_on_verify_fail' -)
        version=$(echo "$worker" | yq e '.version' -)
        specific_use_local_charts=$(echo "$worker" | yq e '.specific_use_local_charts' -)

        # Create a unique directory for this worker's run
        run_dir=$(create_unique_run_dir "$release_name")

        # Merge the prepared values and inline values
        combined_values_file=$(merge_inline_values "$prepared_values_file" "$inline_values" "$worker_name" "$run_dir")

        # Debugging: Output the combined values file to check the contents
        echo "Generated combined values file for $worker_name:"
        cat "$combined_values_file"

        # Now call the install_or_upgrade_helm_chart function in a similar fashion to the controller
        install_or_upgrade_helm_chart "$skip_installation" "$release_name" "$chart_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$repo_url" "$username" "$password" "$combined_values_file" "" "$image_pull_secret_repo" "$image_pull_secret_username" "$image_pull_secret_password" "$image_pull_secret_email" "$helm_flags" "$specific_use_local_charts" "$LOCAL_CHARTS_PATH" "$version" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"
    done
fi


# Function to create a values file from inline values, ensuring uniqueness
create_values_file() {
    local inline_values=$1
    local base_name=$2
    local values_file_path="$run_dir/${base_name}_values.yaml"
    local counter=1

    # Ensure the file name is unique by appending an incremental number if needed
    while [ -f "$values_file_path" ]; do
        values_file_path="$run_dir/${base_name}_$counter.yaml"
        counter=$((counter + 1))
    done

    # Use yq to parse and create a valid YAML file
    echo "$inline_values" | yq eval -P - > "$values_file_path"
    
    # Return the file path to be used in Helm command
    echo "$values_file_path"
}



# Process additional applications if any are defined and installation is enabled
if [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "true" ] && [ "${#ADDITIONAL_APPS[@]}" -gt 0 ]; then
    echo "🚀 Starting installation of additional applications..."
    for app_index in $(seq 0 $((${#ADDITIONAL_APPS[@]} - 1))); do
        # Extracting application configuration from YAML using yq
        app=$(yq e ".additional_apps[$app_index]" "$EGS_INPUT_YAML")
        app_name=$(echo "$app" | yq e '.name' -)
        skip_installation=$(echo "$app" | yq e '.skip_installation' -)
        use_global_kubeconfig=$(echo "$app" | yq e '.use_global_kubeconfig' -)
        namespace=$(echo "$app" | yq e '.namespace' -)
        release_name=$(echo "$app" | yq e '.release' -)
        chart_name=$(echo "$app" | yq e '.chart' -)
        values_file=$(echo "$app" | yq e '.values_file' -)
        helm_flags=$(echo "$app" | yq e '.helm_flags' -)
        verify_install=$(echo "$app" | yq e '.verify_install' -)
        verify_install_timeout=$(echo "$app" | yq e '.verify_install_timeout' -)
        skip_on_verify_fail=$(echo "$app" | yq e '.skip_on_verify_fail' -)
        repo_url=$(echo "$app" | yq e '.repo_url' -)
        username=$(echo "$app" | yq e '.username' -)
        password=$(echo "$app" | yq e '.password' -)
        inline_values=$(echo "$app" | yq e '.inline_values // {}' -)
        version=$(echo "$app" | yq e '.version' -)
        specific_use_local_charts=$(echo "$app" | yq e '.specific_use_local_charts' -)


        # Create a unique directory for this app's run
        run_dir=$(create_unique_run_dir "$release_name")

        # Merge the inline values and the values file
        if [ -n "$inline_values" ] && [ "$inline_values" != "null" ]; then
            inline_values_file=$(create_values_file "$inline_values" "$app_name-inline")
            merged_values_file="$inline_values_file"
            echo "Using inline values file: $inline_values_file"
        elif [ -n "$values_file" ] && [ "$values_file" != "null" ] && [ -f "$values_file" ]; then
            merged_values_file="$values_file"
            echo "Using values file: $values_file"
        else
            merged_values_file=""
        fi

        # Now call the install_or_upgrade_helm_chart function
	install_or_upgrade_helm_chart "$skip_installation" "$release_name" "$chart_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$repo_url" "$username" "$password" "$values_file" "$inline_values" "$image_pull_secret_repo" "$image_pull_secret_username" "$image_pull_secret_password" "$image_pull_secret_email" "$helm_flags" "$specific_use_local_charts" "$LOCAL_CHARTS_PATH" "$version" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"

    done
    echo "✔️ Installation of additional applications complete."
else
    echo "⏩ Skipping installation of additional applications as ENABLE_INSTALL_ADDITIONAL_APPS is set to false."
fi

# Check if the enable_custom_apps flag is defined and set to true
enable_custom_apps=$(yq e '.enable_custom_apps // "false"' "$EGS_INPUT_YAML")

if [ "$enable_custom_apps" = "true" ]; then
    echo "🚀 Custom apps are enabled. Iterating over manifests and applying them..."
    
    # Check if the manifests section is defined
    manifests_exist=$(yq e '.manifests // "null"' "$EGS_INPUT_YAML")

    if [ "$manifests_exist" = "null" ]; then
        echo "⚠️  No 'manifests' section found in the YAML file. Skipping manifest application."
    else
        manifests_length=$(yq e '.manifests | length' "$EGS_INPUT_YAML")
        
        if [ "$manifests_length" -eq 0 ]; then
            echo "⚠️  'manifests' section is defined but contains no entries. Skipping manifest application."
        else
            for index in $(seq 0 $((manifests_length - 1))); do
                echo "🔄 Applying manifest $((index + 1)) of $manifests_length..."
                
                appname=$(yq e ".manifests[$index].appname" "$EGS_INPUT_YAML")
                manifest=$(yq e ".manifests[$index].manifest" "$EGS_INPUT_YAML")
                overrides_yaml=$(yq e ".manifests[$index].overrides_yaml" "$EGS_INPUT_YAML")
                inline_yaml=$(yq e ".manifests[$index].inline_yaml" "$EGS_INPUT_YAML")
                use_global_kubeconfig=$(yq e ".manifests[$index].use_global_kubeconfig" "$EGS_INPUT_YAML")
                kubeconfig=$(yq e ".manifests[$index].kubeconfig" "$EGS_INPUT_YAML")
                kubecontext=$(yq e ".manifests[$index].kubecontext" "$EGS_INPUT_YAML")
                skip_installation=$(yq e ".manifests[$index].skip_installation" "$EGS_INPUT_YAML")
                verify_install=$(yq e ".manifests[$index].verify_install" "$EGS_INPUT_YAML")
                verify_install_timeout=$(yq e ".manifests[$index].verify_install_timeout" "$EGS_INPUT_YAML")
                skip_on_verify_fail=$(yq e ".manifests[$index].skip_on_verify_fail" "$EGS_INPUT_YAML")
                namespace=$(yq e ".manifests[$index].namespace" "$EGS_INPUT_YAML")

                # Create a temporary YAML with only the current manifest entry
                temp_yaml="$INSTALLATION_FILES_PATH/temp_manifest_$index.yaml"
                yq e ".manifests = [ .manifests[$index] ]" "$EGS_INPUT_YAML" > "$temp_yaml"

                # Call apply_manifests_from_yaml function for each manifest
                apply_manifests_from_yaml "$temp_yaml"

                # Clean up temporary YAML file
                rm -f "$temp_yaml"
            done
        fi
    fi
else
    echo "⏩ Custom apps are disabled or not defined. Skipping manifest application."
fi


# Identify the cloud provider and perform cloud-specific installations if cloud_install is defined
if [ -n "$CLOUD_INSTALL" ]; then
    cloud_provider=$(identify_cloud_provider)
    cloud_install_array=($(load_cloud_install_config "$cloud_provider" "$EGS_INPUT_YAML"))
    if [ ${#cloud_install_array[@]} -gt 0 ]; then
        handle_cloud_installation "$cloud_provider" "${cloud_install_array[@]}"
    else
       echo "⚠️  No cloud-specific installations found for $cloud_provider. Skipping."
    fi
else
    echo "⏩ Cloud-specific installations are disabled or not defined."
fi

# Validate the run_commands flag before invoking the function
run_commands=$(yq e '.run_commands // "false"' "$EGS_INPUT_YAML")

if [ "$run_commands" != "true" ]; then
    echo "⏩ Command execution is disabled (run_commands is not true). Skipping."
else
    # Call the function if validation passes
    run_k8s_commands_from_yaml "$EGS_INPUT_YAML"
fi


trap display_summary EXIT



echo "========================================="
echo "    EGS Installer Script Complete        "
echo "========================================="
