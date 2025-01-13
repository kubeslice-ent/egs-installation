#!/bin/bash

# Check if the script is running in Bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Error: This script must be run in a Bash shell."
    echo "Please run the script using: bash script_name.sh"
    exit 1
else
    echo "✅ Bash shell detected. Version: $BASH_VERSION"
fi

# Specify the output file
output_file="egs-uninstaller-output.log"
exec > >(tee -a "$output_file") 2>&1

echo "=====================================EGS UnInstaller Script execution started at: $(date)===================================" >> "$output_file"

# Function to handle operations that should continue on error
continue_on_error() {
    "$@"
    if [[ $? -ne 0 ]]; then
        echo "❌ Error encountered during execution of: $*"
    fi
}

# Print introductory statement
echo "========================================="
echo "           EGS UnInstaller Script          "
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
        echo "🔧 Input Values to kubeaccess_precheck:" >&2
        echo "  📛 Component Name: kubeslice-controller" >&2
        echo "  🌐 Use Global Kubeconfig: $KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" >&2
        echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG" >&2
        echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT" >&2
        echo "  🗂️  Component Kubeconfig: $KUBESLICE_CONTROLLER_KUBECONFIG" >&2
        echo "  🌐 Component Kubecontext: $KUBESLICE_CONTROLLER_KUBECONTEXT" >&2
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
        echo "🔧 Return Values from kubeaccess_precheck:" >&2
        echo "  🗂️  kubeconfig_path=$kubeconfig_path" >&2
        echo "  🌐 kubecontext=$kubecontext" >&2

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:" >&2
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path" >&2
            echo "  🌐 Kubecontext: $kubecontext" >&2

            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path" >&2
            echo "  🌐 Kubecontext: $kubecontext" >&2
            exit 1
        fi

        # Prepare the context argument if the context is available
        local context_arg=""
        if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            context_arg="--context $kubecontext"
        fi

        echo "-----------------------------------------" >&2
        echo "🔍 Validating access to the kubeslice-controller cluster using kubeconfig '$kubeconfig_path'..." >&2
        echo "🔧 Variables:" >&2
        echo "  ENABLE_INSTALL_CONTROLLER=$ENABLE_INSTALL_CONTROLLER" >&2
        echo "  KUBESLICE_CONTROLLER_SKIP_INSTALLATION=$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" >&2
        echo "  kubeconfig_path=$kubeconfig_path" >&2
        echo "  kubecontext=$kubecontext" >&2
        echo "  KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG=$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" >&2
        echo "  GLOBAL_KUBECONFIG=$GLOBAL_KUBECONFIG" >&2
        echo "  GLOBAL_KUBECONTEXT=$GLOBAL_KUBECONTEXT" >&2
        echo "  context_arg=$context_arg" >&2
        echo "-----------------------------------------" >&2

        cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "❌ Error: Unable to access the kubeslice-controller cluster using kubeconfig '$kubeconfig_path'." >&2 
            echo "Details: $cluster_info" >&2
            exit 1
        fi

        controller_cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

        echo "✔️  Successfully accessed kubeslice-controller cluster. Kubernetes endpoint: $controller_cluster_endpoint" >&2 
        echo "-----------------------------------------" >&2
    else
        echo "⏩ Skipping kubeslice-controller cluster validation as installation is skipped or not enabled." >&2 
    fi
    # Validate access to the kubeslice-ui cluster if installation is not skipped
    if [[ "$ENABLE_INSTALL_UI" == "true" && "$KUBESLICE_UI_SKIP_INSTALLATION" == "false" ]]; then

        # Print the input variables
        echo "🔧 kubeaccess_precheck - Input Variables:" >&2 
        echo "  📛 Component Name: kubeslice-ui" >&2 
        echo "  🌐 Use Global Kubeconfig: $KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" >&2 
        echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG" >&2  
        echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT" >&2 
        echo "  🗂️  Component Kubeconfig: $KUBESLICE_UI_KUBECONFIG" >&2 
        echo "  🌐 Component Kubecontext: $KUBESLICE_UI_KUBECONTEXT" >&2 
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
        echo "🔧 kubeaccess_precheck - Output Variables:" >&2 
        echo "  🗂️  Kubeconfig Path: $kubeconfig_path" >&2 
        echo "  🌐 Kubecontext: $kubecontext" >&2  
        echo "-----------------------------------------"

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:" >&2 
            echo "  🗂️   Kubeconfig Path: $kubeconfig_path" >&2 
            echo "  🌐 Kubecontext: $kubecontext" >&2 

            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2 
            echo "  🗂️   Kubeconfig Path: $kubeconfig_path" >&2 
            echo "  🌐 Kubecontext: $kubecontext" >&2 
            exit 1
        fi

        # Prepare the context argument if the context is available
        local context_arg=""
        if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            context_arg="--context $kubecontext"
        fi
        echo "-----------------------------------------" >&2 
        echo "🔍 Validating access to the kubeslice-ui cluster using kubeconfig '$kubeconfig_path'..." >&2 
        echo "🔧 Variables:" >&2 
        echo "  ENABLE_INSTALL_UI=$ENABLE_INSTALL_UI" >&2 
        echo "  KUBESLICE_UI_SKIP_INSTALLATION=$KUBESLICE_UI_SKIP_INSTALLATION" >&2 
        echo "  kubeconfig_path=$kubeconfig_path" >&2 
        echo "  kubecontext=$kubecontext" >&2 
        echo "  KUBESLICE_UI_USE_GLOBAL_KUBECONFIG=$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" >&2 
        echo "  GLOBAL_KUBECONFIG=$GLOBAL_KUBECONFIG" >&2 
        echo "  GLOBAL_KUBECONTEXT=$GLOBAL_KUBECONTEXT" >&2 
        echo "-----------------------------------------" >&2 

        cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "❌ Error: Unable to access the kubeslice-ui cluster using kubeconfig '$kubeconfig_path'." >&2 
            echo "Details: $cluster_info"
            exit 1
        fi

        ui_cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")

        echo "✔️  Successfully accessed kubeslice-ui cluster. Kubernetes endpoint: $ui_cluster_endpoint" >&2 
        echo "-----------------------------------------" >&2 
    else
        echo "⏩ Skipping kubeslice-ui cluster validation as installation is skipped or not enabled." >&2 
    fi

    # Iterate through each worker configuration and validate access if installation is not skipped
    for worker in "${KUBESLICE_WORKERS[@]}"; do
        IFS="|" read -r worker_name skip_installation use_global_kubeconfig kubeconfig kubecontext namespace release_name chart_name repo_url username password values_file inline_values image_pull_secret_repo image_pull_secret_username image_pull_secret_password image_pull_secret_email helm_flags verify_install verify_install_timeout skip_on_verify_fail <<<"$worker"

        if [[ "$skip_installation" == "false" ]]; then
            # Print the input variables for the kubeaccess_precheck function 
            echo "🔧 Input Variables for kubeaccess_precheck:" >&2 
            echo "  📛 Component Name: $worker_name" >&2 
            echo "  🌐 Use Global Kubeconfig: $use_global_kubeconfig" >&2 
            echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG" >&2 
            echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT" >&2 
            echo "  🗂️  Component Kubeconfig: $kubeconfig" >&2 
            echo "  🌐 Component Kubecontext: $kubecontext" >&2 
            echo "-----------------------------------------" >&2 

            # Print input variables before calling kubeaccess_precheck 
            echo "🔧 kubeaccess_precheck - Input Variables:" >&2 
            echo "  📛 Worker Name: $worker_name" >&2 
            echo "  🌐 Use Global Kubeconfig: $use_global_kubeconfig" >&2 
            echo "  🗂️  Global Kubeconfig: $GLOBAL_KUBECONFIG" >&2 
            echo "  🌐 Global Kubecontext: $GLOBAL_KUBECONTEXT" >&2 
            echo "  🗂️  Component Kubeconfig: $kubeconfig" >&2 
            echo "  🌐 Component Kubecontext: $kubecontext" >&2 
            echo "-----------------------------------------" >&2 

            # Call the kubeaccess_precheck function and capture output
            read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
                "$worker_name" \
                "$use_global_kubeconfig" \
                "$GLOBAL_KUBECONFIG" \
                "$GLOBAL_KUBECONTEXT" \
                "$kubeconfig" \
                "$kubecontext")

            # Print output variables after calling kubeaccess_precheck
            echo "🔧 kubeaccess_precheck - Output Variables:" >&2  
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path" >&2 
            echo "  🌐 Kubecontext: $kubecontext" >&2 
            echo "-----------------------------------------" >&2 

            # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
            if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
                echo "🔍 Validating Kubecontext:" >&2 
                echo "  🗂️   Kubeconfig Path: $kubeconfig_path" >&2 
                echo "  🌐 Kubecontext: $kubecontext" >&2 

                validate_kubecontext "$kubeconfig_path" "$kubecontext"
            else
                echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2 
                echo "  🗂️   Kubeconfig Path: $kubeconfig_path" >&2  
                echo "  🌐 Kubecontext: $kubecontext" >&2 
                exit 1
            fi

            # Prepare the context argument if the context is available
            local context_arg=""
            if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
                context_arg="--context $kubecontext"
            fi

            echo "-----------------------------------------" >&2 
            echo "🔍 Validating access to the worker cluster '$worker_name' using kubeconfig '$kubeconfig_path'..." >&2 
            echo "🔧 Variables:" >&2 
            echo "  worker_name=$worker_name" >&2  
            echo "  skip_installation=$skip_installation" >&2 
            echo "  use_global_kubeconfig=$use_global_kubeconfig" >&2 
            echo "  kubeconfig=$kubeconfig_path" >&2 
            echo "  kubecontext=$kubecontext" >&2 
            echo "  context_arg=$context_arg" >&2 
            echo "  namespace=$namespace" >&2  
            echo "  release_name=$release_name" >&2 
            echo "  chart_name=$chart_name" >&2 
            echo "  repo_url=$repo_url" >&2 
            echo "  username=$username" >&2 
            echo "  password=$password" >&2  
            echo "-----------------------------------------" >&2 

            cluster_info=$(kubectl cluster-info --kubeconfig "$kubeconfig_path" $context_arg 2>&1)
            if [[ $? -ne 0 ]]; then
                echo "❌ Error: Unable to access the worker cluster '$worker_name' using kubeconfig '$kubeconfig_path'." >&2 
                echo "Details: $cluster_info" >&2 
                exit 1
            fi

            worker_cluster_endpoint=$(get_api_server_url "$kubeconfig_path" "$kubecontext")
            echo "✔️  Successfully accessed worker cluster '$worker_name'. Kubernetes endpoint: $worker_cluster_endpoint"  >&2 

            # Check for nodes labeled with 'kubeslice.io/node-type=gateway'
            echo "🔍 Checking for nodes labeled 'kubeslice.io/node-type=gateway' in worker cluster '$worker_name'..."  >&2 
            gateway_nodes=$(kubectl get nodes --kubeconfig $kubeconfig_path $context_arg -l kubeslice.io/node-type=gateway --no-headers -o custom-columns=NAME:.metadata.name)

            if [ -z "$gateway_nodes" ]; then
                echo "✔️  No nodes labeled with 'kubeslice.io/node-type=gateway' found."  >&2 
            else
                echo "🔧 Removing label 'kubeslice.io/node-type=gateway' from nodes in worker cluster '$worker_name'..."  >&2 
                for node in $gateway_nodes; do
                    kubectl label node "$node" kubeslice.io/node-type- --kubeconfig $kubeconfig_path $context_arg --overwrite
                    echo "✔️  Label removed from node '$node'."  >&2 
                done
                echo "✔️  All gateway labels removed successfully."  >&2 
            fi
            echo "-----------------------------------------"  >&2 
        else
            echo "⏩ Skipping validation for worker cluster '$worker_name' as installation is skipped."  >&2 
        fi
    done

    echo "✔️ Kubeslice pre-checks completed successfully."  >&2 
    echo ""
}

