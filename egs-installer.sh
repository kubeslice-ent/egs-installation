#!/bin/bash

# Define the script version
SCRIPT_VERSION="1.14.4"

# Check if the script is running in Bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Error: This script must be run in a Bash shell."
    echo "Please run the script using: bash script_name.sh"
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

# Specify the output file
output_file="egs-installer-output.log"
exec > >(tee -a "$output_file") 2>&1

echo "=====================================EGS Installer Script execution started at: $(date)===================================" >> "$output_file"

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
    for ((i = 0; i < $duration; i++)); do
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
    local MIN_YQ_VERSION="4.44.2"
    local MIN_HELM_VERSION="3.15.0"
    local MIN_JQ_VERSION="1.6"
    local MIN_KUBECTL_VERSION="1.23.6"

    # Check yq
    if ! command -v yq &>/dev/null; then
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
    if ! command -v helm &>/dev/null; then
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
    if ! command -v jq &>/dev/null; then
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
    if ! command -v kubectl &>/dev/null; then
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

# Function to check if a context exists in the kubeconfig
context_exists_in_kubeconfig() {
    local kubeconfig="$1"
    local kubecontext="$2"

    # Print the input values (redirected to stderr)
    echo "🔧 context_exists_in_kubeconfig:" >&2
    echo "  🗂️  Kubeconfig: $kubeconfig" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2

    kubectl config --kubeconfig="$kubeconfig" get-contexts -o name | grep -qw "$kubecontext"
}

# Function to retrieve the API server URL for the provided kubeconfig and context
get_api_server_url() {
    local kubeconfig="$1"
    local kubecontext="$2"

    # Print the input values (redirected to stderr)
    echo "🔧 get_api_server_url:" >&2
    echo "  🗂️  Kubeconfig: $kubeconfig" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2

    kubectl config --kubeconfig="$kubeconfig" view -o jsonpath="{.clusters[?(@.name == \"$(kubectl config --kubeconfig="$kubeconfig" view -o jsonpath="{.contexts[?(@.name == \"$kubecontext\")].context.cluster}")\")].cluster.server}"
}

get_lb_external_ip() {
    local kubeconfig="$1"
    local kubecontext="$2"
    local namespace="$3"
    local service_name="$4"

    # Print the input values (redirected to stderr)
    echo "🔧 get_lb_external_ip:" >&2
    echo "  🗂️  Kubeconfig: $kubeconfig" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "  📦 Namespace: $namespace" >&2
    echo "  🛠️  Service: $service_name" >&2

    service_type=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.type}')

    if [ "$service_type" = "LoadBalancer" ]; then
        ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        echo "$ip"
    elif [ "$service_type" = "NodePort" ]; then
        node_port=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].nodePort}')
        node_ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "$node_ip:$node_port"
    elif [ "$service_type" = "ClusterIP" ]; then
        cluster_ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.clusterIP}')
        service_port=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}')
        echo "$cluster_ip:$service_port"
    else
        echo "Unknown service type: $service_type"
        return 1
    fi
}

kubeaccess_precheck() {
    local component_name="$1"
    local use_global_config="$2"
    local global_kubeconfig="$3"
    local global_kubecontext="$4"
    local component_kubeconfig="$5"
    local component_kubecontext="$6"
    local verbose="${7:-true}"
    local dry_run="${8:-false}"

    local kubeaccess_kubeconfig=""
    local kubeaccess_context=""

    # Treat "null" as an empty value
    if [ "$component_kubecontext" = "null" ]; then
        component_kubecontext=""
    fi
    if [ "$component_kubeconfig" = "null" ]; then
        component_kubeconfig=""
    fi

    if [ "$verbose" = "true" ]; then
        echo "🚀 Starting precheck for deployment of component: $component_name" >&2
        echo "🔧 Initial Variables:" >&2
        echo "  🗂️  component_kubeconfig=${component_kubeconfig:-"(not provided)"}" >&2
        echo "  🌐 component_kubecontext=${component_kubecontext:-"(not provided)"}" >&2
        echo "  🌐 use_global_config=$use_global_config" >&2
        echo "  🗂️  global_kubeconfig=$global_kubeconfig" >&2
        echo "  🌐 global_kubecontext=$global_kubecontext" >&2
        echo "-----------------------------------------" >&2
    fi

    # Priority is given to component-specific settings
    if [ -n "$component_kubeconfig" ] && [ -n "$component_kubecontext" ]; then
        if context_exists_in_kubeconfig "$component_kubeconfig" "$component_kubecontext"; then
            kubeaccess_kubeconfig="$component_kubeconfig"
            kubeaccess_context="$component_kubecontext"
            echo "✅ Component level config is used for deployment of $component_name." >&2
            api_server_url=$(get_api_server_url "$kubeaccess_kubeconfig" "$kubeaccess_context")
            echo "🌐 API Server URL for context '$kubeaccess_context': $api_server_url" >&2
        else
            echo "❌ Error: Component kubecontext '$component_kubecontext' not found in the specified component kubeconfig." >&2
            exit 1
        fi
    elif [ -z "$component_kubeconfig" ] && [ -n "$component_kubecontext" ]; then
        # Use global config with component context
        if context_exists_in_kubeconfig "$global_kubeconfig" "$component_kubecontext"; then
            kubeaccess_kubeconfig="$global_kubeconfig"
            kubeaccess_context="$component_kubecontext"
            echo "ℹ️  Component kubeconfig is empty, using global kubeconfig with component context for deployment of $component_name." >&2
            api_server_url=$(get_api_server_url "$kubeaccess_kubeconfig" "$kubeaccess_context")
            echo "🌐 API Server URL for context '$kubeaccess_context': $api_server_url" >&2
        else
            echo "❌ Error: Component kubecontext '$component_kubecontext' not found in global kubeconfig." >&2
            exit 1
        fi
    elif [ "$use_global_config" = "true" ]; then
        # Fallback to global config and context if component-specific config is not provided
        if [ -n "$global_kubeconfig" ] && [ -n "$global_kubecontext" ]; then
            if context_exists_in_kubeconfig "$global_kubeconfig" "$global_kubecontext"; then
                kubeaccess_kubeconfig="$global_kubeconfig"
                kubeaccess_context="$global_kubecontext"
                echo "ℹ️  Falling back to global config for deployment of $component_name." >&2
                api_server_url=$(get_api_server_url "$kubeaccess_kubeconfig" "$kubeaccess_context")
                echo "🌐 API Server URL for context '$kubeaccess_context': $api_server_url" >&2
            else
                echo "❌ Error: Global kubecontext '$global_kubecontext' not found in the specified global kubeconfig." >&2
                exit 1
            fi
        else
            echo "❌ Error: Global kubeconfig or kubecontext is not defined correctly." >&2
            exit 1
        fi
    else
        echo "❌ Error: Component and global configurations are either not provided or invalid." >&2
        exit 1
    fi

    if [ "$dry_run" = "false" ]; then
        echo "$kubeaccess_kubeconfig $kubeaccess_context"
    fi
}

# Function to validate if a given kubecontext is valid
validate_kubecontext() {
    local kubeconfig_path=$1
    local kubecontext=$2

    # Print the input variables (redirected to stderr)
    echo "🔧 validate_kubecontext - Input Variables:" >&2
    echo "  🗂️  Kubeconfig Path: $kubeconfig_path" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2

    # Check if the context exists in the kubeconfig file
    if ! kubectl config get-contexts --kubeconfig "$kubeconfig_path" -o name | grep -q "^$kubecontext$"; then
        echo "❌ Error: Kubecontext '$kubecontext' does not exist in the kubeconfig file '$kubeconfig_path'." >&2
        exit 1
    fi

    # Try to use the context to connect to the cluster
    local cluster_info
    cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" --context "$kubecontext" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "❌ Error: Kubecontext '$kubecontext' is invalid or cannot connect to the cluster." >&2
        echo "Details: $cluster_info" >&2
        exit 1
    fi

    # Print the successful validation message (redirected to stderr)
    echo "✔️ Kubecontext '$kubecontext' is valid and can connect to the cluster." >&2

    # Return success without using echo in stdout
    return 0
}

