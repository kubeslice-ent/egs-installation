#!/bin/bash

create_namespaces() {
  local input_yaml=""
  local kubeconfig=""
  local kubecontext_list=()
  local success_count=0
  local failure_count=0
  local success_details=()
  local failure_details=()

  # Display help message
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --input-yaml <path>         Path to the input YAML file containing namespace definitions."
    echo "  --kubeconfig <path>         Path to the kubeconfig file for accessing the Kubernetes cluster."
    echo "  --kubecontext-list <list>   Comma-separated list of Kubernetes contexts to process."
    echo "  -h, --help                  Display this help message."
    exit 0
  fi

  # Parse named parameters
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input-yaml)
        input_yaml="$2"
        shift 2
        ;;
      --kubeconfig)
        kubeconfig="$2"
        shift 2
        ;;
      --kubecontext-list)
        IFS=',' read -r -a kubecontext_list <<< "$2"
        shift 2
        ;;
      *)
        echo "❌ Unknown parameter: $1" >&2
        echo "Use --help or -h for usage information." >&2
        exit 1
        ;;
    esac
  done

  # Validate inputs
  if [[ -z "$input_yaml" || -z "$kubeconfig" || ${#kubecontext_list[@]} -eq 0 ]]; then
    echo "❌ Error: Missing required parameters." >&2
    echo "Use --help or -h for usage information." >&2
    exit 1
  fi

  # Check if yq is installed
  if ! command -v yq &> /dev/null; then
    echo "❌ Error: yq is required but not installed." >&2
    exit 1
  fi

  # Extract auto_create_namespace flag
  local auto_create=$(yq e '.auto_create_namespace' "$input_yaml")

  if [[ "$auto_create" != "true" ]]; then
    echo "⚠️ auto_create_namespace is not true. Exiting."
    return
  fi

  # Get the current base directory
  local base_dir=$(pwd)

  # Iterate over contexts
  for kubecontext in "${kubecontext_list[@]}"; do
    echo "🔄 Processing context: $kubecontext"

    # Iterate over namespaces and create them
    local namespaces_count=$(yq e '.namespaces | length' "$input_yaml")

    for ((i=0; i<namespaces_count; i++)); do
      local namespace=$(yq e ".namespaces[$i].name" "$input_yaml")

      echo "🔧 Creating namespace: $namespace in context: $kubecontext"

      # Create temporary YAML for namespace
      local tmp_yaml="$base_dir/${namespace}_namespace.yaml"
      echo "apiVersion: v1" > "$tmp_yaml"
      echo "kind: Namespace" >> "$tmp_yaml"
      echo "metadata:" >> "$tmp_yaml"
      echo "  name: $namespace" >> "$tmp_yaml"
      echo "  annotations:" >> "$tmp_yaml"

      local annotations_count=$(yq e ".namespaces[$i].annotations | length" "$input_yaml")
      for ((j=0; j<annotations_count; j++)); do
        local key=$(yq e ".namespaces[$i].annotations[$j].key" "$input_yaml")
        local value=$(yq e ".namespaces[$i].annotations[$j].value" "$input_yaml")
        echo "    $key: $value" >> "$tmp_yaml"
      done

      echo "  labels:" >> "$tmp_yaml"
      local labels_count=$(yq e ".namespaces[$i].labels | length" "$input_yaml")
      for ((k=0; k<labels_count; k++)); do
        local key=$(yq e ".namespaces[$i].labels[$k].key" "$input_yaml")
        local value=$(yq e ".namespaces[$i].labels[$k].value" "$input_yaml")
        echo "    $key: $value" >> "$tmp_yaml"
      done

      # Apply the namespace YAML
      if kubectl --kubeconfig="$kubeconfig" --context="$kubecontext" apply -f "$tmp_yaml"; then
        echo "✅ Successfully created namespace: $namespace in context: $kubecontext"
        success_details+=("$namespace (context: $kubecontext)")
        ((success_count++))
      else
        local error_message=$(kubectl --kubeconfig="$kubeconfig" --context="$kubecontext" apply -f "$tmp_yaml" 2>&1)
        echo "❌ Failed to create namespace: $namespace in context: $kubecontext"
        echo "   Reason: $error_message"
        failure_details+=("$namespace (context: $kubecontext): $error_message")
        ((failure_count++))
      fi

      # Cleanup temporary YAML file
      rm "$tmp_yaml"
    done
  done

  # Summary
  echo "\n📋 Summary:"
  echo "✅ Successful operations: $success_count"
  for detail in "${success_details[@]}"; do
    echo "   - $detail"
  done

  echo "❌ Failed operations: $failure_count"
  for detail in "${failure_details[@]}"; do
    echo "   - $detail"
  done
}

# Invocation
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  create_namespaces "$@"
fi