validate_paths() {
    echo "🚀 Validating paths..."  >&2 
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

    # Check if the manifests path exists and is valid if specified
    if [ -n "$MANIFESTS_PATH" ]; then
        if [ ! -d "$MANIFESTS_PATH" ]; then
            echo "❌ Error: MANIFESTS_PATH '$MANIFESTS_PATH' does not exist or is not a directory."
            error_found=true
        fi
    fi

    # Check kubeconfigs for manifests if MANIFESTS_PATH is specified
    if [ -n "$MANIFESTS_PATH" ]; then
        for manifest in "$MANIFESTS_PATH"/*.yaml; do
            if [ ! -f "$manifest" ]; then
                echo "❌ Error: Manifest '$manifest' does not exist or is not a file."
                error_found=true
            fi

        done
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

    # Extract the add_node_label setting
    ADD_NODE_LABEL=$(yq e '.add_node_label' "$yaml_file")
    if [ -z "$ADD_NODE_LABEL" ] || [ "$ADD_NODE_LABEL" = "null" ]; then
        ADD_NODE_LABEL="false" # Default to false if not specified
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

    # Extract global context usage flag
    USE_GLOBAL_CONTEXT=$(yq e '.use_global_context' "$yaml_file")
    if [ -z "$USE_GLOBAL_CONTEXT" ] || [ "$USE_GLOBAL_CONTEXT" = "null" ]; then
        USE_GLOBAL_CONTEXT="true" # Default to true if not specified
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

    # Extract global enable/disable flag for additional apps installation
    ENABLE_INSTALL_ADDITIONAL_APPS=$(yq e '.enable_install_additional_apps' "$yaml_file")
    if [ -z "$ENABLE_INSTALL_ADDITIONAL_APPS" ] || [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "null" ]; then
        ENABLE_INSTALL_ADDITIONAL_APPS="true" # Default to true if not specified
    fi

    # Extract values for additional applications
    ADDITIONAL_APPS_COUNT=$(yq e '.additional_apps | length' "$yaml_file")

    ADDITIONAL_APPS=()
    for ((i = 0; i < ADDITIONAL_APPS_COUNT; i++)); do
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

remove_helm_repo() {
    echo "🚀 Starting Helm repository removal..."
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

    # Check if repo exists and remove it
    if helm repo list | grep -q "$repo_name"; then
        echo "🔍 Helm repository '$repo_name' exists. Removing..."
        retry helm repo remove $repo_name || {
            echo "❌ Failed to remove Helm repo '$repo_name'. Exiting."
            exit 1
        }
        echo "✔️ Helm repository '$repo_name' removed successfully."
    else
        echo "⚠️  Helm repository '$repo_name' does not exist. Nothing to remove."
    fi

    echo "✔️ Helm repository removal complete."  >&2
}

delete_manifests_from_yaml() {
    local yaml_file=$1
    local base_path=$(yq e '.base_path' "$yaml_file")

    echo "🚀 Starting the application of Kubernetes manifests from YAML file: $yaml_file"  >&2
    echo "🔧 Global Variables:"  >&2
    echo "  🗂️  global_kubeconfig_path=$GLOBAL_KUBECONFIG"   >&2
    echo "  🌐  global_kubecontext= --context $GLOBAL_KUBECONTEXT"  >&2
    echo "  🗂️  base_path=$base_path"  >&2
    echo "  🗂️  installation_files_path=$INSTALLATION_FILES_PATH"  >&2
    echo "-----------------------------------------"  >&2

    # Check if the manifests section exists
    manifests_exist=$(yq e '.manifests' "$yaml_file")

    if [ "$manifests_exist" == "null" ]; then
        echo "⚠️  Warning: No 'manifests' section found in the YAML file. Skipping manifest application."  >&2
        return
    fi

    # Extract manifests from the YAML file
    manifests_length=$(yq e '.manifests | length' "$yaml_file")

    if [ "$manifests_length" -eq 0 ]; then
        echo "⚠️  Warning: 'manifests' section is defined, but no manifests found. Skipping manifest application."  >&2
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

        # Call the kubeaccess_precheck function and capture output
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "$appname" \
            "$use_global_kubeconfig" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$kubeconfig" \
            "$kubecontext")

        # Print output variables after calling kubeaccess_precheck
        echo "🔧 kubeaccess_precheck - Output Variables:"  >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path"  >&2
        echo "  🌐 Kubecontext: $kubecontext"  >&2
        echo "-----------------------------------------"  >&2

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:"  >&2
            echo "  🗂️ Kubeconfig Path: $kubeconfig_path"  >&2
            echo "  🌐 Kubecontext: $kubecontext"  >&2

            validate_kubecontext "$kubeconfig_path" "$kubecontext"
        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."  >&2
            echo "  🗂️ Kubeconfig Path: $kubeconfig_path"  >&2
            echo "  🌐 Kubecontext: $kubecontext"  >&2
            exit 1
        fi

        # Prepare the context argument if the context is available
        local context_arg=""
        if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            context_arg="--context $kubecontext"
        fi

        echo "🔧 App Variables for '$appname':"  >&2
        echo "  🗂️  base_manifest=$base_manifest"  >&2
        echo "  🗂️  overrides_yaml=$overrides_yaml"  >&2
        echo "  📄 inline_yaml=${inline_yaml:+Provided}"  >&2
        echo "  🌐 use_global_kubeconfig=$use_global_kubeconfig"  >&2
        echo "  🗂️  kubeconfig_path=$kubeconfig_path"  >&2
        echo "  🌐 kubecontext=$kubecontext"  >&2
        echo "  🚫 skip_installation=$skip_installation"  >&2
        echo "  🔍 verify_install=$verify_install"  >&2
        echo "  ⏰ verify_install_timeout=$verify_install_timeout"  >&2
        echo "  ❌ skip_on_verify_fail=$skip_on_verify_fail"  >&2
        echo "  🏷️ namespace=$namespace"  >&2
        echo "-----------------------------------------"  >&2

        # Handle HTTPS file URLs or local base manifest files
        if [ -n "$base_manifest" ] && [ "$base_manifest" != "null" ]; then
            if [[ "$base_manifest" =~ ^https:// ]]; then
                echo "🌐 Downloading manifest from URL: $base_manifest"
                temp_manifest="$INSTALLATION_FILES_PATH/${appname}_manifest.yaml"
                curl -sL "$base_manifest" -o "$temp_manifest"
                if [ $? -ne 0 ]; then
                    echo "❌ Error: Failed to download manifest from URL: $base_manifest"
                    return 1
                fi
            else
                base_manifest="$base_path/$base_manifest"
                temp_manifest="$INSTALLATION_FILES_PATH/${appname}_manifest.yaml"
                cp "$base_manifest" "$temp_manifest"
            fi
        else
            # If no base manifest, start with inline YAML if provided
            if [ -n "$inline_yaml" ] && [ "$inline_yaml" != "null" ]; then
                echo "📄 Using inline YAML as the base manifest for $appname"  >&2
                temp_manifest="$INSTALLATION_FILES_PATH/${appname}_manifest.yaml"
                echo "$inline_yaml" >"$temp_manifest"
            else
                echo "❌ Error: Neither base manifest nor inline YAML provided for app: $appname"  >&2
                return 1
            fi
        fi

        # Convert overrides_yaml to absolute paths
        if [ -n "$overrides_yaml" ] && [ "$overrides_yaml" != "null" ]; then
            overrides_yaml="$base_path/$overrides_yaml"
        fi

        # Merge inline YAML with the base manifest if provided
        if [ -n "$inline_yaml" ] && [ "$inline_yaml" != "null" ] && [ -f "$temp_manifest" ]; then
            echo "🔄 Merging inline YAML for $appname into the base manifest"  >&2
            echo "$inline_yaml" | yq eval-all 'select(filename == "'"$temp_manifest"'") * select(filename == "-")' - "$temp_manifest" >"${temp_manifest}_merged"
            mv "${temp_manifest}_merged" "$temp_manifest"
        fi

        # Merge overrides if provided
        if [ -f "$overrides_yaml" ]; then
            echo "🔄 Merging overrides from $overrides_yaml into $temp_manifest"
            yq eval-all 'select(filename == "'"$temp_manifest"'") * select(filename == "'"$overrides_yaml"'")' "$temp_manifest" "$overrides_yaml" >"${temp_manifest}_merged"
            mv "${temp_manifest}_merged" "$temp_manifest"
        else
            echo "⚠️  No overrides YAML file found for app: $appname. Proceeding with base/inline manifest."  >&2
        fi

        echo "📄 Deleting manifest for app: $appname in namespace: ${namespace}"  >&2
        kubectl delete -f "$temp_manifest" --namespace "${namespace}" --kubeconfig "$kubeconfig_path" $context_arg
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to delete manifest for app: $appname"  >&2
            return 1
        fi
        echo "✔️ Successfully deleted manifest for app: $appname"  >&2

        # Clean up the temporary manifest file
        rm -f "$temp_manifest"
    done

    echo "✅ All applicable manifests deleted successfully."  >&2
    echo "-----------------------------------------"  >&2
}

# Function to fetch and display summary information
display_summary() {
    echo "========================================="
    echo "           📋 Summary - Uninstallations  "
    echo "========================================="

    # Summary of all Helm chart uninstallations (including controller, UI, workers, and additional apps)
    echo "🛠️ **Application Uninstallations Summary**:"  >&2

    # Helper function to check Helm release status, ensure it is removed, and show resources
    check_helm_release_uninstalled() {
        local release_name=$1
        local namespace=$2
        local kubeconfig=$3
        local kubecontext=$4

        echo "-----------------------------------------"  >&2
        echo "🚀 **Helm Release: $release_name**"  >&2
        if helm status "$release_name" --namespace "$namespace" --kubeconfig "$kubeconfig" --kube-context "$kubecontext" >/dev/null 2>&1; then
            echo "⚠️ Warning: Release '$release_name' in namespace '$namespace' still exists. It was not successfully uninstalled."  >&2
        else
            echo "✔️ Release '$release_name' in namespace '$namespace' has been successfully uninstalled."  >&2
            # Display resources in the namespace after uninstallation
            echo "📋 Resources in namespace '$namespace' after uninstallation:"  >&2
            kubectl get all --namespace "$namespace" --kubeconfig "$kubeconfig" --context "$kubecontext"
        fi
        echo "-----------------------------------------"  >&2
    }

    # Kubeslice Controller Uninstallation
    if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ] && [ "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" = "false" ]; then
        check_helm_release_uninstalled "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT"
    else
        echo "⏩ **Kubeslice Controller** uninstallation was skipped or disabled."  >&2
    fi

    # Worker Cluster Uninstallations
    if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
        for ((i = 0; i < ${#KUBESLICE_WORKERS[@]}; i++)); do
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
                check_helm_release_uninstalled "$release_name" "$namespace" "$kubeconfig" "$kubecontext"
            else
                echo "⏩ **Worker Cluster '$worker_name'** uninstallation was skipped."  >&2
            fi
        done
    else
        echo "⏩ **Worker uninstallation was skipped or disabled.**"  >&2
    fi

    # Additional Application Uninstallations
    if [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "true" ]; then
        for ((i = 0; i < ${#ADDITIONAL_APPS[@]}; i++)); do
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
                check_helm_release_uninstalled "$release_name" "$namespace" "$kubeconfig" "$kubecontext"
            else
                echo "⏩ **Additional Application '$app_name'** uninstallation was skipped."  >&2
            fi
        done
    else
        echo "⏩ **Additional application uninstallation was skipped or disabled.**"  >&2 
    fi

    echo "========================================="
    echo "          🏁 Summary Output Complete      "
    echo "========================================="
}

uninstall_helm_chart_and_cleanup() {
    local skip_uninstallation=$1
    local release_name=$2
    local namespace=$3
    local specific_use_global_kubeconfig=$4
    local specific_kubeconfig_path=$5
    local specific_kubecontext=$6
    local verify_uninstall=$7
    local verify_uninstall_timeout=${8:-300}
    local skip_on_verify_fail=${9:-false}

    echo "-----------------------------------------" >&2
    echo "🚀 Processing Helm chart uninstallation" >&2
    echo "Release Name: $release_name" >&2
    echo "Namespace: $namespace" >&2
    echo "Skip Uninstallation: $skip_uninstallation" >&2
    echo "Specific Use Global Kubeconfig: $specific_use_global_kubeconfig" >&2
    echo "Specific Kubeconfig Path: $specific_kubeconfig_path" >&2
    echo "Specific Kubecontext: $specific_kubecontext" >&2
    echo "Verify Uninstall: $verify_uninstall" >&2
    echo "Verify Uninstall Timeout: $verify_uninstall_timeout" >&2
    echo "Skip on Verify Fail: $skip_on_verify_fail" >&2
    echo "-----------------------------------------" >&2

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
    echo "🔧 kubeaccess_precheck - Output Variables: $release_name" >&2
    echo "  🗂️   Kubeconfig Path: $kubeconfig_path" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "-----------------------------------------" >&2

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:" >&2
        echo "  🗂️   Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2
        exit 1
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--kube-context $kubecontext"
    fi
    echo "Context Argument: $context_arg" >&2

    if [ "$skip_uninstallation" = "true" ]; then
        echo "⏩ Skipping uninstallation of Helm chart '$release_name' in namespace '$namespace' as per configuration." >&2
        return
    fi

    helm_cmd="helm --namespace $namespace --kubeconfig $kubeconfig_path"
    echo "Helm Command Base: $helm_cmd" >&2

    uninstall_helm_chart() {
        echo "Executing: helm uninstall $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg" >&2
        helm uninstall $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg
    }

delete_kubernetes_objects() {
    echo "🚨 Deleting all Kubernetes objects in namespace '$namespace'" >&2
    kubectl delete all --all --namespace "$namespace" --kubeconfig "$kubeconfig_path" --context $kubecontext --force --grace-period=0
    kubectl delete configmap --all --namespace "$namespace" --kubeconfig "$kubeconfig_path" --context $kubecontext --force --grace-period=0
    kubectl delete secret --all --namespace "$namespace" --kubeconfig "$kubeconfig_path" --context $kubecontext --force --grace-period=0
    kubectl delete serviceaccount --all --namespace "$namespace" --kubeconfig "$kubeconfig_path" --context $kubecontext --force --grace-period=0
}


    if helm status $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
        echo "🔄 Helm release '$release_name' found. Preparing to uninstall..." >&2
        uninstall_helm_chart

        if [ "$verify_uninstall" = "true" ]; then
            echo "🔍 Verifying uninstallation of Helm release '$release_name'..." >&2
            end_time=$((SECONDS + verify_uninstall_timeout))
            while [ $SECONDS -lt $end_time ]; do
                if helm status $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
                    echo "⏳ Waiting for Helm release '$release_name' to be fully uninstalled..." >&2
                    sleep 5
                else
                    echo "✔️ Helm release '$release_name' has been successfully uninstalled." >&2
                    break
                fi
            done

            if helm status $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
                echo "❌ Error: Helm release '$release_name' was not fully uninstalled. Deleting all resources manually..." >&2
                #delete_kubernetes_objects
                echo "🔄 Retrying Helm uninstallation..." >&2
                uninstall_helm_chart
                if helm status $release_name --namespace $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
                    if [ "$skip_on_verify_fail" = "true" ]; then
                        echo "⚠️ Warning: Helm release '$release_name' was not fully uninstalled after retry, but skipping as per configuration." >&2
                    else
                        echo "❌ Error: Helm release '$release_name' failed to uninstall even after retrying. Manual intervention may be required." >&2
                        return 1
                    fi
                else
                    echo "✔️ Helm release '$release_name' has been successfully uninstalled after manual cleanup." >&2
                fi
            fi
        else
            echo "✔️ Helm release '$release_name' has been uninstalled (unverified)." >&2
        fi
    else
        echo "⚠️ Warning: Helm release '$release_name' not found in namespace '$namespace'." >&2
    fi

    echo "-----------------------------------------" >&2
    echo "✔️ Completed uninstallation and cleanup for release: $release_name" >&2
    echo "-----------------------------------------" >&2
}

unregister_clusters_in_controller() {
    echo "🚀 Starting cluster unregistration in controller cluster..." >&2
    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Project Deletion" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Project Creation " >&2
    echo "  🗂️    Kubeconfig Path: $kubeconfig_path" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "-----------------------------------------" >&2

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:" >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2
        exit 1
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:" >&2
    echo "  kubeconfig_path=$kubeconfig_path" >&2
    echo "  context_arg=$context_arg" >&2
    echo "  namespace=$namespace" >&2
    echo "-----------------------------------------" >&2


    for registration in "${KUBESLICE_CLUSTER_REGISTRATIONS[@]}"; do
        IFS="|" read -r cluster_name project_name telemetry_enabled telemetry_endpoint telemetry_provider geo_location_provider geo_location_region <<<"$registration"

        echo "-----------------------------------------" >&2
        echo "🚀 Unregistering cluster '$cluster_name' from project '$project_name' within namespace '$namespace'" >&2
        echo "-----------------------------------------" >&2

        kubectl delete cluster.controller.kubeslice.io "$cluster_name" --kubeconfig $kubeconfig_path $context_arg -n kubeslice-$project_name
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to unregister cluster '$cluster_name' from project '$project_name'." >&2
            return 1
        fi

        echo "🔍 Verifying cluster unregistration for '$cluster_name'..." >&2
        if kubectl get cluster.controller.kubeslice.io "$cluster_name" -n kubeslice-$project_name --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
            echo "❌ Error: Cluster '$cluster_name' still exists in project '$project_name'." >&2
            return 1
        else
            echo "✔️  Cluster '$cluster_name' unregistered successfully from project '$project_name'." >&2
        fi

        echo "-----------------------------------------" >&2
    done
    echo "✔️ Cluster unregistration in controller cluster complete." >&2
}




delete_projects_in_controller() {

    local retry_interval=120 # Default wait time of 1 minute between retries
    local max_retries=5      # Maximum number of retries
    echo "🚀 Starting project deletion in controller cluster..." >&2
    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Project Deletion" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Project Creation " >&2
    echo "  🗂️    Kubeconfig Path: $kubeconfig_path" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "-----------------------------------------" >&2

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:" >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2
        exit 1
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:" >&2
    echo "  kubeconfig_path=$kubeconfig_path" >&2
    echo "  context_arg=$context_arg" >&2
    echo "  namespace=$namespace" >&2
    echo "-----------------------------------------" >&2

    for project in "${KUBESLICE_PROJECTS[@]}"; do
        IFS="|" read -r project_name project_username <<<"$project"

        echo "-----------------------------------------" >&2
        echo "🚀 Deleting project '$project_name' in namespace '$namespace'" >&2
        echo "-----------------------------------------" >&2

        # Retry loop for deletion
        for ((i = 1; i <= max_retries; i++)); do
            kubectl delete project.controller.kubeslice.io "$project_name" --kubeconfig $kubeconfig_path $context_arg -n $namespace
            if [ $? -eq 0 ]; then
                break
            elif [ $i -lt $max_retries ]; then
                echo "⚠️  Warning: Failed to delete project '$project_name' in namespace '$namespace'. Retrying in $retry_delay seconds... ($i/$max_retries)" >&2
                sleep $retry_delay
            else
                echo "❌ Error: Failed to delete project '$project_name' in namespace '$namespace' after $max_retries attempts." >&2
                return 1
            fi
        done

        echo "🔍 Verifying project '$project_name' deletion..."  >&2
        if kubectl get project.controller.kubeslice.io "$project_name" -n $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
            echo "❌ Error: Project '$project_name' still exists in namespace '$namespace'." >&2
            return 1
        else
            echo "✔️  Project '$project_name' deleted successfully in namespace '$namespace'." >&2
        fi

        echo "-----------------------------------------" >&2
    done
    echo "✔️ Project deletion in controller cluster complete." >&2
}

delete_slices_in_controller() {
    echo "🚀 Starting project deletion in controller cluster..."
    local kubeconfig_path="$KUBESLICE_CONTROLLER_KUBECONFIG"
    local context_arg=""
    local retry_interval=120 # Default wait time of 1 minute between retries
    local max_retries=5      # Maximum number of retries

    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Project Deletion" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Project Creation "  >&2
    echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "-----------------------------------------" >&2

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:" >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2
        exit 1
    fi
    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    for project in "${KUBESLICE_PROJECTS[@]}"; do
        IFS="|" read -r project_name project_username <<<"$project"

        echo "-----------------------------------------" >&2
        echo "🚀 Deleting all slices in '$project_name' in namespace 'kubeslice-$project_name'" >&2
        echo "-----------------------------------------" >&2

        kubectl get sliceconfig.controller.kubeslice.io --kubeconfig $kubeconfig_path $context_arg -n "kubeslice-$project_name" -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | while read namespace name; do
            retry_count=0
            success=false
            until [ $retry_count -ge $max_retries ]; do
                # Patch the SliceConfig to remove the specific entry
                kubectl patch sliceconfig.controller.kubeslice.io --kubeconfig $kubeconfig_path $context_arg $name -n $namespace --type=json -p='[
                    {
                        "op": "remove",
                        "path": "/spec/namespaceIsolationProfile/applicationNamespaces/0"
                    }
                ]'
                patch_status=$?

                if [ $patch_status -eq 0 ]; then
                    echo "✅ Successfully patched SliceConfig '$name'. Proceeding with deletion." >&2
                elif [ $patch_status -ne 0 ]; then
                    echo "⚠️  Nothing to patch or patch failed. Proceeding with deletion." >&2  
                fi

                # Attempt to delete the SliceConfig after patching
                kubectl delete sliceconfig.controller.kubeslice.io $name -n $namespace --kubeconfig $kubeconfig_path $context_arg
                if [ $? -eq 0 ]; then
                    success=true
                    break
                fi

                echo "⚠️  Retrying deletion of SliceConfig '$name' in namespace '$namespace' ($((retry_count + 1))/$max_retries)..." >&2
                retry_count=$((retry_count + 1))
                sleep $retry_interval
            done

            if [ "$success" = false ]; then
                echo "❌ Error: Failed to delete SliceConfig '$name' in namespace '$namespace' after $max_retries attempts." >&2
                exit 1
            fi
        done

        echo "🔍 Verifying sliceconfig in 'kubeslice-$project_name' deletion..." >&2
        if kubectl get sliceconfig.controller.kubeslice.io --all -n "kubeslice-$project_name" --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
            echo "❌ Error: sliceconfig in '$project_name' still exists in namespace kubeslice-$project_name." >&2
            exit 1
        else
            echo "✔️  sliceconfig in '$project_name' deleted successfully in namespace kubeslice-$project_name." >&2
        fi

        echo "-----------------------------------------" >&2
    done
    echo "✔️ slice config in kubeslice-$project_name deletion in controller cluster complete." >&2
}

delete_projects_in_controller() {
    echo "🚀 Starting project deletion in controller cluster..."  >&2
    local kubeconfig_path="$KUBESLICE_CONTROLLER_KUBECONFIG"
    local context_arg=""
    local max_retries=3 # Number of retries
    local retry_delay=5 # Delay between retries in seconds

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "Kubeslice Controller Cluster Registration" \
        "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$KUBESLICE_CONTROLLER_KUBECONFIG" \
        "$KUBESLICE_CONTROLLER_KUBECONTEXT")

    # Print output variables after calling kubeaccess_precheck
    echo "🔧 kubeaccess_precheck - Output Variables: Kubeslice Controller Cluster Registration " >&2
    echo "  🗂️     Kubeconfig Path: $kubeconfig_path" >&2
    echo "  🌐 Kubecontext: $kubecontext" >&2
    echo "-----------------------------------------" >&2

    # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
    if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
        echo "🔍 Validating Kubecontext:" >&2
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2

        validate_kubecontext "$kubeconfig_path" "$kubecontext"
    else
        echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null." >&2
        echo "  🗂️     Kubeconfig Path: $kubeconfig_path" >&2
        echo "  🌐 Kubecontext: $kubecontext" >&2
        exit 1 
    fi

    local context_arg=""
    if [ -n "$kubecontext" ] && [ "$kubecontext" != "null" ]; then
        context_arg="--context $kubecontext"
    fi

    local namespace="$KUBESLICE_CONTROLLER_NAMESPACE"

    echo "🔧 Variables:" >&2 
    echo "  kubeconfig_path=$kubeconfig_path" >&2
    echo "  context_arg=$context_arg" >&2
    echo "  namespace=$namespace" >&2
    echo "-----------------------------------------"

    for project in "${KUBESLICE_PROJECTS[@]}"; do
        IFS="|" read -r project_name project_username <<<"$project"

        echo "-----------------------------------------" >&2
        echo "🚀 Deleting project '$project_name' in namespace '$namespace'" >&2
        echo "-----------------------------------------" >&2

        # Retry loop for deletion
        for ((i = 1; i <= max_retries; i++)); do
            kubectl delete project.controller.kubeslice.io "$project_name" --kubeconfig $kubeconfig_path $context_arg -n $namespace
            if [ $? -eq 0 ]; then
                break
            elif kubectl get project.controller.kubeslice.io "$project_name" -n $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
                if [ $i -lt $max_retries ]; then
                    echo "⚠️  Warning: Failed to delete project '$project_name' in namespace '$namespace'. Retrying in $retry_delay seconds... ($i/$max_retries)" >&2
                    sleep $retry_delay
                else
                    echo "❌ Error: Failed to delete project '$project_name' in namespace '$namespace' after $max_retries attempts." >&2 
                    return 1
                fi
            else
                echo "⚠️  Warning: Project '$project_name' not found in namespace '$namespace'. Proceeding to the next project." >&2
                break
            fi
        done

        echo "🔍 Verifying project '$project_name' deletion..." >&2
        if kubectl get project.controller.kubeslice.io "$project_name" -n $namespace --kubeconfig $kubeconfig_path $context_arg >/dev/null 2>&1; then
            echo "❌ Error: Project '$project_name' still exists in namespace '$namespace'."
            return 1
        else
            echo "✔️  Project '$project_name' deleted successfully or was not found in namespace '$namespace'." >&2
        fi
        echo "✔️ deletion of all objects Project '$project_name' starting." >&2
        api_groups=("gpr.kubeslice.io" "inventory.kubeslice.io" "controller.kubeslice.io" "worker.kubeslice.io" "aiops.kubeslice.io" "networking.kubeslice.io")
        webhooks=("gpr-validating-webhook-configuration" "kubeslice-controller-validating-webhook-configuration")
        continue_on_error cleanup_resources_and_webhooks "kubeslice-$project_name" "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" "$kubeconfig_path" "$kubecontext" "${api_groups[@]}" --webhooks "${webhooks[@]}"
        echo "✔️ deletion of all objects Project '$project_name' completed." >&2
        echo "-----------------------------------------"
    done
    echo "✔️ Project deletion in controller cluster complete." >&2
}

########################## EGS ALL Clear ##################################################

list_resources_in_group() {
    local namespace=$1
    local api_group=$2
    local specific_use_global_kubeconfig=$3
    local specific_kubeconfig_path=$4
    local specific_kubecontext=$5
    local resources=()  # Array to store resources

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "list_resources_in_group" \
        "$specific_use_global_kubeconfig" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$specific_kubeconfig_path" \
        "$specific_kubecontext")

    # Collect resource kinds in the API group
    resource_kinds=$(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext" api-resources --verbs=list --namespaced -o name | grep "$api_group")

    # Collect all resources of these kinds in the namespace
    for resource in $resource_kinds; do
        mapfile -t temp_resources < <(kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext" -n "$namespace" get "$resource" -o name 2>/dev/null)
        resources+=("${temp_resources[@]}")
    done

    # Final output: Only resource names
    printf "%s\n" "${resources[@]}"
}
# Function to delete a namespace
delete_namespace() {
    local namespace=$1
    local specific_use_global_kubeconfig=$2
    local specific_kubeconfig_path=$3
    local specific_kubecontext=$4


 # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "deleteing namespace" \
        "$specific_use_global_kubeconfig" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$specific_kubeconfig_path" \
        "$specific_kubecontext")
    

    # Attempt to delete the namespace
    echo "Attempting to delete namespace: $namespace"
    kubectl --kubeconfig "$kubeconfig_path" --context $kubecontext delete namespace "$namespace" --wait=false

    # Wait for a few seconds and check if the namespace is in terminating state
    sleep 5
    if kubectl --kubeconfig "$kubeconfig_path" --context $kubecontext get namespace "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Terminating"; then
        echo "Namespace $namespace is in a terminating state. Proceeding with force deletion."

        # Remove the finalizer
        kubectl --kubeconfig "$kubeconfig_path" --context $kubecontext get namespace "$namespace" -o json \
            | jq '.spec.finalizers = []' \
            | kubectl --kubeconfig "$kubeconfig_path" --context $kubecontext replace --raw "/api/v1/namespaces/$namespace/finalize" -f -

        echo "Namespace $namespace has been forcefully deleted."
    else
        echo "Namespace $namespace deleted successfully."
    fi
}
# Function to remove finalizers from a resource
remove_finalizers() {
    local namespace=$1
    local resource=$2
    local kubeconfig_path=$3
    local kubecontext=$4

    echo "🗑 Processing resource: $resource in namespace: $namespace" >&2

    # Fetch the resource YAML and remove unwanted fields
    kubectl --kubeconfig "$kubeconfig_path" --context $kubecontext -n "$namespace" get "$resource" -o json > ./resource.json
    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to fetch resource: $resource" >&2
        return
    fi

    # Remove the finalizers and clean up unnecessary metadata
    jq 'del(.metadata.finalizers[]? | select(. == "inventory.kubeslice.io/hubspoke-gpunodeinventory-finalizer")) |
        del(.metadata.ownerReferences) |
        del(.metadata.managedFields)' ./resource.json > ./patched-resource.json

    # Apply the patched resource
    kubectl --kubeconfig "$kubeconfig_path" --context $kubecontext -n "$namespace" replace -f ./patched-resource.json
    if [[ $? -eq 0 ]]; then
        echo "✅ Finalizers removed from $resource" >&2
    else
        echo "❌ Failed to remove finalizers from $resource" >&2
    fi

    # Clean up temporary files
    rm -f ./resource.json ./patched-resource.json
}

# Function to delete validating webhook configurations
delete_validating_webhooks() {
    local kubeconfig_path=$1
    local kubecontext=$2
    shift 2  # Remove the first two arguments
    local webhooks=("$@")

    # Sanity check: Ensure at least one webhook name is provided
    if [[ ${#webhooks[@]} -eq 0 ]]; then
        echo "⚠️  No validating webhook configurations specified for deletion." >&2
        return 1
    fi

    for webhook in "${webhooks[@]}"; do
        # Skip invalid inputs (paths or context names mistakenly passed as webhooks)
        if [[ $webhook == */* || $webhook == *context* || $webhook == *kubeconfig* ]]; then
            echo "⚠️  Skipping invalid webhook name: '$webhook'" >&2
            continue
        fi

        # Delete the webhook and handle errors
        kubectl --kubeconfig "$kubeconfig_path" --context "$kubecontext" delete validatingwebhookconfiguration "$webhook" --ignore-not-found > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "✅ Validating webhook configuration '$webhook' removed." >&2
        else
            echo "❌ Failed to remove validating webhook configuration '$webhook'." >&2
        fi
    done
}