# Kubeslice pre-checks function with context validation
kubeslice_pre_check() {
    echo "🚀 Starting Kubeslice pre-checks..."

    # Validate access to the kubeslice-controller cluster if installation is not skipped
    if [[ "$ENABLE_INSTALL_CONTROLLER" == "true" && "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" == "false" ]]; then

        # Print the input values to kubeaccess_precheck
        echo "🔧 Input Values to kubeaccess_precheck:"
        echo "  📛 Component Name: kubeslice-controller"
        echo "  🌐 Use Global Kubeconfig: $KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG"
        echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG"
        echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT"
        echo "  🗂️  Component Kubeconfig: $KUBESLICE_CONTROLLER_KUBECONFIG"
        echo "  🌐 Component Kubecontext: $KUBESLICE_CONTROLLER_KUBECONTEXT"
        echo "-----------------------------------------"

        # Using the kubeaccess_precheck function to determine kubeconfig and kubecontext
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "kubeslice-controller" \
            "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$KUBESLICE_CONTROLLER_KUBECONFIG" \
            "$KUBESLICE_CONTROLLER_KUBECONTEXT")

        # Print the return values with icons
        echo "🔧 Return Values from kubeaccess_precheck:"
        echo "  🗂️  kubeconfig_path=$kubeconfig_path"
        echo "  🌐 kubecontext=$kubecontext"

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:"
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"

            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"
            exit 1
        fi

        # Prepare the context argument if the context is available
        local context_arg=""
        if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            context_arg="--context $kubecontext"
        fi

        echo "-----------------------------------------"
        echo "🔍 Validating access to the kubeslice-controller cluster using kubeconfig '$kubeconfig_path'..."
        echo "🔧 Variables:"
        echo "  ENABLE_INSTALL_CONTROLLER=$ENABLE_INSTALL_CONTROLLER"
        echo "  KUBESLICE_CONTROLLER_SKIP_INSTALLATION=$KUBESLICE_CONTROLLER_SKIP_INSTALLATION"
        echo "  kubeconfig_path=$kubeconfig_path"
        echo "  kubecontext=$kubecontext"
        echo "  KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG=$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG"
        echo "  GLOBAL_KUBECONFIG=$GLOBAL_KUBECONFIG"
        echo "  GLOBAL_KUBECONTEXT=$GLOBAL_KUBECONTEXT"
        echo "  context_arg=$context_arg"
        echo "-----------------------------------------"

        cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "❌ Error: Unable to access the kubeslice-controller cluster using kubeconfig '$kubeconfig_path'."
            echo "Details: $cluster_info"
            exit 1
        fi

        controller_cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

        echo "✔️  Successfully accessed kubeslice-controller cluster. Kubernetes endpoint: $controller_cluster_endpoint"
        echo "-----------------------------------------"
    else
        echo "⏩ Skipping kubeslice-controller cluster validation as installation is skipped or not enabled."
    fi
    # Validate access to the kubeslice-ui cluster if installation is not skipped
    if [[ "$ENABLE_INSTALL_UI" == "true" && "$KUBESLICE_UI_SKIP_INSTALLATION" == "false" ]]; then

        # Print the input variables
        echo "🔧 kubeaccess_precheck - Input Variables:"
        echo "  📛 Component Name: kubeslice-ui"
        echo "  🌐 Use Global Kubeconfig: $KUBESLICE_UI_USE_GLOBAL_KUBECONFIG"
        echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG"
        echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT"
        echo "  🗂️  Component Kubeconfig: $KUBESLICE_UI_KUBECONFIG"
        echo "  🌐 Component Kubecontext: $KUBESLICE_UI_KUBECONTEXT"
        echo "-----------------------------------------"

        # Using the kubeaccess_precheck function to determine kubeconfig and kubecontext
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "kubeslice-ui" \
            "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$KUBESLICE_UI_KUBECONFIG" \
            "$KUBESLICE_UI_KUBECONTEXT")

        # Print the output variables
        echo "🔧 kubeaccess_precheck - Output Variables:"
        echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        echo "-----------------------------------------"

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:"
            echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"

            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
            echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"
            exit 1
        fi

        # Prepare the context argument if the context is available
        local context_arg=""
        if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            context_arg="--context $kubecontext"
        fi
        echo "-----------------------------------------"
        echo "🔍 Validating access to the kubeslice-ui cluster using kubeconfig '$kubeconfig_path'..."
        echo "🔧 Variables:"
        echo "  ENABLE_INSTALL_UI=$ENABLE_INSTALL_UI"
        echo "  KUBESLICE_UI_SKIP_INSTALLATION=$KUBESLICE_UI_SKIP_INSTALLATION"
        echo "  kubeconfig_path=$kubeconfig_path"
        echo "  kubecontext=$kubecontext"
        echo "  KUBESLICE_UI_USE_GLOBAL_KUBECONFIG=$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG"
        echo "  GLOBAL_KUBECONFIG=$GLOBAL_KUBECONFIG"
        echo "  GLOBAL_KUBECONTEXT=$GLOBAL_KUBECONTEXT"
        echo "-----------------------------------------"

        cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "❌ Error: Unable to access the kubeslice-ui cluster using kubeconfig '$kubeconfig_path'."
            echo "Details: $cluster_info"
            exit 1
        fi

        ui_cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

        echo "✔️  Successfully accessed kubeslice-ui cluster. Kubernetes endpoint: $ui_cluster_endpoint"
        echo "-----------------------------------------"
    else
        echo "⏩ Skipping kubeslice-ui cluster validation as installation is skipped or not enabled."
    fi

    # Iterate through each worker configuration and validate access if installation is not skipped
    for worker in "${KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<<"$worker"

        if [[ "$skip_installation" == "false" ]]; then
            # Print the input variables for the kubeaccess_precheck function
            echo "🔧 Input Variables for kubeaccess_precheck:"
            echo "  📛 Component Name: $worker_name"
            echo "  🌐 Use Global Kubeconfig: $use_global_kubeconfig"
            echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG"
            echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT"
            echo "  🗂️  Component Kubeconfig: $kubeconfig"
            echo "  🌐 Component Kubecontext: $kubecontext"
            echo "-----------------------------------------"

            # Print input variables before calling kubeaccess_precheck
            echo "🔧 kubeaccess_precheck - Input Variables:"
            echo "  📛 Worker Name: $worker_name"
            echo "  🌐 Use Global Kubeconfig: $use_global_kubeconfig"
            echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG"
            echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT"
            echo "  🗂️  Component Kubeconfig: $kubeconfig"
            echo "  🌐 Component Kubecontext: $kubecontext"
            echo "-----------------------------------------"

            # Call the kubeaccess_precheck function and capture output
            read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
                "$worker_name" \
                "$use_global_kubeconfig" \
                "$GLOBAL_KUBECONFIG" \
                "$GLOBAL_KUBECONTEXT" \
                "$kubeconfig" \
                "$kubecontext")

            # Print output variables after calling kubeaccess_precheck
            echo "🔧 kubeaccess_precheck - Output Variables:"
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"
            echo "-----------------------------------------"

            # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
            if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
                echo "🔍 Validating Kubecontext:"
                echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
                echo "  🌐 Kubecontext: $kubecontext"

                validate_kubecontext "$kubeconfig_path" "$kubecontext"
            else
                echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
                echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
                echo "  🌐 Kubecontext: $kubecontext"
                exit 1
            fi

            # Prepare the context argument if the context is available
            local context_arg=""
            if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
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
            echo "  context_arg=$context_arg"
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

            worker_cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
            echo "✔️  Successfully accessed worker cluster '$worker_name'. Kubernetes endpoint: $worker_cluster_endpoint"

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
        echo "⚠️  GLOBAL_KUBECONFIG '$GLOBAL_KUBECONFIG' does not exist or is not a file."
    fi

    # Check GLOBAL_KUBECONTEXT
    if [ ! -f "$GLOBAL_KUBECONTEXT" ]; then
        echo "⚠️  GLOBAL_KUBECONTEXT '$GLOBAL_KUBECONTEXT' does not exist or is not a file."
    fi

    # Check KUBESLICE_CONTROLLER_KUBECONFIG if controller installation is enabled and global config is not being used
    if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ] && [ "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" != "true" ]; then
        if [ -z "$KUBESLICE_CONTROLLER_KUBECONFIG" ] || [ "$KUBESLICE_CONTROLLER_KUBECONFIG" = "null" ] || [ ! -f "$KUBESLICE_CONTROLLER_KUBECONFIG" ]; then
            echo "❌ Error: KUBESLICE_CONTROLLER_KUBECONFIG '$KUBESLICE_CONTROLLER_KUBECONFIG' does not exist or is not a file."
            error_found=true
        fi

        if [ -z "$KUBESLICE_CONTROLLER_KUBECONTEXT" ] || [ "$KUBESLICE_CONTROLLER_KUBECONTEXT" = "null" ]; then
            echo "❌ Error: KUBESLICE_CONTROLLER_KUBECONTEXT is not defined."
            error_found=true
        fi
    fi

    # Check KUBESLICE_UI_KUBECONFIG if UI installation is enabled and global config is not being used
    if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" != "true" ]; then
        if [ -z "$KUBESLICE_UI_KUBECONFIG" ] || [ "$KUBESLICE_UI_KUBECONFIG" = "null" ] || [ ! -f "$KUBESLICE_UI_KUBECONFIG" ]; then
            echo "❌ Error: KUBESLICE_UI_KUBECONFIG '$KUBESLICE_UI_KUBECONFIG' does not exist or is not a file."
            error_found=true
        fi

        if [ -z "$KUBESLICE_UI_KUBECONTEXT" ] || [ "$KUBESLICE_UI_KUBECONTEXT" = "null" ]; then
            echo "❌ Error: KUBESLICE_UI_KUBECONTEXT is not defined."
            error_found=true
        fi
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
        echo "❌ One or more critical errors were found in the paths or required commands. Please correct them and try again."
        exit 1
    else
        echo "✔️ All required paths and commands are valid."
    fi
}

