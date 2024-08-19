#!/bin/bash

# Function to display usage
usage() {
    echo -e "\033[1;32mUsage:\033[0m $0 -k <kubeconfig_absolute_path> -s <slice_name> -p <project_name>"
    echo -e "       $0 --kubeconfig <kubeconfig_absolute_path> --slice <slice_name> --project <project_name>"
    echo ""
    echo -e "\033[1;34mParameters:\033[0m"
    echo -e "  \033[1;36m-k, --kubeconfig\033[0m  \U1F4C1  Absolute path to the kubeconfig file used for connecting to the Kubernetes cluster."
    echo -e "  \033[1;36m-s, --slice\033[0m       \U1F4A5  Name of the slice for which the token is to be retrieved."
    echo -e "  \033[1;36m-p, --project\033[0m     \U1F4DA  Name of the project (namespace) where the slice is located."
    echo -e "  \033[1;36m-h, --help\033[0m        \U1F6C8  Display this help message."
    echo ""
    echo -e "\033[1;34mExample:\033[0m"
    echo -e "  \033[1;32m$0\033[0m -k /path/to/kubeconfig -s pool1 -p avesha"
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
        -h|--help) usage ;;
        *) error_exit "Unknown parameter: $1";;
    esac
    shift
done

# Ensure all required arguments are provided
if [ -z "$KUBECONFIG_PATH" ]; then
    error_exit "The --kubeconfig (-k) parameter is required."
fi

if [ ! -f "$KUBECONFIG_PATH" ]; then
    error_exit "The kubeconfig file at '$KUBECONFIG_PATH' does not exist."
fi

if [ -z "$SLICE_NAME" ]; then
    error_exit "The --slice (-s) parameter is required."
fi

if [ -z "$PROJECT_NAME" ]; then
    error_exit "The --project (-p) parameter is required."
fi

# Define the secret name and namespace
SECRET_NAME="kubeslice-rbac-slice-${SLICE_NAME}"
NAMESPACE="kubeslice-${PROJECT_NAME}"

# Fetch the token from the secret and decode it
TOKEN=$(kubectl --kubeconfig="$KUBECONFIG_PATH" -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath="{.data.token}" 2>/dev/null | base64 --decode)

# Check if the token was successfully retrieved
if [ -z "$TOKEN" ]; then
    error_exit "Failed to retrieve token from secret '$SECRET_NAME' in namespace '$NAMESPACE'. Ensure the secret exists and you have the correct permissions."
fi

# Output the decoded token
echo -e "\033[1;32mDecoded token for slice '\033[1;33m$SLICE_NAME\033[1;32m' in project '\033[1;33m$PROJECT_NAME\033[1;32m':\033[0m"
echo "$TOKEN"