# Main function to process all API groups and validating webhooks
cleanup_resources_and_webhooks() {
    local namespace=$1
    local specific_use_global_kubeconfig=$2
    local specific_kubeconfig_path=$3
    local specific_kubecontext=$4

    # Shift the first 4 arguments to process the remaining ones
    shift 4

    # Split remaining arguments into API groups and webhooks
    local api_groups=()
    local webhooks=()
    local is_webhook_section=false

    for arg in "$@"; do
        if [[ "$arg" == "--webhooks" ]]; then
            is_webhook_section=true
            continue
        fi

        if [[ "$is_webhook_section" == true ]]; then
            webhooks+=("$arg")
        else
            api_groups+=("$arg")
        fi
    done

    # Use kubeaccess_precheck to determine kubeconfig path and context
    read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
        "clean_up_resources_and_webhooks" \
        "$specific_use_global_kubeconfig" \
        "$GLOBAL_KUBECONFIG" \
        "$GLOBAL_KUBECONTEXT" \
        "$specific_kubeconfig_path" \
        "$specific_kubecontext")

    echo "🛠 Cleaning up namespace: $namespace" >&2
    for api_group in "${api_groups[@]}"; do
        echo "🔍 Processing API group: $api_group" >&2
        resources=$(list_resources_in_group "$namespace" "$api_group" "$specific_use_global_kubeconfig" "$kubeconfig_path" "$kubecontext")

        if [[ -z "$resources" ]]; then
            echo "⚠️  No resources found in API group: $api_group" >&2
            continue
        fi

        echo "The following resources will be cleaned up:" >&2
        echo "$resources" >&2

        # Process each resource
        echo "$resources" | while read -r resource; do
            remove_finalizers "$namespace" "$resource" "$kubeconfig_path" "$kubecontext"
        done
    done

    # Delete webhooks
    if [[ ${#webhooks[@]} -gt 0 ]]; then
        echo "🧹 Deleting validating webhooks..." >&2
        delete_validating_webhooks "$kubeconfig_path" "$kubecontext" "${webhooks[@]}"
    fi

    echo "🎉 Cleanup completed for namespace: $namespace" >&2
}



############################### EGS ALL Clear ########################################################################



# Parse command-line arguments for options
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --input-yaml)
        EGS_INPUT_YAML="$2"
        shift
        ;;
    --help)
        echo "Usage: $0 --input-yaml <yaml_file>"  >&2
        exit 0
        ;;
    *)
        echo "Unknown parameter passed: $1"  >&2
        echo "Use --help for usage information."  >&2 
        exit 1
        ;;
    esac
    shift