# Function to parse YAML using yq

parse_yaml() {
    local yaml_file=$1

    echo "🚀 Parsing input YAML file '$yaml_file'..."
    wait_with_dots 5 " "



    INPUT_VERSION=$(yq '.version' "$yaml_file" 2>/dev/null)

    if [[ -z "$INPUT_VERSION" ]]; then
        echo -e "❌ \033[31mError:\033[0m Could not find 'version' field in the input YAML file."
        exit 1
    fi

    # Print script and input versions
    echo -e "ℹ️  \033[34mScript Version:\033[0m $SCRIPT_VERSION"
    echo -e "ℹ️  \033[34mInput File Version:\033[0m $INPUT_VERSION"

    # Validate if versions match
    if [[ "$SCRIPT_VERSION" != "$INPUT_VERSION" ]]; then
        echo -e "❌ \033[31mError:\033[0m Script version ($SCRIPT_VERSION) does not match the input file version ($INPUT_VERSION)."
        echo -e "Please use a compatible input file version."
        exit 1
    fi

    # Print input file content if versions match
    echo "Versions match! Displaying input file content:"
    echo "------------------------------------------------------------"

    # Print YAML file content without duplicates
    cat "$yaml_file"

    echo "------------------------------------------------------------"

    # Extract BASE_PATH
    BASE_PATH=$(yq e '.base_path' "$yaml_file")
    if [ -z "$BASE_PATH" ] || [ "$BASE_PATH" = "null" ]; then
        echo "⚠️  BASE_PATH not specified. Defaulting to script directory."
        BASE_PATH=$(dirname "$(realpath "$0")") # Default to the script's directory
    fi

    # Ensure BASE_PATH is absolute
    BASE_PATH=$(realpath "$BASE_PATH")

    # Create installation-files directory if not exists
    INSTALLATION_FILES_PATH="$BASE_PATH/installation-files"
    mkdir -p "$INSTALLATION_FILES_PATH"

    # Extract precheck flag
    PRECHECK=$(yq e '.precheck' "$yaml_file")
    if [ -z "$PRECHECK" ] || [ "$PRECHECK" = "null" ]; then
        PRECHECK="true" # Default to true if not specified
    fi

    # Extract Kubeslice pre-check flag
    KUBESLICE_PRECHECK=$(yq e '.kubeslice_precheck' "$yaml_file")
    if [ -z "$KUBESLICE_PRECHECK" ] || [ "$KUBESLICE_PRECHECK" = "null" ]; then
        KUBESLICE_PRECHECK="false" # Default to false if not specified
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
        GLOBAL_VERIFY_INSTALL="true" # Default to true if not specified
    fi

    GLOBAL_VERIFY_INSTALL_TIMEOUT=$(yq e '.verify_install_timeout' "$yaml_file")
    if [ -z "$GLOBAL_VERIFY_INSTALL_TIMEOUT" ] || [ "$GLOBAL_VERIFY_INSTALL_TIMEOUT" = "null" ]; then
        GLOBAL_VERIFY_INSTALL_TIMEOUT="600" # Default to 10 minutes if not specified
    fi

    GLOBAL_SKIP_ON_VERIFY_FAIL=$(yq e '.skip_on_verify_fail' "$yaml_file")
    if [ -z "$GLOBAL_SKIP_ON_VERIFY_FAIL" ] || [ "$GLOBAL_SKIP_ON_VERIFY_FAIL" = "null" ]; then
        GLOBAL_SKIP_ON_VERIFY_FAIL="false" # Default to error out if not specified
    fi

    # Extract the list of required binaries
    REQUIRED_BINARIES=($(yq e '.required_binaries[]' "$yaml_file"))
    if [ ${#REQUIRED_BINARIES[@]} -eq 0 ]; then
        REQUIRED_BINARIES=("yq" "helm" "kubectl" "kubectx") # Default list if none specified
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

    echo " BASE_PATH=$BASE_PATH"
    echo " LOCAL_CHARTS_PATH=$LOCAL_CHARTS_PATH"

    # Global enable/disable flags for different stages

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
    for ((i = 0; i < WORKERS_COUNT; i++)); do
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
    for ((i = 0; i < PROJECTS_COUNT; i++)); do
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
    for ((i = 0; i < CLUSTER_REGISTRATION_COUNT; i++)); do
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
    for ((i = 0; i < seconds; i++)); do
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
                    sleep $delay
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
        retry helm repo remove "$repo_name" || {
            echo "❌ Failed to remove existing Helm repo '$repo_name'. Exiting."
            exit 1
        }

        if [ -n "$username" ] && [ -n "$password" ]; then
            retry helm repo add "$repo_name" "$repo_url" --username "$username" --password "$password" || {
                echo "❌ Failed to re-add Helm repo '$repo_name' with authentication. Exiting."
                exit 1
            }
        else
            retry helm repo add "$repo_name" "$repo_url" || {
                echo "❌ Failed to re-add Helm repo '$repo_name' without authentication. Exiting."
                exit 1
            }
        fi
    fi
else
    echo "➕ Adding Helm repository '$repo_name'..."
    if [ -n "$username" ] && [ -n "$password" ]; then
        retry helm repo add "$repo_name" "$repo_url" --username "$username" --password "$password" || {
            echo "❌ Failed to add Helm repo '$repo_name' with authentication. Exiting."
            exit 1
        }
    else
        retry helm repo add "$repo_name" "$repo_url" || {
            echo "❌ Failed to add Helm repo '$repo_name' without authentication. Exiting."
            exit 1
        }
    fi
fi

    echo "✔️ Helm repository management complete."
}

# Function to fetch and display summary information
display_summary() {
    echo "========================================="
    echo "           📋 Summary - Installations    "
    echo "========================================="

    # Summary of all Helm chart installations (including controller, UI, workers)
    echo "🛠️ **Application Installations Summary**:"

    # Helper function to check Helm release status and list Helm releases
    check_helm_release_status() {
        local release_name=$1
        local namespace=$2
        local kubeconfig_path=$3
        local kubecontext=$4

        echo "-----------------------------------------"
        echo "🚀 **Helm Release: $release_name**"
        if helm status "$release_name" --namespace "$namespace" --kubeconfig "$kubeconfig_path" --kube-context "$kubecontext" >/dev/null 2>&1; then
            echo "✔️ Release '$release_name' in namespace '$namespace' is successfully installed."
            echo "🔍 **Helm List Output**:"
            helm list --namespace "$namespace" --kubeconfig "$kubeconfig_path" --kube-context "$kubecontext" || echo "⚠️ Warning: Failed to list Helm releases in namespace '$namespace'."
        else
            echo "⚠️ Warning: Release '$release_name' in namespace '$namespace' encountered an issue."
        fi
        echo "-----------------------------------------"
    }

    # Kubeslice Controller Installation
    if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ] && [ "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" = "false" ]; then
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "Kubeslice Controller" \
            "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$KUBESLICE_CONTROLLER_KUBECONFIG" \
            "$KUBESLICE_CONTROLLER_KUBECONTEXT")
        check_helm_release_status "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$kubeconfig_path" "$kubecontext"
    else
        echo "⏩ **Kubeslice Controller** installation was skipped or disabled."
    fi

    # Worker Cluster Installations
    if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
        for ((i = 0; i < ${#KUBESLICE_WORKERS[@]}; i++)); do
            worker_name=$(yq e ".kubeslice_worker_egs[$i].name" "$EGS_INPUT_YAML")
            skip_installation=$(yq e ".kubeslice_worker_egs[$i].skip_installation" "$EGS_INPUT_YAML")
            kubeconfig=$(yq e ".kubeslice_worker_egs[$i].kubeconfig" "$EGS_INPUT_YAML")
            kubecontext=$(yq e ".kubeslice_worker_egs[$i].kubecontext" "$EGS_INPUT_YAML")
            use_global_kubeconfig=$(yq e ".kubeslice_worker_egs[$i].use_global_kubeconfig" "$EGS_INPUT_YAML")
            namespace=$(yq e ".kubeslice_worker_egs[$i].namespace" "$EGS_INPUT_YAML")
            release_name=$(yq e ".kubeslice_worker_egs[$i].release" "$EGS_INPUT_YAML")

            if [ "$skip_installation" = "false" ]; then
                read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
                    "$worker_name" \
                    "$use_global_kubeconfig" \
                    "$GLOBAL_KUBECONFIG" \
                    "$GLOBAL_KUBECONTEXT" \
                    "$kubeconfig" \
                    "$kubecontext")
                check_helm_release_status "$release_name" "$namespace" "$kubeconfig_path" "$kubecontext"
            else
                echo "⏩ **Worker Cluster '$worker_name'** installation was skipped."
            fi
        done
    else
        echo "⏩ **Worker installation was skipped or disabled.**"
    fi

    echo "========================================="
    echo "           📋 Summary - Details          "
    echo "========================================="

    # Fetch the kubeslice-ui-proxy service LoadBalancer URL using the controller's kubeconfig and context
    if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$KUBESLICE_UI_SKIP_INSTALLATION" = "false" ]; then
        echo "🔍 **Service Information for Kubeslice UI**:"
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "Kubeslice UI" \
            "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$KUBESLICE_CONTROLLER_KUBECONFIG" \
            "$KUBESLICE_CONTROLLER_KUBECONTEXT")

        kubectl get svc kubeslice-ui-proxy -n "$KUBESLICE_UI_NAMESPACE" --kubeconfig "$kubeconfig_path" --context "$kubecontext" || echo "⚠️ Warning: Failed to get services in namespace '$KUBESLICE_UI_NAMESPACE'."

        ui_proxy_url=$(kubectl get svc kubeslice-ui-proxy -n "$KUBESLICE_UI_NAMESPACE" --kubeconfig "$kubeconfig_path" --context "$kubecontext" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -z "$ui_proxy_url" ]; then
            ui_proxy_url=$(kubectl get svc kubeslice-ui-proxy -n "$KUBESLICE_UI_NAMESPACE" --kubeconfig "$kubeconfig_path" --context "$kubecontext" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        fi
        if [ -n "$ui_proxy_url" ]; then
            echo "🔗 **Kubeslice UI Proxy LoadBalancer URL**: https://$ui_proxy_url"
        else
            echo "⚠️ Warning: Kubeslice UI Proxy LoadBalancer URL not available."
        fi
    else
        echo "⏩ **Kubeslice UI installation was skipped or disabled.**"
    fi

    # Fetch the token for each project provided in the input YAML
    if [ "$ENABLE_PROJECT_CREATION" = "true" ]; then
        for project in "${KUBESLICE_PROJECTS[@]}"; do
            IFS="|" read -r project_name project_username <<<"$project"
            token=$(kubectl get secret "kubeslice-rbac-rw-$project_username" -o jsonpath="{.data.token}" -n "kubeslice-$project_name" --kubeconfig "$kubeconfig_path" --context "$kubecontext" 2>/dev/null | base64 --decode || echo "")
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
    echo "          🏁 Summary Output Complete      "
    echo "========================================="
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

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "$release_name" \
        "$specific_use_global_kubeconfig" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$specific_kubeconfig_path" \
        "$specific_kubecontext")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: $release_name"
    echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
    echo "  🌐 Kubecontext: $kubecontext"
    echo "-----------------------------------------"

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:"
        echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
        echo "  🗂️   Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        exit 1
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
            cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

            if [ -z "$cluster_endpoint" ]; then
                echo "⚠️ Warning: Failed to fetch cluster endpoint. Proceeding without setting the controller endpoint."
            else
                # Clean and sanitize the endpoint
                cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
                # Initialize inline_values with the fetched endpoint
                inline_values=$(echo "{}" | yq e ".kubeslice.controller.endpoint = \"$cluster_endpoint\"" -)
                echo "✔️ Inline values created with fetched cluster endpoint: $cluster_endpoint"
            fi
        elif [ -z "$(echo "$inline_values" | yq e '.kubeslice.controller.endpoint' -)" ]; then
            echo "🔍 No endpoint found in inline values. Attempting to fetch the cluster endpoint..."

            local cluster_endpoint
            cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

            if [ -z "$cluster_endpoint" ]; then
                echo "⚠️ Warning: Failed to fetch cluster endpoint. Proceeding without setting the controller endpoint, Manually Pass the value"
                exit 1
            else
                # Clean and sanitize the endpoint
                cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
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
                cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

                if [ -z "$cluster_endpoint" ]; then
                    echo "⚠️ Warning: Failed to fetch cluster endpoint. Proceeding without setting the controller endpoint. Manually pass the value in inline values file "
                    exit 1
                else
                    # Clean and sanitize the endpoint
                    cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
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
        echo "$inline_values" | yq eval -P - >"$values_file_path"

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
    image_pull_secrets_inline=$(
        cat <<EOF
imagePullSecrets:
  repository: $image_pull_secret_repo_used
  username: $image_pull_secret_username_used
  password: $image_pull_secret_password_used
EOF
    )

    echo "✅ Image pull secrets configured successfully."

    # Define the base Helm command
    helm_cmd="helm --namespace $namespace --kubeconfig $kubeconfig_path $context_arg"

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

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Project Creation" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Project Creation "
    echo "  🗂️    Kubeconfig Path: $kubeconfig_path"
    echo "  🌐 Kubecontext: $kubecontext"
    echo "-----------------------------------------"

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:"
        echo "  🗂️    Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
        echo "  🗂️    Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        exit 1
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  context_arg=$context_arg"
    echo "  namespace=$namespace"
    echo "-----------------------------------------"

    for project in "${KUBESLICE_PROJECTS[@]}"; do
        IFS="|" read -r project_name project_username <<<"$project"

        echo "-----------------------------------------"
        echo "🚀 Creating project '$project_name' in namespace '$namespace'"
        echo "-----------------------------------------"

        cat <<EOF >"$INSTALLATION_FILES_PATH/${project_name}_project.yaml"
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
        kubectl get project.controller.kubeslice.io -n $namespace --kubeconfig $kubeconfig_path $context_arg | grep $project_name

        echo "-----------------------------------------"
        echo "✔️  Project '$project_name' created successfully in namespace '$namespace'."
        echo "-----------------------------------------"
    done
    echo "✔️ Project creation in controller cluster complete."
}

# Function to register clusters in the controller namespace
register_clusters_in_controller() {
    echo "🚀 Starting cluster registration in controller cluster..."

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Cluster Registration" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Cluster Registration "
    echo "  🗂️     Kubeconfig Path: $kubeconfig_path"
    echo "  🌐 Kubecontext: $kubecontext"
    echo "-----------------------------------------"

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:"
        echo "  🗂️     Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
        echo "  🗂️     Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        exit 1
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  context_arg=$context_arg"
    echo "  namespace=$namespace"
    echo "-----------------------------------------"

    for registration in "${KUBESLICE_CLUSTER_REGISTRATIONS[@]}"; do
        IFS="|" read -r cluster_name project_name telemetry_enabled telemetry_endpoint telemetry_provider geo_location_provider geo_location_region <<<"$registration"

        echo "-----------------------------------------"
        echo "🚀 Registering cluster '$cluster_name' in project '$project_name' within namespace '$namespace'"
        echo "-----------------------------------------"

        cat <<EOF >"$INSTALLATION_FILES_PATH/${cluster_name}_cluster.yaml"
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
        kubectl get cluster.controller.kubeslice.io -n kubeslice-$project_name --kubeconfig $kubeconfig_path $context_arg | grep $cluster_name

        echo "-----------------------------------------"
        echo "✔️  Cluster '$cluster_name' registered successfully in project '$project_name'."
        echo "-----------------------------------------"
    done
    echo "✔️ Cluster registration in controller cluster complete."
}

get_prometheus_external_ip() {
    local kubeconfig="$1"
    local kubecontext="$2"
    local namespace="$3"
    local service_name="$4"
    local service_type="$5"

    # Print the input values (redirected to stderr)
    echo "🔧 get_lb_external_ip:" >&2
    echo "  🗂️  Kubeconfig: $kubeconfig" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "  📦 Namespace: $namespace" >&2
    echo "  🛠️  Service: $service_name" >&2
    echo "  🔧 Service Type: $service_type" >&2

    service_type_existing=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.type}')

    if [ "$service_type_existing" != "$service_type" ]; then
        echo "${service_name}.${namespace}.svc.cluster.local:9090"
    elif [ "$service_type" = "LoadBalancer" ]; then
        ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        echo "$ip:9090"
    elif [ "$service_type" = "NodePort" ]; then
        node_port=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].nodePort}')
        node_ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "$node_ip:$node_port"
    elif [ "$service_type" = "ClusterIP" ]; then
        cluster_ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.clusterIP}')
        service_port=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}')
        echo "$cluster_ip:$service_port"
    else
        echo "Unsupported service type: $service_type" >&2
        return 1
    fi
}

