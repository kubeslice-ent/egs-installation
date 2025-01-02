#!/bin/bash

# Function to check if the Kubernetes cluster is accessible
check_k8s_cluster_access() {
  local kubeconfig="$1"
  local kubecontext="$2"

  if ! kubectl $kubeconfig $kubecontext version --short >/dev/null 2>&1; then
    echo "Error: Unable to access Kubernetes cluster. Ensure kubectl is configured correctly."
    exit 1
  fi
}

# Function to check if namespace creation is possible
check_namespace_creation() {
  local kubeconfig="$1"
  local kubecontext="$2"

  if ! kubectl $kubeconfig $kubecontext auth can-i create namespace >/dev/null 2>&1; then
    echo "Error: You do not have permissions to create namespaces."
    exit 1
  fi
  echo "Namespace creation is allowed."
}

# Function to check if a namespace exists
check_namespace_exists() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespace="$3"

  if kubectl $kubeconfig $kubecontext get namespace "$namespace" >/dev/null 2>&1; then
    echo "Namespace '$namespace' already exists."
    return 0
  else
    echo "Namespace '$namespace' does not exist."
    return 1
  fi
}

# Function to check if a namespace is empty
check_namespace_empty() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespace="$3"

  resources=$(kubectl $kubeconfig $kubecontext get all --namespace "$namespace" --no-headers 2>/dev/null)
  if [[ -z $resources ]]; then
    echo "Namespace '$namespace' is empty."
    return 0
  else
    echo "Namespace '$namespace' is not empty."
    return 1
  fi
}

# Function to test namespace creation and deletion
test_namespace_creation_deletion() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local test_namespace="$3"

  echo "Attempting to create a test namespace '$test_namespace'."
  if ! kubectl $kubeconfig $kubecontext create namespace "$test_namespace" >/dev/null 2>&1; then
    echo "Error: Unable to create test namespace '$test_namespace'."
    exit 1
  fi
  echo "Test namespace '$test_namespace' created successfully."

  echo "Attempting to delete the test namespace '$test_namespace'."
  if ! kubectl $kubeconfig $kubecontext delete namespace "$test_namespace" --wait >/dev/null 2>&1; then
    echo "Error: Unable to delete test namespace '$test_namespace'."
    exit 1
  fi
  echo "Test namespace '$test_namespace' deleted successfully."
}

# Wrapper function for all namespace-related checks
namespace_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local input_namespace="$3"
  local test_namespace="$4"

  check_k8s_cluster_access "$kubeconfig" "$kubecontext"

  echo "Checking namespace creation permissions..."
  check_namespace_creation "$kubeconfig" "$kubecontext"

  check_namespace_exists "$kubeconfig" "$kubecontext" "$input_namespace"
  if [[ $? -eq 0 ]]; then
    echo "Checking if namespace '$input_namespace' is empty..."
    check_namespace_empty "$kubeconfig" "$kubecontext" "$input_namespace"
  fi

  echo "Testing namespace creation and deletion capabilities with namespace '$test_namespace'..."
  test_namespace_creation_deletion "$kubeconfig" "$kubecontext" "$test_namespace"

  echo "Namespace preflight checks completed successfully."
}

# Function to invoke multiple wrapper functions
invoke_wrappers() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local wrapper_args="$3"

  IFS=',' read -r -a wrappers <<< "$wrapper_args"

  for wrapper in "${wrappers[@]}"; do
    case "$wrapper" in
      namespace_preflight_checks)
        if [[ -z "$input_namespace" || -z "$test_namespace" ]]; then
          echo "Error: Parameters --namespace-to-check and --test-namespace are required for namespace_preflight_checks."
          exit 1
        fi
        namespace_preflight_checks "$kubeconfig" "$kubecontext" "$input_namespace" "$test_namespace"
        ;;
      *)
        echo "Error: Unknown wrapper function '$wrapper'."
        exit 1
        ;;
    esac
  done
}

# Main script execution
main() {
  local input_namespace=""
  local test_namespace=""
  local wrappers_to_invoke=""
  local kubeconfig=""
  local kubecontext=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --namespace-to-check)
        input_namespace="$2"
        shift 2
        ;;
      --test-namespace)
        test_namespace="$2"
        shift 2
        ;;
      --invoke-wrappers)
        wrappers_to_invoke="$2"
        shift 2
        ;;
      --kubeconfig)
        kubeconfig="--kubeconfig=$2"
        shift 2
        ;;
      --kubecontext)
        kubecontext="--context=$2"
        shift 2
        ;;
      *)
        echo "Unknown parameter: $1"
        echo "Usage: $0 [--namespace-to-check <namespace>] [--test-namespace <namespace>] [--kubeconfig <path>] [--kubecontext <context>] --invoke-wrappers <wrapper1,wrapper2,...>"
        exit 1
        ;;
    esac
  done

  if [[ -n "$wrappers_to_invoke" ]]; then
    invoke_wrappers "$kubeconfig" "$kubecontext" "$wrappers_to_invoke"
  else
    echo "No wrappers invoked. Use --invoke-wrappers to execute specific functions."
  fi
}

main "$@"