done

# Validation for input-yaml flag
if [ -z "$EGS_INPUT_YAML" ]; then
    echo "❌ Error: --input-yaml flag is required."  >&2
    echo "Use --help for usage information."  >&2
    exit 1
fi

# If an input YAML file is provided, parse it
if [ -n "$EGS_INPUT_YAML" ]; then
    # Run prerequisite checks if precheck is enabled
    prerequisite_check
    if command -v yq &>/dev/null; then
        parse_yaml "$EGS_INPUT_YAML"
        echo " calling validate_paths..."  >&2 
        validate_paths
    else
        echo "❌ yq command not found. Please install yq to use the --input-yaml option."  >&2
        exit 1
    fi
fi

# # Run Kubeslice pre-checks if enabled
# if [ "$KUBESLICE_PRECHECK" = "true" ]; then
#     continue_on_error kubeslice_uninstall_pre_check
# fi

# Check if the enable_custom_apps flag is defined and set to true
enable_custom_apps=$(yq e '.enable_custom_apps // "false"' "$EGS_INPUT_YAML")

if [ "$enable_custom_apps" = "true" ]; then
    echo "🚀 Custom apps are enabled. Iterating over manifests and applying them..."  >&2

    # Check if the manifests section is defined
    manifests_exist=$(yq e '.manifests // "null"' "$EGS_INPUT_YAML")

    if [ "$manifests_exist" = "null" ]; then
        echo "⚠️  No 'manifests' section found in the YAML file. Skipping manifest application."  >&2 
    else
        manifests_length=$(yq e '.manifests | length' "$EGS_INPUT_YAML")

        if [ "$manifests_length" -eq 0 ]; then
            echo "⚠️  'manifests' section is defined but contains no entries. Skipping manifest application."  >&2
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
                yq e ".manifests = [ .manifests[$index] ]" "$EGS_INPUT_YAML" >"$temp_yaml"

                # Call apply_manifests_from_yaml function for each manifest
                continue_on_error delete_manifests_from_yaml "$temp_yaml"

                # Clean up temporary YAML file
                rm -f "$temp_yaml"
            done
        fi
    fi