get_grafana_external_ip() {
    local kubeconfig="$1"
    local kubecontext="$2"
    local namespace="$3"
    local service_name="$4"
    local service_type="$5"

    # Print the input values (redirected to stderr)
    echo "🔧 get_lb_external_ip:" >&2
    echo "  🗂️  Kubeconfig: $kubeconfig" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "  📦 Namespace: $namespace" >&2
    echo "  🛠️  Service: $service_name" >&2
    echo "  🔧 Service Type: $service_type" >&2

    service_type_existing=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.type}')

    if [ "$service_type_existing" != "$service_type" ]; then
        echo "defined_service_type_is_not_correct"
    elif [ "$service_type" = "LoadBalancer" ]; then
        ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        echo "$ip"
    elif [ "$service_type" = "NodePort" ]; then
        node_port=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].nodePort}')
        node_ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "$node_ip:$node_port"
    elif [ "$service_type" = "ClusterIP" ]; then
        cluster_ip=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.clusterIP}')
        service_port=$(kubectl --kubeconfig "$kubeconfig" --context "$kubecontext" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}')
        echo "$cluster_ip:$service_port"
    else
        echo "Unsupported service type: $service_type" >&2
        return 1
    fi
}

upgrade_cluster_registration(){
    echo "🚀 Starting cluster registration in controller cluster..."

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Cluster Registration" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Cluster Registration "
    echo "  🗂️     Kubeconfig Path: $kubeconfig_path"
    echo "  🌐 Kubecontext: $kubecontext"
    echo "-----------------------------------------"

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:"
        echo "  🗂️     Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
        echo "  🗂️     Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        exit 1
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:"
    echo "  kubeconfig_path=$kubeconfig_path"
    echo "  context_arg=$context_arg"
    echo "  namespace=$namespace"
    echo "-----------------------------------------"

    for registration in "${KUBESLICE_CLUSTER_REGISTRATIONS[@]}"; do
        IFS="|" read -r cluster_name project_name telemetry_enabled telemetry_endpoint telemetry_provider geo_location_provider geo_location_region <<<"$registration"

        echo "-----------------------------------------"
        echo "🚀 Upgrading Registered cluster '$cluster_name' in project '$project_name' within namespace '$namespace'"
        echo "-----------------------------------------"

        
        kubectl apply -f "$INSTALLATION_FILES_PATH/${cluster_name}_cluster.yaml" --kubeconfig $kubeconfig_path $context_arg -n kubeslice-$project_name
        echo "🔍 Verifying cluster registration for '$cluster_name'..."
        kubectl get cluster.controller.kubeslice.io -n kubeslice-$project_name --kubeconfig $kubeconfig_path $context_arg | grep $cluster_name

        echo "-----------------------------------------"
        echo "✔️  Cluster '$cluster_name' Upgraded successfully in project '$project_name' with telemetry endpoint values."
        echo "-----------------------------------------"
    done
    echo "✔️ Cluster registration upgradation in controller cluster complete."
}

