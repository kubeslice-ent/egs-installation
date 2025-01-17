#!/bin/bash

# Function to display usage
usage() {
    echo -e "\033[1;32mUsage:\033[0m $0 -k <kubeconfig_absolute_path> [-s <slice_name>] -p <project_name> [-a] -u <username1,username2,...>"
    echo -e "       $0 --kubeconfig <kubeconfig_absolute_path> [--slice <slice_name>] --project <project_name> [--admin] --username <username1,username2,...>"
    echo ""
    echo -e "\033[1;34mParameters:\033[0m"
    echo -e "  \033[1;36m-k, --kubeconfig\033[0m  \U1F4C1  Absolute path to the kubeconfig file used for connecting to the Kubernetes cluster."
    echo -e "  \033[1;36m-s, --slice\033[0m       \U1F4A5  Name of the slice for which the tokens are to be retrieved (optional if -a is provided)."
    echo -e "  \033[1;36m-p, --project\033[0m     \U1F4DA  Name of the project (namespace) where the slice is located."
    echo -e "  \033[1;36m-a, --admin\033[0m       \U1F512  Fetch the admin token for the specified usernames (makes --slice optional)."
    echo -e "  \033[1;36m-u, --username\033[0m    \U1F464  Comma-separated list of usernames for fetching admin tokens (used with --admin)."
    echo -e "  \033[1;36m-h, --help\033[0m        \U1F6C8  Display this help message."
    echo ""
    echo -e "\033[1;34mExample:\033[0m"
    echo -e "  \033[1;32m$0\033[0m -k /path/to/kubeconfig -s pool1 -p avesha -a -u admin,dev"
    exit 1
}

# Function to display an error message and exit
error_exit() {
    echo -e "\033[1;31mError:\033[0m $1"
    exit 1
}

# If no arguments are provided, display usage
if [ "$#" -eq 0 ]; then
    usage
fi

# Parse the command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -k|--kubeconfig) KUBECONFIG_PATH="$2"; shift ;;
        -s|--slice) SLICE_NAME="$2"; shift ;;
        -p|--project) PROJECT_NAME="$2"; shift ;;
        -a|--admin) FETCH_ADMIN=true ;;
        -u|--username) USERNAMES="$2"; shift ;;
        -h|--help) usage ;;
        *) error_exit "Unknown parameter: $1";;
    esac
    shift
done

# Ensure required arguments are provided
if [ -z "$KUBECONFIG_PATH" ]; then
    error_exit "The --kubeconfig (-k) parameter is required."
fi

if [ ! -f "$KUBECONFIG_PATH" ]; then
    error_exit "The kubeconfig file at '$KUBECONFIG_PATH' does not exist."
fi

if [ -z "$PROJECT_NAME" ]; then
    error_exit "The --project (-p) parameter is required."
fi

if [ "$FETCH_ADMIN" != true ] && [ -z "$SLICE_NAME" ]; then
    error_exit "The --slice (-s) parameter is required unless --admin (-a) is specified."
fi

if [ "$FETCH_ADMIN" = true ] && [ -z "$USERNAMES" ]; then
    error_exit "The --username (-u) parameter is required when fetching admin tokens."
fi

# Define the namespace
NAMESPACE="kubeslice-${PROJECT_NAME}"

# Define secret names for read-only and read-write tokens if slice is provided
if [ -n "$SLICE_NAME" ]; then
    SECRET_NAME_RO="kubeslice-rbac-ro-slice-${SLICE_NAME}"
    SECRET_NAME_RW="kubeslice-rbac-rw-slice-${SLICE_NAME}"
fi

# Function to retrieve and decode token from a secret
fetch_token() {
    local secret_name="$1"
    local token

    token=$(kubectl --kubeconfig="$KUBECONFIG_PATH" -n "$NAMESPACE" get secret "$secret_name" -o jsonpath="{.data.token}" 2>/dev/null | base64 --decode)

    if [ -z "$token" ]; then
        echo -e "\033[1;31mError:\033[0m Failed to retrieve token from secret '$secret_name' in namespace '$NAMESPACE'. Ensure the secret exists and you have the correct permissions."
    else
        echo -e "\033[1;32mDecoded token for secret '\033[1;33m$secret_name\033[1;32m':\033[0m"
        echo "$token"
    fi
}

# Fetch and display tokens for read-only and read-write if slice name is provided
if [ -n "$SLICE_NAME" ]; then
    fetch_token "$SECRET_NAME_RO"
    fetch_token "$SECRET_NAME_RW"
fi

# If admin tokens are requested, split the usernames and fetch tokens for each
if [ "$FETCH_ADMIN" = true ]; then
    IFS=',' read -ra USERNAME_ARRAY <<< "$USERNAMES"
    for USERNAME in "${USERNAME_ARRAY[@]}"; do
        SECRET_NAME_ADMIN="kubeslice-rbac-rw-${USERNAME}"
        fetch_token "$SECRET_NAME_ADMIN"
    done
fi