else
    echo "⏩ Custom apps are disabled or not defined. Skipping manifest application."  >&2 
fi

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
        kubeconfig=$(echo "$app" | yq e '.kubeconfig' -)
        kubecontext=$(echo "$app" | yq e '.kubecontext' -)
        
        continue_on_error uninstall_helm_chart_and_cleanup "$skip_installation" "$release_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"
        continue_on_error delete_kubernetes_objects
        continue_on_error delete_namespace "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext"

    done
    echo "✔️ Installation of additional applications complete."  >&2
else
    echo "⏩ Skipping installation of additional applications as ENABLE_INSTALL_ADDITIONAL_APPS is set to false."  >&2
fi

#Delete Slice
continue_on_error delete_slices_in_controller

# UnRegister clusters in the controller cluster after projects have been created
if [ "$ENABLE_CLUSTER_REGISTRATION" = "true" ]; then
    continue_on_error unregister_clusters_in_controller
fi

# Inside the loop where you process each worker
if [ "$ENABLE_INSTALL_WORKER" = "true" ]; then
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
        verify_uninstall_timeout=$(echo "$worker" | yq e '.verify_install_timeout' -)
        skip_on_verify_fail=$(echo "$worker" | yq e '.skip_on_verify_fail' -)
        version=$(echo "$worker" | yq e '.version' -)
        specific_use_local_charts=$(echo "$worker" | yq e '.specific_use_local_charts' -)
        kubeconfig=$(echo "$worker" | yq e '.kubeconfig' -)
        kubecontext=$(echo "$worker" | yq e '.kubecontext' -)

        # Now call the install_or_upgrade_helm_chart function in a similar fashion to the controller
        continue_on_error uninstall_helm_chart_and_cleanup "$skip_installation" "$release_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"
        api_groups=("gpr.kubeslice.io" "inventory.kubeslice.io" "controller.kubeslice.io" "worker.kubeslice.io" "aiops.kubeslice.io" "networking.kubeslice.io")
        webhooks=("gpr-validating-webhook-configuration" "kubeslice-controller-validating-webhook-configuration")
        continue_on_error cleanup_resources_and_webhooks "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "${api_groups[@]}" --webhooks "${webhooks[@]}"
        continue_on_error delete_kubernetes_objects
        continue_on_error delete_namespace "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext"
    done