# Function to fetch secrets from the worker clusters and create worker values file
prepare_worker_values_file() {

    for worker_index in "${!KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<<"${KUBESLICE_WORKERS[$worker_index]}"

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
        kubeconfig=$(echo "$worker" | yq e '.kubeconfig' -)
        kubecontext=$(echo "$worker" | yq e '.kubecontext' -)
        specific_use_local_charts=$(echo "$worker" | yq e '.specific_use_local_charts' -)

        if [ "$use_global_kubeconfig" = "true" ]; then
                    kubeconfigname=$(yq e '.global_kubeconfig' "$EGS_INPUT_YAML")
                    kubecontextname=$(yq e '.global_kubecontext' "$EGS_INPUT_YAML")
        else
                kubeconfigname=$(echo "$worker" | yq e '.kubeconfig' -)
                kubecontextname=$(echo "$worker" | yq e '.kubecontext' -)
        fi

        global_auto_fetch_endpoint=$(yq e '.global_auto_fetch_endpoint' "$EGS_INPUT_YAML")
        global_prometheus_namespace=$(yq e '.global_prometheus_namespace' "$EGS_INPUT_YAML")
        global_prometheus_service_name=$(yq e '.global_prometheus_service_name' "$EGS_INPUT_YAML")
        global_prometheus_service_type=$(yq e '.global_prometheus_service_type' "$EGS_INPUT_YAML")
        global_grafana_namespace=$(yq e '.global_grafana_namespace' "$EGS_INPUT_YAML")
        global_grafana_service_name=$(yq e '.global_grafana_service_name' "$EGS_INPUT_YAML")
        global_grafana_service_type=$(yq e '.global_grafana_service_type' "$EGS_INPUT_YAML")



        echo "Worker data testing:"
        echo "$worker" | yq e '.' -

        reg_cluster=$(yq e ".cluster_registration[$worker_index]" "$EGS_INPUT_YAML")
        echo "cluster registration data ..."
        echo "$reg_cluster" | yq e '.' -
        echo "installation path.."
        echo $INSTALLATION_FILES_PATH
        cluster_name=$(yq e ".cluster_registration[$worker_index].cluster_name" "$EGS_INPUT_YAML")
        project_name=$(yq e ".cluster_registration[$worker_index].project_name" "$EGS_INPUT_YAML")



        local_auto_fetch_endpoint=$(echo "$worker" | yq e '.local_auto_fetch_endpoint' -)

        if [ -z "$local_auto_fetch_endpoint" ] || [ "$local_auto_fetch_endpoint" = "null" ]; then
            auto_fetch_endpoint=$global_auto_fetch_endpoint
        elif [ -z "$global_auto_fetch_endpoint" ] || [ "$global_auto_fetch_endpoint" = "null" ]; then
            auto_fetch_endpoint=$local_auto_fetch_endpoint
        else
            auto_fetch_endpoint=$local_auto_fetch_endpoint
        fi

        echo "local_auto_fetch_endpoint: $local_auto_fetch_endpoint"
        echo "global_auto_fetch_endpoint: $global_auto_fetch_endpoint"
        echo "auto_fetch_endpoint: $auto_fetch_endpoint"

        

        local_prometheus_namespace=$(echo "$worker" | yq e '.local_prometheus_namespace' -)
        if [ -z "$local_prometheus_namespace" ] || [ "$local_prometheus_namespace" = "null" ]; then
            prometheus_namespace=$global_prometheus_namespace
        elif [ -z "$global_prometheus_namespace" ] || [ "$global_prometheus_namespace" = "null" ]; then
            prometheus_namespace=$local_prometheus_namespace
        else
            prometheus_namespace=$local_prometheus_namespace
        fi
        echo "prometheus_namespace: $prometheus_namespace"

        
        local_prometheus_service_name=$(echo "$worker" | yq e '.local_prometheus_service_name' -)
        if [ -z "$local_prometheus_service_name" ] || [ "$local_prometheus_service_name" = "null" ]; then
            prometheus_service_name=$global_prometheus_service_name
        elif [ -z "$global_prometheus_service_name" ] || [ "$global_prometheus_service_name" = "null" ]; then
            prometheus_service_name=$local_prometheus_service_name
        else
            prometheus_service_name=$local_prometheus_service_name
        fi
        echo "prometheus_service_name: $prometheus_service_name"

        

        local_prometheus_service_type=$(echo "$worker" | yq e '.local_prometheus_service_type' -)
        if [ -z "$local_prometheus_service_type" ] || [ "$local_prometheus_service_type" = "null" ]; then
            prometheus_service_type=$global_prometheus_service_type
        elif [ -z "$global_prometheus_service_type" ] || [ "$global_prometheus_service_type" = "null" ]; then
            prometheus_service_type=$local_prometheus_service_type
        else
            prometheus_service_type=$local_prometheus_service_type
        fi
        echo "prometheus_service_type: $prometheus_service_type"


        
        local_grafana_namespace=$(echo "$worker" | yq e '.local_grafana_namespace' -)
        if [ -z "$local_grafana_namespace" ] || [ "$local_grafana_namespace" = "null" ]; then
            grafana_namespace=$global_grafana_namespace
        elif [ -z "$global_grafana_namespace" ] || [ "$global_grafana_namespace" = "null" ]; then
            grafana_namespace=$local_grafana_namespace
        else
            grafana_namespace=$local_grafana_namespace
        fi
        echo "grafana_namespace: $grafana_namespace"


        
        local_grafana_service_name=$(echo "$worker" | yq e '.local_grafana_service_name' -)
        if [ -z "$local_grafana_service_name" ] || [ "$local_grafana_service_name" = "null" ]; then
            grafana_service_name=$global_grafana_service_name
        elif [ -z "$global_grafana_service_name" ] || [ "$global_grafana_service_name" = "null" ]; then
            grafana_service_name=$local_grafana_service_name
        else
            grafana_service_name=$local_grafana_service_name
        fi
        echo "grafana_service_name: $grafana_service_name"

        
        local_grafana_service_type=$(echo "$worker" | yq e '.local_grafana_service_type' -)
        if [ -z "$local_grafana_service_type" ] || [ "$local_grafana_service_type" = "null" ]; then
            grafana_service_type=$global_grafana_service_type
        elif [ -z "$global_grafana_service_type" ] || [ "$global_grafana_service_type" = "null" ]; then
            grafana_service_type=$local_grafana_service_type
        else
            grafana_service_type=$local_grafana_service_type
        fi
        echo "grafana_service_type: $grafana_service_type"

        if [[ "$auto_fetch_endpoint" == "true" && -n "$auto_fetch_endpoint" ]]; then

            if [[ -z "$auto_fetch_endpoint" || -z "$prometheus_namespace" || -z "$prometheus_service_name" || -z "$prometheus_service_type" || -z "$grafana_namespace" || -z "$grafana_service_name" || -z "$grafana_service_type" ]]; then
                    echo "Error: One or more required values are missing. Skipping Prometheus and Grafana endpoint updates."
            else
                prometheus_endpoint=""
                while [ -z "${prometheus_endpoint}" ]; do 
                    prometheus_endpoint="$(get_prometheus_external_ip "${kubeconfigname}" "${kubecontextname}" "${prometheus_namespace}" "${prometheus_service_name}" "${prometheus_service_type}")"
                    sleep 10 
                done

                prometheus_url="http://${prometheus_endpoint}"
                
                
                yq eval ".kubeslice_worker_egs[$worker_index].inline_values.egs.prometheusEndpoint = \"${prometheus_url}\" | del(.null)" --inplace "${EGS_INPUT_YAML}"
                echo "Updated Prometheus endpoint for worker ${worker_name}: ${prometheus_url}"

                yq eval ".cluster_registration[$worker_index].telemetry.endpoint = \"${prometheus_url}\"" --inplace "${EGS_INPUT_YAML}"
                echo "Updated Prometheus endpoint for cluster  ${cluster_name}: ${prometheus_url}"
                sed -i "s|endpoint: .*|endpoint: ${prometheus_url}|" "$INSTALLATION_FILES_PATH/${cluster_name}_cluster.yaml"

                echo "Waiting for Grafana service to get an IP or port for worker..."
                external_ip=""

                while [ -z "${external_ip}" ] ; do 
                    external_ip="$(get_grafana_external_ip "${kubeconfigname}" "${kubecontextname}" "${grafana_namespace}" "${grafana_service_name}" "${grafana_service_type}")"
                    sleep 10 
                done

                grafana_url="http://${external_ip}/d/Oxed_c6Wz"
                echo "Grafana URL: ${grafana_url}"

                yq eval ".kubeslice_worker_egs[$worker_index].inline_values.egs.grafanaDashboardBaseUrl = \"${grafana_url}\" | del(.null)" --inplace "${EGS_INPUT_YAML}"

            fi

        else
            echo "Auto fetch endpoint is not enabled or empty. Skipping Prometheus and Grafana endpoint updates if it is false or please provide proper input if you haven't give any."
        fi


        enable_autofetch_egsagent_endpoint_and_token=$(yq e '.enable_autofetch_egsagent_endpoint_and_token' "$EGS_INPUT_YAML")
        echo "value of enable_autofetch_egsagent_endpoint_and_token: $enable_autofetch_egsagent_endpoint_and_token"

        if [[ "$enable_autofetch_egsagent_endpoint_and_token" == "true" && -n "$enable_autofetch_egsagent_endpoint_and_token" ]]; then

            if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$KUBESLICE_UI_SKIP_INSTALLATION" = "false" ]; then
                
                kubeconfig_path=$(yq e '.global_kubeconfig' "$EGS_INPUT_YAML")
                kubecontext_path=$(yq e '.global_kubecontext' "$EGS_INPUT_YAML")

                # Service details
                namespace="$KUBESLICE_UI_NAMESPACE"
                service_name="kubeslice-ui-proxy"

                # Get the service type
                service_type_existing=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.type}')
                echo " existing service type is: $service_type_existing"

                ui_proxy_url=""

                if [ "$service_type_existing" = "LoadBalancer" ]; then
                    
                        ui_proxy_url=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get svc -n "$namespace" "$service_name" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' )
                    
                    if [ -z "$ui_proxy_url" ]; then
                        ui_proxy_url=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get svc -n "$namespace" "$service_name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' )
                    fi

                    echo "🔗 LoadBalancer service detected. IP/Hostname: $ui_proxy_url"

                elif [ "$service_type_existing" = "NodePort" ]; then
                    # Get NodePort
                    node_port=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].nodePort}')
                    
                    # Get first node's internal IP
                    node_ip=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                    
                    ui_proxy_url="${node_ip}:${node_port}"
                    echo "🔗 NodePort service detected. Node IP and Port: $ui_proxy_url"

                elif [ "$service_type_existing" = "ClusterIP" ]; then
                    # Get ClusterIP and port
                    cluster_ip=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.clusterIP}')
                    service_port=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}')
                    
                    ui_proxy_url="${cluster_ip}:${service_port}"
                    echo "🔗 ClusterIP service detected. Cluster IP and Port: $ui_proxy_url"

                else
                    echo "❌ Unsupported service type: $service_type_existing" >&2
                    exit 1
                fi

                # Check if we have a valid URL
                if [ -n "$ui_proxy_url" ]; then
                    echo "🔗 **Updating Kubeslice UI Proxy URL**: https://$ui_proxy_url in values file"
                    yq eval ".kubeslice_worker_egs[$worker_index].inline_values.egsAgent.agentSecret.endpoint = \"https://$ui_proxy_url\" | del(.null)" --inplace "${EGS_INPUT_YAML}"
                else
                    echo "❌ Error: Unable to retrieve a valid endpoint for kubeslice-ui-proxy"
                    exit 1
                fi
            else
                echo "⏩ **Kubeslice UI installation was skipped or disabled.**"
            fi


            if [ "$ENABLE_PROJECT_CREATION" = "true" ]; then
                for project in "${KUBESLICE_PROJECTS[@]}"; do
                    IFS="|" read -r project_name project_username <<<"$project"
                    token=$(kubectl get secret "kubeslice-rbac-rw-$project_username" -o jsonpath="{.data.token}" -n "kubeslice-$project_name" --kubeconfig "$kubeconfig_path" --context "$kubecontext_path" 2>/dev/null | base64 --decode || echo "")
                    if [ -n "$token" ]; then
                        echo "🔑 **updating Token for project '$project_name' (username: $project_username)**: $token in values file"
                        yq eval ".kubeslice_worker_egs[$worker_index].inline_values.egsAgent.agentSecret.key = \"$token\" | del(.null)" --inplace "${EGS_INPUT_YAML}"
                    else
                        echo "⚠️ Warning: Token for project '$project_name' (username: $project_username) not available."
                    fi
                done
            else
                echo "⏩ **Project creation was skipped or disabled.**"
            fi
        
        else
            echo "Auto fetch endpoint and token is not enabled or empty. Skipping egsAgent Endpoint and Token endpoint updates."
        fi
        
        echo "  Extracted values for worker $worker_name:"
        echo "  Worker Name: $worker_name"
        echo "  Skip Installation: $skip_installation"
        echo "  Use Global Kubeconfig: $use_global_kubeconfig"
        echo "  Namespace: $namespace"
        echo "  Release Name: $release_name"
        echo "  Chart Name: $chart_name"
        echo "  Values File: $values_file"
        echo "  Helm Flags: $helm_flags"
        echo "  Verify Install: $verify_install"
        echo "  Verify Install Timeout: $verify_install_timeout"
        echo "  Skip on Verify Fail: $skip_on_verify_fail"
        echo "  Version: $version"
        echo "  kubecontext: $kubecontext"
        echo "  kubeconfig: $kubeconfig"
        echo "  Specific Use Local Charts: $specific_use_local_charts"

        echo "🚀 Fetching controller context"
        # Use kubeaccess_precheck to determine the controller kubeconfig path and context
        read -r controller_kubeconfig_path controller_kubecontext < <(kubeaccess_precheck \
            "Fetching secrets for $worker_name from Kubeslice Controller" \
            "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$KUBESLICE_CONTROLLER_KUBECONFIG" \
            "$KUBESLICE_CONTROLLER_KUBECONTEXT")

        # Print output variables after calling kubeaccess_precheck
        echo "🔧 kubeaccess_precheck - Output Variables: Controller: Fetching secrets for $worker_name from Kubeslice Controller"
        echo "  🗂️ Kubeconfig Path: $controller_kubeconfig_path"
        echo "  🌐 Kubecontext: $controller_kubecontext"
        echo "-----------------------------------------"

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$controller_kubeconfig_path" && "$controller_kubeconfig_path" != "null" && -n "$controller_kubecontext" && "$controller_kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:"
            echo "  🗂️ Kubeconfig Path: $controller_kubeconfig_path"
            echo "  🌐 Kubecontext: $controller_kubecontext"

            validate_kubecontext "$controller_kubeconfig_path" "$controller_kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
            echo "  🗂️ Kubeconfig Path: $controller_kubeconfig_path"
            echo "  🌐 Kubecontext: $controller_kubecontext"
            exit 1
        fi

        local controller_context_arg=""
        if [ -n "$controller_kubecontext" ] && [ "$controller_kubecontext" != "null" ]; then
            controller_context_arg="--context $controller_kubecontext"
        fi

        # Use kubeaccess_precheck to determine worker kubeconfig path and context
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "$worker_name" \
            "$use_global_kubeconfig" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$kubeconfig" \
            "$kubecontext")

        # Print output variables after calling kubeaccess_precheck
        echo "🔧 kubeaccess_precheck - Output Variables: Fetching secrets for $worker_name from Kubeslice Controller"
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        echo "-----------------------------------------"

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:"
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"

            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
            echo "  🗂️ Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"
            exit 1
        fi

        local context_arg=""
        if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
            context_arg="--context $kubecontext"
        fi

        # Extract and output inline values from the EGS input YAML
        inline_values=$(yq e ".kubeslice_worker_egs[$worker_index].inline_values | select(. != null)" "$EGS_INPUT_YAML")
        echo "Inline values extracted for worker $worker_name:"
        echo "$inline_values"

        local secret_name="kubeslice-rbac-worker-$worker_name"
        local controller_secret_file="$INSTALLATION_FILES_PATH/${secret_name}.yaml"
        local worker_endpoint

        # Fetch the secret from the worker cluster
        echo "🔍 Fetching secret '$secret_name' from worker cluster..."

        # Print the command that will be executed
        echo "kubectl get secret $secret_name -n kubeslice-$project_name --kubeconfig $controller_kubeconfig_path $controller_context_arg -o yaml"

        worker_secret=$(kubectl get secret $secret_name -n kubeslice-$project_name --kubeconfig $controller_kubeconfig_path $controller_context_arg -o yaml)

        # Decode the relevant fields from the controller secret
        ca_crt=$(echo "$worker_secret" | yq e '.data["ca.crt"]')
        token=$(echo "$worker_secret" | yq e '.data.token')
        namespace=$(echo "$worker_secret" | yq e '.data.namespace')
        controller_endpoint=$(echo "$worker_secret" | yq e '.data.controllerEndpoint')
        cluster_name=$(echo "$worker_secret" | yq e '.data.clusterName' - | base64 --decode)

        # Determine the cluster endpoint and name
        if [ -n "$inline_values" ] && [ "$inline_values" != "{}" ]; then
            # Check if the cluster object is present and if it's empty
            cluster_object_present=$(echo "$inline_values" | yq e '.cluster // null' -)
            if [ "$cluster_object_present" != "null" ]; then
                # Check if the cluster object is empty
                is_cluster_empty=$(echo "$inline_values" | yq e '.cluster | length == 0' -)
                if [ "$is_cluster_empty" = "true" ]; then
                    echo "Error: The cluster object is present in inline values but is empty."
                    exit 1
                fi
            fi

            inline_clustername=$(echo "$inline_values" | yq e '.cluster.name // null' -)
            inline_endpoint=$(echo "$inline_values" | yq e '.cluster.endpoint // null' -)

            # Ensure the cluster name always matches the one from secrets
            if [ "$inline_clustername" != "null" ] && [ "$inline_clustername" != "$cluster_name" ]; then
                echo "Error: The inline cluster name ($inline_clustername) does not match the expected cluster name ($cluster_name)."
                exit 1
            fi

            # Fetch the worker endpoint if not provided in inline values
            if [ -z "$inline_endpoint" ] || [ "$inline_endpoint" == "null" ]; then
                echo "🔍 No endpoint found in inline values. Attempting to fetch the worker endpoint..."
                worker_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

                if [ -z "$worker_endpoint" ]; then
                    echo "⚠️ Warning: Failed to fetch worker endpoint.Pass the Worker K8s Cluster Api Server endpoint using inline values from input yaml "
                    exit 1
                else
                    worker_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
                    echo "✔️ Fetched worker endpoint: $worker_endpoint"
                fi
            else
                worker_endpoint=$inline_endpoint
                echo "✔️ Worker endpoint is provided in inline values: $worker_endpoint"
            fi
        else
            echo "⚠️ Warning: Worker inline values are empty or not provided."

            # Fetch the worker endpoint if inline values are empty or not provided
            worker_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

            if [ -z "$worker_endpoint" ]; then
                echo "⚠️ Warning: Failed to fetch worker endpoint. Setting a default value.Pass the Worker K8s Cluster Api Server endpoint using inline values from input yaml "
                exit 1
            else
                worker_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
                echo "✔️ Fetched worker endpoint: $worker_endpoint"
            fi
        fi

        # Ensure the cluster object is properly created in the final values file
        if [ -z "$inline_clustername" ] || [ "$inline_clustername" == "null" ]; then
            inline_clustername="$cluster_name"
        fi

        # Generate the final values file
        echo "🔧 Generating final values file: $INSTALLATION_FILES_PATH/${worker_name}_final_values.yaml"
        cat <<EOF >"$INSTALLATION_FILES_PATH/${worker_name}_final_values.yaml"
