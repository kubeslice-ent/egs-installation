#!/bin/bash

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

    # Iterate over the list and check if each binary is available
    for binary in "${REQUIRED_BINARIES[@]}"; do
        if ! command -v $binary &> /dev/null; then
            echo -e "\n❌ Error: $binary is not installed or not available in PATH."
            prerequisites_met=false
        else
            echo "✔️ $binary is installed."
        fi
    done

    if [ "$prerequisites_met" = false ]; then
        echo "❌ Please install the missing prerequisites and try again."
        exit 1
    fi

    echo "✔️ All prerequisites are met."
    echo "✔️ Prerequisite check complete."
    echo ""
}

# Function to perform Kubeslice pre-checks for controller, UI, and workers
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



# Function to add or update Helm repo
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

    if helm repo list | grep -q "$repo_name"; then
        echo "🔍 Helm repository '$repo_name' already exists."
        if [ "$READD_HELM_REPOS" = "true" ]; then
            echo "♻️  Removing and re-adding Helm repository '$repo_name'..."
            helm repo remove $repo_name
            helm repo add $repo_name $repo_url --username $username --password $password
        fi
    else
        echo "➕ Adding Helm repository '$repo_name'..."
        helm repo add $repo_name $repo_url --username $username --password $password
    fi

    echo "🔄 Updating Helm repositories..."
    helm repo update $repo_name
    echo "✔️ Helm repository management complete."
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
    local use_local_charts=${18}
    local local_charts_path=${19}
    local verify_install=${20}
    local verify_install_timeout=${21}
    local skip_on_verify_fail=${22}

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
    echo "  use_local_charts=$use_local_charts"
    echo "  local_charts_path=$local_charts_path"
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
    if [ "$use_local_charts" = "true" ]; then
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

    # Determine which image pull secrets to use (global or chart-level)
    local image_pull_secret_repo_used=${image_pull_secret_repo:-$GLOBAL_IMAGE_PULL_SECRET_REPO}
    local image_pull_secret_username_used=${image_pull_secret_username:-$GLOBAL_IMAGE_PULL_SECRET_USERNAME}
    local image_pull_secret_password_used=${image_pull_secret_password:-$GLOBAL_IMAGE_PULL_SECRET_PASSWORD}
    local image_pull_secret_email_used=${image_pull_secret_email:-$GLOBAL_IMAGE_PULL_SECRET_EMAIL}

    # Chart-level overrides for imagePullSecrets
    if [ -n "$image_pull_secret_repo" ] || [ -n "$image_pull_secret_username" ] || [ -n "$image_pull_secret_password" ]; then
        image_pull_secret_repo_used=$image_pull_secret_repo
        image_pull_secret_username_used=$image_pull_secret_username
        image_pull_secret_password_used=$image_pull_secret_password
        image_pull_secret_email_used=$image_pull_secret_email
    fi

    # Create inline values for imagePullSecrets only if they are defined
    image_pull_secrets_inline=""
    if [ -n "$image_pull_secret_repo_used" ] && [ -n "$image_pull_secret_username_used" ] && [ -n "$image_pull_secret_password_used" ]; then
        image_pull_secrets_inline=$(cat <<EOF
imagePullSecrets:
  repository: $image_pull_secret_repo_used
  username: $image_pull_secret_username_used
  password: $image_pull_secret_password_used
  email: $image_pull_secret_email_used
EOF
)
    fi

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
    if [ "$use_local_charts" != "true" ] && [ -n "$repo_url" ]; then
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
    if command -v yq &> /dev/null; then
        parse_yaml "$EGS_INPUT_YAML"
	echo " calling validate_paths..."
	validate_paths
    else
        echo "❌ yq command not found. Please install yq to use the --input-yaml option."
        exit 1
    fi
fi

# Run prerequisite checks if precheck is enabled
if [ "$PRECHECK" = "true" ]; then
    prerequisite_check
