#!/bin/bash

# Define the script version
SCRIPT_VERSION="1.14.3"

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
output_file="egs-install-prerequisites-output.log"
exec > >(tee -a "$output_file") 2>&1

echo "=====================================EGS Install Prerequisites Script execution started at: $(date)===================================" >> "$output_file"

# Exit immediately if a command exits with a non-zero status
set -e

# Print introductory statement
echo "====================================================="
echo "           EGS Install Prerequisites Script          "
echo "====================================================="
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

    echo " BASE_PATH=$BASE_PATH"
    echo " LOCAL_CHARTS_PATH=$LOCAL_CHARTS_PATH"

    # Global enable/disable flags for different stages


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
        return # Return empty array
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
    local base_path=$(yq e '.base_path' "$yaml_file")

    echo "🚀 Starting the application of Kubernetes manifests from YAML file: $yaml_file"
    echo "🔧 Global Variables:"
    echo "  🗂️  global_kubeconfig_path=$GLOBAL_KUBECONFIG"
    echo "  🌐  global_kubecontext= --context $GLOBAL_KUBECONTEXT"
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

        # Call the kubeaccess_precheck function and capture output
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "$appname" \
            "$use_global_kubeconfig" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$kubeconfig" \
            "$kubecontext")

        # Print output variables after calling kubeaccess_precheck
        echo "🔧 kubeaccess_precheck - Output Variables:"
        echo "  🗂️ Kubeconfig Path: $kubeconfig_path"
        echo "  🌐 Kubecontext: $kubecontext"
        echo "-----------------------------------------"

        # Validate the kubecontext if both kubeconfig_path and kubecontext are set and not null
        if [[ -n "$kubeconfig_path" && "$kubeconfig_path" != "null" && -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            echo "🔍 Validating Kubecontext:"
            echo "  🗂️ Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"

            validate_kubecontext "$kubeconfig_path" "$kubecontext"

        else
            echo "⚠️ Warning: Either kubeconfig_path or kubecontext is not set or is null."
            echo "  🗂️ Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"
            exit 1
        fi

        # Prepare the context argument if the context is available
        local context_arg=""
        if [[ -n "$kubecontext" && "$kubecontext" != "null" ]]; then
            context_arg="--context $kubecontext"
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
        echo "  🏷️ namespace=$namespace"
        echo "-----------------------------------------"

        # Check if namespace exists, if not create it
        if [ -n "$namespace" ] && [ "$namespace" != "null" ]; then
            echo "🔍 Checking if namespace $namespace exists..."
            if ! kubectl get namespace "$namespace" --kubeconfig "$kubeconfig_path" $context_arg &>/dev/null; then
                echo "🚀 Namespace $namespace not found. Creating namespace $namespace..."
                kubectl create namespace "$namespace" --kubeconfig "$kubeconfig_path" $context_arg
                if [ $? -ne 0 ]; then
                    echo "❌ Error: Failed to create namespace: $namespace"
                    exit 1
                fi
                echo "✔️ Namespace $namespace created successfully."
            else
                echo "✔️ Namespace $namespace already exists."
            fi
        else
            echo "⚠️  No namespace specified. Default namespace will be used."
        fi

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
                echo "$inline_yaml" >"$temp_manifest"
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
            echo "$inline_yaml" | yq eval-all 'select(filename == "'"$temp_manifest"'") * select(filename == "-")' - "$temp_manifest" >"${temp_manifest}_merged"
            mv "${temp_manifest}_merged" "$temp_manifest"
        fi

        # Merge overrides if provided
        if [ -f "$overrides_yaml" ]; then
            echo "🔄 Merging overrides from $overrides_yaml into $temp_manifest"
            yq eval-all 'select(filename == "'"$temp_manifest"'") * select(filename == "'"$overrides_yaml"'")' "$temp_manifest" "$overrides_yaml" >"${temp_manifest}_merged"
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

run_k8s_commands_from_yaml() {
    local yaml_file=$1

    # Extract and ensure the base_path is absolute
    local base_path=$(yq e '.base_path' "$yaml_file")
    base_path=$(realpath "${base_path:-.}")

    # Check if the run_commands flag is set to true
    local run_commands=$(yq e '.run_commands // "false"' "$yaml_file")
    if [[ "$run_commands" != "true" ]]; then
        echo "⏩ Command execution is disabled (run_commands is not true). Skipping."
        return
    fi

    echo "🚀 Starting execution of Kubernetes commands from YAML file: $yaml_file"
    echo "🔧 Global Variables:"
    echo "  🗂️  global_kubeconfig_path= $GLOBAL_KUBECONFIG"
    echo "  🌐 global_kubecontext=$GLOBAL_KUBECONTEXT"
    echo "  🗂️  base_path=$base_path"
    echo "  🗂️  installation_files_path=$INSTALLATION_FILES_PATH"
    echo "-----------------------------------------"

    # Unset the local KUBECONFIG environment variable to avoid interference
    unset KUBECONFIG

    # Check if the commands section exists in the YAML file
    local commands_exist=$(yq e '.commands' "$yaml_file")
    if [[ "$commands_exist" == "null" ]]; then
        echo "⚠️  Warning: No 'commands' section found in the YAML file. Skipping command execution."
        return
    fi

    # Extract commands from the YAML file
    local commands_length=$(yq e '.commands | length' "$yaml_file")
    if [[ "$commands_length" -eq 0 ]]; then
        echo "⚠️  Warning: 'commands' section is defined, but no commands found. Skipping command execution."
        return
    fi

    # Iterate through each command set
    for index in $(seq 0 $((commands_length - 1))); do
        echo "🔄 Executing command set $((index + 1)) of $commands_length"

        # Extract the command stream and other configurations
        local command_stream_file="$INSTALLATION_FILES_PATH/command_stream_$index.sh"
        yq e ".commands[$index].command_stream" "$yaml_file" >"$command_stream_file"
        local command_stream=$(<"$command_stream_file")
        rm "$command_stream_file"

        local use_global_kubeconfig=$(yq e ".commands[$index].use_global_kubeconfig // false" "$yaml_file")
        local skip_installation=$(yq e ".commands[$index].skip_installation // false" "$yaml_file")
        local verify_install=$(yq e ".commands[$index].verify_install // false" "$yaml_file")
        local verify_install_timeout=$(yq e ".commands[$index].verify_install_timeout // 200" "$yaml_file")
        local skip_on_verify_fail=$(yq e ".commands[$index].skip_on_verify_fail // false" "$yaml_file")
        local namespace=$(yq e ".commands[$index].namespace // \"default\"" "$yaml_file")
        local kubeconfig=$(yq e ".commands[$index].kubeconfig" "$yaml_file")
        local kubecontext=$(yq e ".commands[$index].kubecontext" "$yaml_file")

        # Call the kubeaccess_precheck function and capture output
        read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
            "command_set_$index" \
            "$use_global_kubeconfig" \
            "$GLOBAL_KUBECONFIG" \
            "$GLOBAL_KUBECONTEXT" \
            "$kubeconfig" \
            "$kubecontext")

        # Log debug info
        echo "🔧 kubeaccess_precheck - Output Variables: command_set_$index"
        echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
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
            echo "  🗂️  Kubeconfig Path: $kubeconfig_path"
            echo "  🌐 Kubecontext: $kubecontext"
            exit 1
        fi

        # Prepare the kubeconfig and context arguments
        local kubeconfig_arg="--kubeconfig $kubeconfig_path"
        local context_arg="--context $kubecontext"

        # Log command before execution
        echo "🔧 Executing command stream with kubeconfig: $kubeconfig_path and context: $context_arg"

        # Print all variables for debugging
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

        # Execute each command in the stream with the appropriate kubeconfig and context
        while IFS= read -r cmd; do
            if [ -n "$cmd" ]; then
                if echo "$cmd" | grep -q "|"; then
                    # Complex command with pipes, handle each part correctly
                    local full_cmd="${cmd//kubectl/kubectl $kubeconfig_arg $context_arg}"
                    echo "🔄 Executing complex command: $full_cmd"
                    eval "$full_cmd"
                else
                    # Simple command
                    local full_cmd="kubectl $cmd $kubeconfig_arg $context_arg"
                    echo "🔄 Executing command: $full_cmd"
                    eval "$full_cmd"
                fi

                if [ $? -ne 0 ]; then
                    echo "❌ Error: Command failed: $cmd"
                    if [ "$skip_on_verify_fail" = true ]; then
                        echo "⚠️  Skipping further commands in this set due to failure."
                        break
                    else
                        echo "❌ Exiting due to command failure."
                        exit 1
                    fi
                fi
            fi
        done <<<"$command_stream"

        if [ "$verify_install" = true ]; then
            echo "🔍 Verifying installation in namespace: $namespace"
            local end_time=$((SECONDS + verify_install_timeout))
            while [ $SECONDS -lt $end_time ]; do
                local non_running_pods=$(kubectl get pods -n "$namespace" $kubeconfig_arg $context_arg --no-headers | awk '{print $3}' | grep -vE 'Running|Completed' | wc -l)
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

    # Additional Application Installations
    if [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "true" ]; then
        for ((i = 0; i < ${#ADDITIONAL_APPS[@]}; i++)); do
            app_name=$(yq e ".additional_apps[$i].name" "$EGS_INPUT_YAML")
            use_global_kubeconfig=$(yq e ".additional_apps[$i].use_global_kubeconfig" "$EGS_INPUT_YAML")
            skip_installation=$(yq e ".additional_apps[$i].skip_installation" "$EGS_INPUT_YAML")
            kubeconfig=$(yq e ".additional_apps[$i].kubeconfig" "$EGS_INPUT_YAML")
            kubecontext=$(yq e ".additional_apps[$i].kubecontext" "$EGS_INPUT_YAML")
            namespace=$(yq e ".additional_apps[$i].namespace" "$EGS_INPUT_YAML")
            release_name=$(yq e ".additional_apps[$i].release" "$EGS_INPUT_YAML")

            if [ "$skip_installation" = "false" ]; then
                read -r kubeconfig_path kubecontext < <(kubeaccess_precheck \
                    "$app_name" \
                    "$use_global_kubeconfig" \
                    "$GLOBAL_KUBECONFIG" \
                    "$GLOBAL_KUBECONTEXT" \
                    "$kubeconfig" \
                    "$kubecontext")
                check_helm_release_status "$release_name" "$namespace" "$kubeconfig_path" "$kubecontext"
            else
                echo "⏩ **Additional Application '$app_name'** installation was skipped."
            fi
        done
    else
        echo "⏩ **Additional application installation was skipped or disabled.**"
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
SKIP_RUN_COMMANDS="false"
SKIP_CUSTOM_APPS="false"
SKIP_ADDITIONAL_APPS="false"

# Parse command-line arguments for options
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --input-yaml)
        EGS_INPUT_YAML="$2"
        shift
        ;;
    --skip-run-commands)
        SKIP_RUN_COMMANDS="true"
        ;;
    --skip-custom-apps)
        SKIP_CUSTOM_APPS="true"
        ;;
    --skip-additional-apps)
        SKIP_ADDITIONAL_APPS="true"
        ;;
    --help)
        echo "Usage: $0 --input-yaml <yaml_file> [options]"
        echo "Options:"
        echo "  --input-yaml <yaml_file>            Path to the input configuration YAML file."
        echo "  --skip-run-commands                Skip running Kubernetes commands from YAML."
        echo "  --skip-custom-apps                 Skip applying custom app manifests."
        echo "  --skip-additional-apps             Skip installation of additional applications."
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