controllerSecret:
  namespace: $namespace
  endpoint: $controller_endpoint
  ca.crt: $ca_crt
  token: $token

cluster:
  name: $cluster_name
  endpoint: $worker_endpoint

EOF

        # Append the remaining inline values (excluding the cluster object)
        echo "$inline_values" | yq e 'del(.cluster)' - >>"$INSTALLATION_FILES_PATH/${worker_name}_final_values.yaml"

        echo "✔️ Worker values file prepared and saved as '${worker_name}_final_values.yaml'."
        echo "-----------------------------------------"

    done
    echo "✔️ Worker values file preparation complete."
}

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
    echo "$inline_values" | yq eval -P - >"$values_file_path"

    # Return the file path to be used in Helm command
    echo "$values_file_path"
}

# Function to create a unique directory for each run
create_unique_run_dir() {
    local base_dir="$INSTALLATION_FILES_PATH/run"
    local release_name=$1
    local run_dir="$base_dir/helm_run_$(date +%Y%m%d_%H%M%S)_${release_name}"

    mkdir -p "$run_dir"
    echo "$run_dir"
}


# Function to merge inline values and remove duplicates
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
        echo "$inline_values" | yq eval -P - >>"$combined_values_file"

        # Remove duplicates, keeping the first occurrence
        yq eval 'with(.[]; . as $item ireduce({}; . *+ $item))' "$combined_values_file" -o=yaml >"$run_dir/temp_combined_values.yaml"

        # Replace the original combined file with the deduplicated version
        mv "$run_dir/temp_combined_values.yaml" "$combined_values_file"
    fi

    echo "$combined_values_file"
}