fi

# Delete projects in the controller cluster before deploying workers
if [ "$ENABLE_PROJECT_CREATION" = "true" ]; then
    continue_on_error delete_projects_in_controller
fi


# Process kubeslice-controller uninstallation if enabled
if [ "$ENABLE_INSTALL_CONTROLLER" = "true" ]; then
    continue_on_error uninstall_helm_chart_and_cleanup "$KUBESLICE_CONTROLLER_SKIP_INSTALLATION" "$KUBESLICE_CONTROLLER_RELEASE_NAME" "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL" "$KUBESLICE_CONTROLLER_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_CONTROLLER_SKIP_ON_VERIFY_FAIL"
    api_groups=("gpr.kubeslice.io" "inventory.kubeslice.io" "controller.kubeslice.io" "worker.kubeslice.io" "aiops.kubeslice.io" "networking.kubeslice.io")
    webhooks=("gpr-validating-webhook-configuration" "kubeslice-controller-validating-webhook-configuration")
    continue_on_error cleanup_resources_and_webhooks "$KUBESLICE_CONTROLLER_NAMESPACE" "$KUBESLICE_CONTROLLER_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONFIG" "$KUBESLICE_CONTROLLER_KUBECONTEXT" "${api_groups[@]}" --webhooks "${webhooks[@]}"