fi

# Run Kubeslice pre-checks if enabled
if [ "$KUBESLICE_PRECHECK" = "true" ]; then
    kubeslice_pre_check
fi

# Process kubeslice-controller installation if enabled
if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ]; then
    install_or_upgrade_helm_chart "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_CHART_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT" "$KUBESLICE_CONTROLLER_REPO_URL" "$KUBESLICE_CONTROLLER_USERNAME" "$KUBESLICE_CONTROLLER_PASSWORD" "$KUBESLICE_CONTROLLER_VALUES_FILE" "$KUBESLICE_CONTROLLER_INLINE_VALUES" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL" "$KUBESLICE_CONTROLLER_HELM_FLAGS" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL"
fi

# Process kubeslice-ui installation if enabled
if [ "$ENABLE_INSTALL_UI" = "true" ]; then
    install_or_upgrade_helm_chart "$KUBESLICE_UI_SKIP_INSTALLATION" "$KUBESLICE_UI_RELEASE_NAME" "$KUBESLICE_UI_CHART_NAME" "$KUBESLICE_UI_NAMESPACE" "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_UI_KUBECONFIG" "$KUBESLICE_UI_KUBECONTEXT" "$KUBESLICE_UI_REPO_URL" "$KUBESLICE_UI_USERNAME" "$KUBESLICE_UI_PASSWORD" "$KUBESLICE_UI_VALUES_FILE" "$KUBESLICE_UI_INLINE_VALUES" "$KUBESLICE_UI_IMAGE_PULL_SECRET_REPO" "$KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME" "$KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD" "$KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL" "$KUBESLICE_UI_HELM_FLAGS" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$KUBESLICE_UI_VERIFY_INSTALL" "$KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_UI_SKIP_ON_VERIFY_FAIL"
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

# Prepare worker values files using the fetched secrets if enabled
if [ "$ENABLE_PREPARE_WORKER_VALUES_FILE" = "true" ]; then
    prepare_worker_values_file
fi

# Function to parse YAML using yq and extract the inline values
extract_inline_values() {
    local yaml_file=$1
    local worker_index=$2

    # Extract the inline_values for the specified worker
    inline_values=$(yq e ".kubeslice_worker_egs[$worker_index].inline_values" "$yaml_file")
    echo "$inline_values"
}

# Process worker installations if enabled
if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
    for worker_index in "${!KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<< "${KUBESLICE_WORKERS[$worker_index]}"
        
        # Prepare the path to the prepared values file
        prepared_values_file="$INSTALLATION_FILES_PATH/${worker_name}_final_values.yaml"

        # Debug: Extract and output inline values
        inline_values=$(extract_inline_values "$EGS_INPUT_YAML" "$worker_index")
        echo "Inline values extracted for worker $worker_name:"
        echo "$inline_values"

        # Create the final combined values file
        combined_values_file="$INSTALLATION_FILES_PATH/${worker_name}_combined_values.yaml"
        
        # Copy the contents of the prepared values file to the combined file
        cp "$prepared_values_file" "$combined_values_file"

        # Merge the inline values directly into the combined file
        if [ -n "$inline_values" ] && [ "$inline_values" != "null" ]; then
            echo "Merging inline values into the combined values file..."
            echo "$inline_values" >> "$combined_values_file"
        fi

        # Debugging: Output the combined values file to check the contents
        echo "Generated combined values file:"
        cat "$combined_values_file"

        # Now call the install_or_upgrade_helm_chart function in a similar fashion to the controller
        install_or_upgrade_helm_chart "$skip_installation" "$release_name" "$chart_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$repo_url" "$username" "$password" "$combined_values_file" "" "$image_pull_secret_repo" "$image_pull_secret_username" "$image_pull_secret_password" "$image_pull_secret_email" "$helm_flags" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"
    done
fi


echo "========================================="
echo "    EGS Installer Script Complete        "
echo "========================================="