# Initialize skip flags with default values
SKIP_PRECHECKS="false"
SKIP_CONTROLLER_INSTALL="false"
SKIP_UI_INSTALL="false"
SKIP_PROJECT_CREATION="false"
SKIP_CLUSTER_REGISTRATION="false"
SKIP_PREPARE_WORKER_VALUES="false"
SKIP_WORKER_INSTALL="false"

# Parse command-line arguments for options
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --input-yaml)
        EGS_INPUT_YAML="$2"
        shift
        ;;
    --skip-prechecks)
        SKIP_PRECHECKS="true"
        ;;
    --skip-controller-install)
        SKIP_CONTROLLER_INSTALL="true"
        ;;
    --skip-ui-install)
        SKIP_UI_INSTALL="true"
        ;;
    --skip-project-creation)
        SKIP_PROJECT_CREATION="true"
        ;;
    --skip-cluster-registration)
        SKIP_CLUSTER_REGISTRATION="true"
        ;;
    --skip-prepare-worker-values)
        SKIP_PREPARE_WORKER_VALUES="true"
        ;;
    --skip-worker-install)
        SKIP_WORKER_INSTALL="true"
        ;;
    --help)
        echo "Usage: $0 --input-yaml <yaml_file> [options]"
        echo "Options:"
        echo "  --input-yaml <yaml_file>            Path to the input configuration YAML file."
        echo "  --skip-prechecks                    Skip Kubeslice pre-checks."
        echo "  --skip-controller-install           Skip Kubeslice Controller installation."
        echo "  --skip-ui-install                   Skip Kubeslice UI installation."
        echo "  --skip-project-creation             Skip project creation in the controller cluster."
        echo "  --skip-cluster-registration         Skip cluster registration in the controller cluster."
        echo "  --skip-prepare-worker-values        Skip preparation of worker values files."
        echo "  --skip-worker-install               Skip worker installation."
        echo "  --help                              Display this help message."
        exit 0
        ;;
    *)
        echo "Unknown parameter passed: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
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
    echo "📂 Parsing input YAML file: $EGS_INPUT_YAML"
    # Run prerequisite checks if precheck is enabled
    prerequisite_check
    if command -v yq &>/dev/null; then
        parse_yaml "$EGS_INPUT_YAML"
        echo "🔍 Calling validate_paths..."
        validate_paths
    else
        echo "❌ yq command not found. Please install yq to use the --input-yaml option."
        exit 1
    fi