# Check if the enable_custom_apps flag is defined and set to true
enable_custom_apps=$(yq e '.enable_custom_apps // "false"' "$EGS_INPUT_YAML")

if [ "$enable_custom_apps" = "true" ] && [ "$SKIP_CUSTOM_APPS" != "true" ]; then
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
                yq e ".manifests = [ .manifests[$index] ]" "$EGS_INPUT_YAML" >"$temp_yaml"

                echo "🔍 Applying manifests from YAML..."
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

# Process additional applications if any are defined and installation is enabled
if [ "$ENABLE_INSTALL_ADDITIONAL_APPS" = "true" ] && [ "$SKIP_ADDITIONAL_APPS" != "true" ] && [ "${#ADDITIONAL_APPS[@]}" -gt 0 ]; then
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
        # kubeconfigname=$(yq e '.global_kubeconfig' "$EGS_INPUT_YAML")
        
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


        echo "🔍 Installing or upgrading Helm chart for application: $app_name"
        # Now call the install_or_upgrade_helm_chart function
        install_or_upgrade_helm_chart "$skip_installation" "$release_name" "$chart_name" "$namespace" "$use_global_kubeconfig" "$kubeconfig" "$kubecontext" "$repo_url" "$username" "$password" "$values_file" "$inline_values" "$image_pull_secret_repo" "$image_pull_secret_username" "$image_pull_secret_password" "$image_pull_secret_email" "$helm_flags" "$specific_use_local_charts" "$LOCAL_CHARTS_PATH" "$version" "$verify_install" "$verify_install_timeout" "$skip_on_verify_fail"
        
    done
    echo "✔️ Installation of additional applications complete."
else
    echo "⏩ Skipping installation of additional applications as ENABLE_INSTALL_ADDITIONAL_APPS is set to false."
fi

# Validate the run_commands flag before invoking the function
run_commands=$(yq e '.run_commands // "false"' "$EGS_INPUT_YAML")

if [ "$run_commands" != "true" ] || [ "$SKIP_RUN_COMMANDS" = "true" ]; then
    echo "⏩ Command execution is disabled (run_commands is not true). Skipping."
else
    echo "🚀 Running Kubernetes commands from YAML..."
    # Call the function if validation passes
    run_k8s_commands_from_yaml "$EGS_INPUT_YAML"
fi

trap display_summary EXIT

echo "========================================="
echo "    EGS Install Prerequisites Script Complete        "
echo "========================================="

echo "=====================================EGS Install Prerequisites Script execution completed at: $(date)===================================" >> "$output_file"