fi

# Process kubeslice-ui uninstallation if enabled
if [ "$ENABLE_INSTALL_UI" = "true" ]; then
    continue_on_error uninstall_helm_chart_and_cleanup "$KUBESLICE_UI_SKIP_INSTALLATION" "$KUBESLICE_UI_RELEASE_NAME" "$KUBESLICE_UI_NAMESPACE" "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_UI_KUBECONFIG" "$KUBESLICE_UI_KUBECONTEXT" "$KUBESLICE_UI_VERIFY_INSTALL" "$KUBESLICE_UI_VERIFY_INSTALL_TIMEOUT" "$KUBESLICE_UI_SKIP_ON_VERIFY_FAIL"
    namespace="$KUBESLICE_UI_NAMESPACE"
    continue_on_error delete_kubernetes_objects
    continue_on_error delete_namespace "$KUBESLICE_UI_NAMESPACE" "$KUBESLICE_UI_USE_GLOBAL_KUBECONFIG" "$KUBESLICE_UI_KUBECONFIG" "$KUBESLICE_UI_KUBECONTEXT"
fi



trap display_summary EXIT

echo "========================================="
echo "    EGS UnInstaller Script Complete        "
echo "========================================="

echo "=====================================EGS UnInstaller Script execution completed at: $(date)===================================" >> "$output_file"