fi

# Run Kubeslice pre-checks if enabled
if [ "$KUBESLICE_PRECHECK" = "true" ]  && [ "$SKIP_PRECHECKS" != "true" ]; then
    echo "🚀 Running Kubeslice pre-checks..."
    kubeslice_pre_check
fi


# Process kubeslice-controller installation if enabled
if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ] && [ "$SKIP_CONTROLLER_INSTALL" != "true" ]; then
    echo "🚀 Installing or upgrading Kubeslice Controller..."
    install_or_upgrade_helm_chart "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_CHART_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT" "$KUBESLICE_CONTROLLER_REPO_URL" "$KUBESLICE_CONTROLLER_USERNAME" "$KUBESLICE_CONTROLLER_PASSWORD" "$KUBESLICE_CONTROLLER_VALUES_FILE" "$KUBESLICE_CONTROLLER_INLINE_VALUES" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_REPO" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_USERNAME" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_PASSWORD" "$KUBESLICE_CONTROLLER_IMAGE_PULL_SECRET_EMAIL" "$KUBESLICE_CONTROLLER_HELM_FLAGS" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$KUBESLICE_CONTROLLER_VERSION" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL"
fi

# Process kubeslice-ui installation if enabled
if [ "$ENABLE_INSTALL_UI" = "true" ] && [ "$SKIP_UI_INSTALL" != "true" ]; then
    echo "🚀 Installing or upgrading Kubeslice UI..."
    install_or_upgrade_helm_chart "$KUBESLICE_UI_SKIP_INSTALLATION" "$KUBESLICE_UI_RELEASE_NAME" "$KUBESLICE_UI_CHART_NAME" "$KUBESLICE_UI_NAMESPACE" "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_UI_KUBECONFIG" "$KUBESLICE_UI_KUBECONTEXT" "$KUBESLICE_UI_REPO_URL" "$KUBESLICE_UI_USERNAME" "$KUBESLICE_UI_PASSWORD" "$KUBESLICE_UI_VALUES_FILE" "$KUBESLICE_UI_INLINE_VALUES" "$KUBESLICE_UI_IMAGE_PULL_SECRET_REPO" "$KUBESLICE_UI_IMAGE_PULL_SECRET_USERNAME" "$KUBESLICE_UI_IMAGE_PULL_SECRET_PASSWORD" "$KUBESLICE_UI_IMAGE_PULL_SECRET_EMAIL" "$KUBESLICE_UI_HELM_FLAGS" "$USE_LOCAL_CHARTS" "$LOCAL_CHARTS_PATH" "$KUBESLICE_UI_VERSION" "$KUBESLICE_UI_VERIFY_INSTALL" "$KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_UI_SKIP_ON_VERIFY_FAIL"
fi

# Create projects in the controller cluster before deploying workers
if [ "$ENABLE_PROJECT_CREATION" = "true" ] && [ "$SKIP_PROJECT_CREATION" != "true" ];  then
    echo "🚀 Creating projects in the controller cluster..."
    create_projects_in_controller
fi

# Register clusters in the controller cluster after projects have been created
if [ "$ENABLE_CLUSTER_REGISTRATION" = "true" ] && [ "$SKIP_CLUSTER_REGISTRATION" != "true" ];  then
    echo "🚀 Registering clusters in the controller cluster..."
    register_clusters_in_controller
fi

if [ "$ENABLE_PREPARE_WORKER_VALUES_FILE" = "true" ]  && [ "$SKIP_PREPARE_WORKER_VALUES" != "true" ]; then
    echo "🚀 Preparing worker values file for: $worker_name"
    prepare_worker_values_file
fi

if [ "$ENABLE_CLUSTER_REGISTRATION" = "true" ] && [ "$SKIP_CLUSTER_REGISTRATION" != "true" ];  then
    echo "🚀 Upgrading registered clusters in the controller cluster with telemetry endpoint..."
    upgrade_cluster_registration
fi

# Inside the loop where you process each worker
if [ "$ENABLE_INSTALL_WORKER" = "true" ] && [ "$SKIP_WORKER_INSTALL" != "true" ]; then
    for worker_index in "${!KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<<"${KUBESLICE_WORKERS[$worker_index]}"

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
        kubeconfig=$(echo "$worker" | yq e '.kubeconfig' -)
        kubecontext=$(echo "$worker" | yq e '.kubecontext' -)

        # Create a unique directory for this worker's run
        run_dir=$(create_unique_run_dir "$release_name")

        # Merge the prepared values and inline values
        combined_values_file=$(merge_inline_values "$prepared_values_file" "$inline_values" "$worker_name" "$run_dir")

        # Debugging: Output the combined values file to check the contents
        echo "Generated combined values file for $worker_name:"
        cat "$combined_values_file"

        echo "🔍 Installing or upgrading Helm chart for worker: $worker_name"
        # Now call the install_or_upgrade_helm_chart function in a similar fashion to the controller
        install_or_upgrade_helm_chart "$skip_installation" "$release_name" "$chart_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$repo_url" "$username" "$password" "$combined_values_file" "" "$image_pull_secret_repo" "$image_pull_secret_username" "$image_pull_secret_password" "$image_pull_secret_email" "$helm_flags" "$specific_use_local_charts" "$LOCAL_CHARTS_PATH" "$version" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"
    done
fi

trap display_summary EXIT

echo "========================================="
echo "    EGS Installer Script Complete        "
echo "========================================="

echo "=====================================EGS Installer Script execution completed at: $(date)===================================" >> "$output_file"
