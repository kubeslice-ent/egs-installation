#!/bin/bash

# Define the script version
SCRIPT_VERSION="1.12.1"

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
output_file="egs-preflight-check-output.log"
exec > >(tee -a "$output_file") 2>&1

echo "=====================================EGS Preflight Check Script execution started at: $(date)===================================" >> "$output_file"
# Global default values
labels="managed-by=egs-script,purpose=preflight-check"
annotations="managed-by=egs-script,purpose=preflight-check"
namespaces_to_check=""
test_namespace="egs-test-namespace"
pvc_test_namespace="egs-test-namespace"
wrappers_to_invoke=""
kubeconfig=""
kubecontext=""
pvc_name="egs-test-pvc"
storage_class=""
storage_size="1Gi"
cleanup="true"
display_resources="false"
global_wait="2"
KUBECTL_BIN=$(which kubectl)
service_type="all"
service_name="egs-test-service"
watch_resources="true"
watch_duration="7"
function_debug_input="false"
generate_summary_flag="true"
fetch_resource_names="prometheus,gpu-operator,grafana,nginx"
#fetch_resource_names=""
#fetch_webhook_names="aiops-mutating-webhook-configuration,kubeslice-mutating-webhook-configuration,prometheus-kube-prometheus-admission,aiops-validating-webhook-configuration,gpr-validating-webhook-configuration,kubeslice-controller-validating-webhook-configuration,kubeslice-validating-webhook-configuration,prometheus-kube-prometheus-admission"
#fetch_webhook_names=""
# Global default resource_action_pairs
resource_action_pairs="namespace:create,namespace:delete,namespace:get,namespace:list,pod:create,pod:delete,pod:list,service:create,configmap:create,configmap:get,configmap:list,secret:create,secret:list,serviceaccount:create,serviceaccount:list,clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list,clusterrolebinding:create,clusterrolebinding:get,clusterrolebinding:list,deployment:create,deployment:delete,deployment:get,deployment:list,deployment"
#resource_action_pairs="namespace:create,namespace:delete,namespace:get,namespace:list,namespace:watch,pod:create,pod:delete,pod:get,pod:list,pod:watch,service:create,service:delete,service:get,service:list,service:watch,configmap:create,configmap:delete,configmap:get,configmap:list,configmap:watch,secret:create,secret:delete,secret:get,secret:list,secret:watch,serviceaccount:create,serviceaccount:delete,serviceaccount:get,serviceaccount:list,serviceaccount:watch,clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list,clusterrolebinding:create,clusterrolebinding:delete,clusterrolebinding:get,clusterrolebinding:list,deployment:create,deployment:delete,deployment:get,deployment:list,deployment:watch,statefulset:create,statefulset:delete,statefulset:get,statefulset:list,statefulset:watch"
webhooks="all"
# Define all API resources as a single variable
#api_resources="namespace,pod,daemonset,job,service,serviceaccount,ingress,configmap,secret,persistentvolume,persistentvolumeclaim,storageclass,clusterrole,clusterrolebinding,role,rolebinding,event"
api_resources="pod,service"



# Array to store summary information
declare -A summary
# Initialize arrays for tracking commands and their inputs
declare -a commands
declare -A command_inputs

display_help() {
  echo -e "🔹 Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  🗂️  --namespace-to-check <namespace1,namespace2,...> Comma-separated list of namespaces to check existence."
  echo -e "  🏷️  --test-namespace <namespace>                    Namespace for test creation and deletion (default: egs-test-namespace)."
  echo -e "  🏷️  --test-namespace-labels <key1=value1,key2=value2,...> Labels to apply to the test namespace (default: purpose=preflight-check,managed-by=egs-script)."
  echo -e "  📝  --test-namespace-annotations <key1=value1,key2=value2,...> Annotations to apply to the test namespace (default: purpose=preflight-check,managed-by=egs-script)."
  echo -e "  📂  --pvc-test-namespace <namespace>                Namespace for PVC test creation and deletion (default: egs-test-namespace)."
  echo -e "  🛠️  --pvc-name <name>                               Name of the test PVC (default: egs-test-pvc)."
  echo -e "  🗄️  --storage-class <class>                         Storage class for the PVC (default: none)."
  echo -e "  📦  --storage-size <size>                           Storage size for the PVC (default: 1Gi)."
  echo -e "  📌  --service-name <name>                           Name of the test service (default: test-service)."
  echo -e "  ⚙️   --service-type <type>                           Type of service to create and validate (ClusterIP, NodePort, LoadBalancer, or all). Default: all."
  echo -e "  🗂️  --kubeconfig <path>                             Path to the kubeconfig file (mandatory)."
  echo -e "  🌐  --kubecontext <context>                         Context from the kubeconfig file (mandatory)."
  echo -e "  🌐  --kubecontext-list <context1,context2,...>      Comma-separated list of context names to operate on."
  echo -e "  🧹  --cleanup <true|false>                          Whether to delete test resources (default: true)."
  echo -e "  ⏳  --global-wait <seconds>                         Time to wait after each command execution (default: 0)."
  echo -e "  👀  --watch-resources <true|false>                  Enable or disable watching resources after creation (default: false)."
  echo -e "  ⏱️  --watch-duration <seconds>                      Duration to watch resources after creation (default: 30 seconds)."
  echo -e "  🛠️  --invoke-wrappers <wrapper1,wrapper2,...>       Comma-separated list of wrapper functions to invoke."
  echo -e "  👁️  --display-resources <true|false>                Whether to display resources created (default: true)."
  echo -e "  ⚡   --kubectl-path <path>                           Override default kubectl binary path."
  echo -e "  🐞  --function-debug-input <true|false>             Enable or disable function debugging (default: false)."
  echo -e "  📊  --generate-summary <true|false>                 Enable or disable summary generation (default: true)."
  echo -e "  🔐  --resource-action-pairs <pairs>                 Override default resource-action pairs (e.g., pod:create,service:get)."
  echo -e "  🔍  --fetch-resource-names <true|false>             Fetch all resource names from the cluster (default: false)."
  echo -e "  🔍  --fetch-webhook-names <true|false>              Fetch all webhook names from the cluster (default: false)."
  echo -e "  🌍  --api-resources <resource1,resource2,...>       Comma-separated list of API resources to include or operate on."
  echo -e "  🌍  --webhooks <resource1,resource2,...>            Comma-separated list of webhooks to include or operate on."
  echo -e "  ❓  --help                                          Display this help message."
  echo -e "
Default Resource-Action Pairs:
  📌 The default resource-action pairs used for privilege checks are:
      namespace:create,namespace:delete,namespace:get,namespace:list,namespace:watch,
      pod:create,pod:delete,pod:get,pod:list,pod:watch,
      service:create,service:delete,service:get,service:list,service:watch,
      configmap:create,configmap:delete,configmap:get,configmap:list,configmap:watch,
      secret:create,secret:delete,secret:get,secret:list,secret:watch,
      serviceaccount:create,serviceaccount:delete,serviceaccount:get,serviceaccount:list,serviceaccount:watch,
      clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list,
      clusterrolebinding:create,clusterrolebinding:delete,clusterrolebinding:get,clusterrolebinding:list

Wrapper Functions:
  🗂️  namespace_preflight_checks                     Validates namespace creation and existence.
  🔍  grep_k8s_resources_with_crds_and_webhooks      Validates existing resources available in cluster based on resource names. (prometheus,gpu-operator,postgresql)
  📂  pvc_preflight_checks                           Validates PVC creation, deletion, and storage properties.
  ⚙️   service_preflight_checks                       Validates the creation and deletion of services (ClusterIP, NodePort, LoadBalancer).
  🔐  k8s_privilege_preflight_checks                 Validates privileges for Kubernetes actions on resources.
  🌐  internet_access_preflight_checks               Validates internet connectivity from within the Kubernetes cluster.


Examples:
  $0 --namespace-to-check my-namespace --test-namespace test-ns --invoke-wrappers namespace_preflight_checks
  $0 --pvc-test-namespace pvc-ns --pvc-name test-pvc --storage-class standard --storage-size 1Gi --invoke-wrappers pvc_preflight_checks
  $0 --test-namespace service-ns --service-name test-service --service-type NodePort --watch-resources true --watch-duration 60 --invoke-wrappers service_preflight_checks
  $0 --invoke-wrappers namespace_preflight_checks,pvc_preflight_checks,service_preflight_checks
  $0 --resource-action-pairs pod:create,namespace:delete --invoke-wrappers k8s_privilege_preflight_checks
  $0 --function-debug-input true --invoke-wrappers namespace_preflight_checks
  $0 --generate-summary false --invoke-wrappers namespace_preflight_checks
  $0 --fetch-resource-names true --invoke-wrappers service_preflight_checks
  $0 --api-resources pod,service --invoke-wrappers namespace_preflight_checks"
  exit 0
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



# Function to add summary details
log_summary() {
  local key="$1"
  local value="$2"
  summary["$key"]="$value"
}


generate_summary() {

local kubecontext="$1"

  if [ "$generate_summary_flag" == "true" ]; then
    # Display Inputs Used
    echo -e "\n📂 ====================== INPUTS USED FOR CLUSTER WITH KUBECONTEXT ${kubecontext:-N/A} ==============================================="
    printf "| %-30s | %-50s |\n" "🔧 Input Parameter" "• Value"
    echo "------------------------------------------------------------------------------------------"
    printf "| %-30s | %-50s |\n" "Namespaces to Check" "${namespaces_to_check:-None}"
    printf "| %-30s | %-50s |\n" "Test Namespace" "${test_namespace:-egs-test-namespace}"
    printf "| %-30s | %-50s |\n" "PVC Test Namespace" "${pvc_test_namespace:-egs-test-namespace}"
    printf "| %-30s | %-50s |\n" "Kubeconfig" "${kubeconfig:-Not provided}"
    printf "| %-30s | %-50s |\n" "Kubecontext" "${kubecontext:-Not provided}"
    printf "| %-30s | %-50s |\n" "Kubecontext_list" "${kubecontext_list:-Not provided}"
    printf "| %-30s | %-50s |\n" "PVC Name" "${pvc_name:-egs-test-pvc}"
    printf "| %-30s | %-50s |\n" "Storage Class" "${storage_class:-None}"
    printf "| %-30s | %-50s |\n" "Storage Size" "${storage_size:-1Gi}"
    printf "| %-30s | %-50s |\n" "Service Name" "${service_name:-egs-test-service}"
    printf "| %-30s | %-50s |\n" "Service Type" "${service_type:-all}"
    printf "| %-30s | %-50s |\n" "Cleanup" "${cleanup:-true}"
    printf "| %-30s | %-50s |\n" "Wrappers Invoked" "${wrappers_to_invoke:-None}"
    printf "| %-30s | %-50s |\n" "Display Resources" "${display_resources:-true}"
    printf "| %-30s | %-50s |\n" "Global Wait" "${global_wait:-0}"
    printf "| %-30s | %-50s |\n" "Watch Resources" "${watch_resources:-false}"
    printf "| %-30s | %-50s |\n" "Watch Duration" "${watch_duration:-30}"
    printf "| %-30s | %-50s |\n" "Function Debug Input" "${function_debug_input:-false}"
    printf "| %-30s | %-50s |\n" "Fetch Resource Names" "${fetch_resource_names:-false}"
    printf "| %-30s | %-50s |\n" "API Resources" "${api_resources:-false}"
    printf "| %-30s | %-50s |\n" "Webhooks" "${webhooks:-false}"
    printf "| %-30s | %-50s |\n" "Fetch Webhook Names" "${fetch_webhook_names:-false}"
    echo "============================================================================================"

    # Display Kubernetes Cluster Info
    echo -e "\n📊 ====================== KUBERNETES CLUSTER DETAILS ======================================================================================================================"
    printf "| %-30s | %-50s |\n" "🔧 Parameter" "📦 Value"
    echo "-----------------------------------------------------------------------------------------------------------------------------------"
    printf "| %-30s | %-50s |\n" "🔧 Kubeconfig" "${kubeconfig:-None}"
    printf "| %-30s | %-50s |\n" "🌐 Kubecontext" "${kubecontext:-default-context}"
    printf "| %-30s | %-50s |\n" "📡 Cluster Endpoint" "$(echo "${summary[K8S Cluster Endpoint]:-❌ Missing}" | grep -oE 'https?://[^ ]+')"
    printf "| %-30s | %-50s |\n" "🔐 Cluster Access" "${summary[Kubernetes Cluster Access]:-❌ Missing}"

    echo -e "\n📊 ====================== KUBERNETES NODE DETAILS ========================================================================================================================="
    printf "| %-30s | %-500s |\n" "📊 Node Details" "${summary[Node Details]:-❌ Missing}"

    echo "================================ END OF KUBERNETES CLUSTER DETAILS ========================================================================================================"

    # Define descriptions for wrapper function names
    declare -A function_descriptions=(
      ["k8s_privilege_preflight_checks"]="Kubernetes Privilege Checks"
      ["namespace_preflight_checks"]="Namespace Validation Checks"
      ["pvc_preflight_checks"]="Persistent Volume Claim Checks"
      ["service_preflight_checks"]="Service Configuration Checks"
      ["grep_k8s_resources_with_crds_and_webhooks"]="Kubernetes Resources & CRD/Webhook Validation"
      ["internet_access_preflight_checks"]="Internet Connectivity Checks from Pod"
    )

    # Define the predefined list of wrapper function names
    function_defaults=(
      "k8s_privilege_preflight_checks"
      "namespace_preflight_checks"
      "pvc_preflight_checks"
      "service_preflight_checks"
      "grep_k8s_resources_with_crds_and_webhooks"
      "internet_access_preflight_checks"
    )

declare -A grouped_results

# Process the summary array to organize results by function
for key in "${!summary[@]}"; do
  function_name=$(echo "$key" | awk -F' - ' '{print $1}')
  resource_action=$(echo "$key" | awk -F' - ' '{print $2}')
  status="${summary[$key]}"

  if [[ "$function_name" == "k8s_privilege_preflight_checks" ]]; then
    resource=$(echo "$resource_action" | cut -d':' -f1)
    action=$(echo "$resource_action" | cut -d':' -f2)
    namespace=$(echo "$status" | awk '{print $1}')
    detailed_status=$(echo "$status" | awk '{$1=""; $2=""; $3=""; print $0}' | xargs)
    grouped_results["$function_name"]+="$namespace:$resource:$action:$detailed_status;"
  else
    grouped_results["$function_name"]+="$resource_action:$status;"
  fi
done

# Generate and print the summary for each function
for function_name in "${function_defaults[@]}"; do
  if [[ -n "${grouped_results[$function_name]}" ]]; then
    echo -e "\n🔍 ====================== SUMMARY FOR: ${function_descriptions[$function_name]} ========================================================================================================================================================="
    if [[ "$function_name" == "k8s_privilege_preflight_checks" ]]; then
      printf "| %-40s | %-35s | %-20s | %-55s | %-15s | %-10s |\n" "Resource" "Action" "Found/Notfound" "Detailed Summary" "Status" "✅/⚠️/❌"
    else
      printf "| %-40s | %-115s | %-15s | %-10s |\n" "Resource Check Type" "Detailed Summary" "Status" "✅/⚠️/❌"
    fi
    echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

    IFS=';' read -ra entries <<< "${grouped_results[$function_name]}"
    for entry in "${entries[@]}"; do
      if [[ "$function_name" == "k8s_privilege_preflight_checks" ]]; then
        IFS=':' read -r namespace resource action detailed_status <<< "$entry"
        found_status=$([[ "$detailed_status" == *"Success"* ]] && echo "Found" || echo "Notfound")
        if [[ "$detailed_status" == *"Skipped"* ]]; then
          icon="⚠️"
          trimmed_status="Skipped"
        else
          icon=$([[ "$detailed_status" == *"Success"* ]] && echo "✅" || echo "❌")
          trimmed_status=$([[ "$detailed_status" == *"Success"* ]] && echo "Success" || echo "Failure")
        fi
        printf "| %-40s | %-35s | %-20s | %-55s | %-15s | %-10s |\n" \
          "${resource:-Unknown}" "${action:-Unknown}" "$found_status" "$detailed_status" "$trimmed_status" "$icon"
      else
        IFS=':' read -r resource_action detailed_status <<< "$entry"
        resource_name=$(echo "$resource_action" | awk -F':' '{print $1}')
        resource_type=$(echo "$resource_action" | awk -F':' '{print $2}')
        if [[ "$detailed_status" == *"Skipped"* ]]; then
          icon="⚠️"
          trimmed_status="Skipped"
        else
          icon=$([[ "$detailed_status" == *"Success"* ]] && echo "✅" || echo "❌")
          trimmed_status=$([[ "$detailed_status" == *"Success"* ]] && echo "Success" || echo "Failure")
        fi
        printf "| %-40s | %-115s | %-15s | %-10s |\n" \
          "${resource_name:-Unknown}" "$detailed_status" "$trimmed_status" "$icon"
      fi
    done
    echo "==================================================================================================================================================================================================================================================="
  fi
done

# Final check if there are no results
if [[ ${#grouped_results[@]} -eq 0 ]]; then
  echo "📂 No grouped results to display."
else
  echo "📂 Summary generation is complete."
fi
  else
    echo "📂 Summary generation is disabled."
  fi
}




grep_k8s_resources_with_crds_and_webhooks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local test_namespace="$3"
  local cleanup="$4"
  local display_resources_flag="$5"
  local global_wait="$6"
  local watch_resources="${7:-false}"
  local watch_duration="${8:-30}"
  local fetch_resource_names="${9:-}"
  local api_resources="${10:-all}"
  local webhooks="${11:-all}"
  local fetch_webhook_names="${12:-}"
  local function_name="grep_k8s_resources_with_crds_and_webhooks"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration, fetch_resource_names=$fetch_resource_names, api_resources=$api_resources, webhooks=$webhooks, fetch_webhook_names=$fetch_webhook_names"
  log_command "$function_name" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, cleanup=$cleanup"

  # Determine the resource names to process
  local resource_name_array
  if [[ "$api_resources" == "all" ]]; then
    echo "🌍 Fetching all API resources from the cluster..."
    resource_name_array=($(run_command kubectl $kubeconfig --context=$kubecontext api-resources --no-headers | awk '{print $1}' | tr '\n' ' '))
    if [[ ${#resource_name_array[@]} -eq 0 ]]; then
      echo "❌ Failed to fetch API resources. Ensure your Kubernetes context is valid."
      log_summary "$function_name - API Resources Check" "N/A:N/A:API Resources Check Not Found:Failure"
      return 1
    fi
  else
    IFS=',' read -r -a resource_name_array <<< "$api_resources"
  fi

  # Perform resource checks if fetch_resource_names is provided
  if [[ -n "$fetch_resource_names" ]]; then
    for resource_type in "${resource_name_array[@]}"; do
      if [[ "$function_debug_input" == "true" ]]; then
        echo -e "\n🔍 Searching for resource type: $resource_type"
      fi
      IFS=',' read -r -a fetch_names_array <<< "$fetch_resource_names"
      for resource_name in "${fetch_names_array[@]}"; do
        if [[ "$function_debug_input" == "true" ]]; then
          echo "🔍 Filtering for resource type '$resource_type' with name containing '$resource_name'..."
        fi
        local resource_matches
        resource_matches=$(run_command kubectl $kubeconfig --context=$kubecontext get $resource_type --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name 2>/dev/null | grep -i "$resource_name")

        if [[ -n "$resource_matches" ]]; then
          if [[ "$function_debug_input" == "true" ]]; then
            echo "✅ Found matching resources for type '$resource_type' with name '$resource_name':"
            echo "$resource_matches"
          fi
          while IFS= read -r match; do
            namespace=$(echo "$match" | awk '{print $1}')
            name=$(echo "$match" | awk '{print $2}')
            [[ -z "$namespace" ]] && namespace="N/A"

            # Fetch detailed status for the resource
            local resource_status
            local resource_details
            if [[ "$namespace" != "N/A" ]]; then
              resource_status=$(run_command kubectl $kubeconfig --context=$kubecontext get $resource_type $name -n $namespace -o jsonpath='{.status.phase}' 2>/dev/null)
              resource_details=$(run_command kubectl $kubeconfig --context=$kubecontext get $resource_type $name -n $namespace -o json 2>/dev/null)
            else
              resource_status=$(run_command kubectl $kubeconfig --context=$kubecontext get $resource_type $name -o jsonpath='{.status.phase}' 2>/dev/null)
              resource_details=$(run_command kubectl $kubeconfig --context=$kubecontext get $resource_type $name -o json 2>/dev/null)
            fi

            # Extract additional status details based on resource type
            local additional_status=""
            case "$resource_type" in
              "deployment"|"statefulset"|"daemonset")
                local replicas=$(echo "$resource_details" | jq -r '.status.replicas // 0')
                local ready_replicas=$(echo "$resource_details" | jq -r '.status.readyReplicas // 0')
                local updated_replicas=$(echo "$resource_details" | jq -r '.status.updatedReplicas // 0')
                additional_status="Replicas: $replicas, Ready: $ready_replicas, Updated: $updated_replicas"
                ;;
              "pod")
                local pod_status=$(echo "$resource_details" | jq -r '.status.phase')
                local container_statuses=$(echo "$resource_details" | jq -r '.status.containerStatuses[]?.ready' 2>/dev/null)
                local ready_containers=0
                local total_containers=0
                while read -r ready; do
                  ((total_containers++))
                  [[ "$ready" == "true" ]] && ((ready_containers++))
                done <<< "$container_statuses"
                additional_status="Phase: $pod_status, Containers Ready: $ready_containers/$total_containers"
                ;;
              "service")
                local service_type=$(echo "$resource_details" | jq -r '.spec.type')
                local cluster_ip=$(echo "$resource_details" | jq -r '.spec.clusterIP')
                additional_status="Type: $service_type, ClusterIP: $cluster_ip"
                ;;
              "pvc")
                local storage_class=$(echo "$resource_details" | jq -r '.spec.storageClassName')
                local capacity=$(echo "$resource_details" | jq -r '.status.capacity.storage')
                additional_status="StorageClass: $storage_class, Capacity: $capacity"
                ;;
            esac

            # Combine status information
            local status_summary="Status: ${resource_status:-Unknown}"
            [[ -n "$additional_status" ]] && status_summary+=", $additional_status"

            log_summary "$function_name - $resource_type Check - $name - $namespace" "$namespace:$name:$resource_type Check:Success:$status_summary"
          done <<< "$resource_matches"
        else
          if [[ "$function_debug_input" == "true" ]]; then
            echo "❌ No resources found for type '$resource_type' containing name '$resource_name'."
          fi
          log_summary "$function_name - $resource_type Check - $resource_name - N/A" "N/A:$resource_name:$resource_type Check:Failure:Resource not found"
        fi
      done
    done
  else
    echo "⏩ Skipping resource checks because fetch_resource_names is empty."
  fi

  # Rest of the webhook checking code remains the same...
  # [Previous webhook checking code continues here...]

  # Determine the webhook names to process
  local webhook_name_array
  if [[ "$webhooks" == "all" ]]; then
    webhook_name_array=("mutatingwebhookconfigurations" "validatingwebhookconfigurations")
  else
    IFS=',' read -r -a webhook_name_array <<< "$webhooks"
  fi

  # Perform webhook checks if fetch_webhook_names is provided
  if [[ -n "$fetch_webhook_names" ]]; then
    local mutating_webhook_names=()
    local validating_webhook_names=()
    IFS=',' read -r -a fetch_webhook_names_array <<< "$fetch_webhook_names"
    for fetch_name in "${fetch_webhook_names_array[@]}"; do
      if [[ "$fetch_name" =~ mutating ]]; then
        mutating_webhook_names+=("$fetch_name")
      elif [[ "$fetch_name" =~ validating ]]; then
        validating_webhook_names+=("$fetch_name")
      else
        mutating_webhook_names+=("$fetch_name")
        validating_webhook_names+=("$fetch_name")
      fi
    done

    for webhook_type in "${webhook_name_array[@]}"; do
      if [[ "$webhook_type" == "mutatingwebhookconfigurations" ]]; then
        for fetch_name in "${mutating_webhook_names[@]}"; do
          if [[ "$function_debug_input" == "true" ]]; then
            echo "🔍 Filtering $webhook_type for name containing '$fetch_name'..."
          fi
          local webhook_matches
          webhook_matches=$(run_command kubectl $kubeconfig --context=$kubecontext get $webhook_type -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -i "$fetch_name")

          if [[ -n "$webhook_matches" ]]; then
            if [[ "$function_debug_input" == "true" ]]; then
              echo "✅ Found $webhook_type for '$fetch_name':"
              echo "$webhook_matches"
            fi
            while IFS= read -r match; do
              # Fetch webhook status
              local webhook_details=$(run_command kubectl $kubeconfig --context=$kubecontext get $webhook_type $match -o json 2>/dev/null)
              local webhook_status="Active"  # Default status
              local webhook_rules=$(echo "$webhook_details" | jq -r '.webhooks[].rules[] | "\(.operations) on \(.resources)"' 2>/dev/null)
              
              log_summary "$function_name - $webhook_type Check - $match" "N/A:$match:$webhook_type Check:Success:Status: $webhook_status, Rules: $webhook_rules"
            done <<< "$webhook_matches"
          else
            if [[ "$function_debug_input" == "true" ]]; then
              echo "❌ No $webhook_type containing name '$fetch_name' found."
            fi
            log_summary "$function_name - $webhook_type Check - $fetch_name" "N/A:$fetch_name:$webhook_type Check:Failure:Webhook not found"
          fi
        done
      elif [[ "$webhook_type" == "validatingwebhookconfigurations" ]]; then
        # Similar logic for validating webhooks...
        for fetch_name in "${validating_webhook_names[@]}"; do
          if [[ "$function_debug_input" == "true" ]]; then
            echo "🔍 Filtering $webhook_type for name containing '$fetch_name'..."
          fi
          local webhook_matches
          webhook_matches=$(run_command kubectl $kubeconfig --context=$kubecontext get $webhook_type -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -i "$fetch_name")

          if [[ -n "$webhook_matches" ]]; then
            if [[ "$function_debug_input" == "true" ]]; then
              echo "✅ Found $webhook_type for '$fetch_name':"
              echo "$webhook_matches"
            fi
            while IFS= read -r match; do
              # Fetch webhook status
              local webhook_details=$(run_command kubectl $kubeconfig --context=$kubecontext get $webhook_type $match -o json 2>/dev/null)
              local webhook_status="Active"  # Default status
              local webhook_rules=$(echo "$webhook_details" | jq -r '.webhooks[].rules[] | "\(.operations) on \(.resources)"' 2>/dev/null)
              
              log_summary "$function_name - $webhook_type Check - $match" "N/A:$match:$webhook_type Check:Success:Status: $webhook_status, Rules: $webhook_rules"
            done <<< "$webhook_matches"
          else
            if [[ "$function_debug_input" == "true" ]]; then
              echo "❌ No $webhook_type containing name '$fetch_name' found."
            fi
            log_summary "$function_name - $webhook_type Check - $fetch_name" "N/A:$fetch_name:$webhook_type Check:Failure:Webhook not found"
          fi
        done
      fi
    done
  else
    echo "⏩ Skipping webhook checks because fetch_webhook_names is empty."
  fi

  echo "✅ Kubernetes resource and webhook checks completed."
}




# Function to log commands executed
log_command() {
  local command="$1"
  local inputs="$2"
  commands+=("$command")
  command_inputs["$command"]="$inputs"
}

# Log inputs and execution details based on a global or passed flag
log_inputs_and_time() {
  local execute_flag="${function_debug_input:-true}" # Use global flag variable, default to 'true'
  local function_name
  local start_time
  local end_time

  if [[ "$1" == "true" || "$1" == "false" ]]; then
    execute_flag="$1"             # Override global flag if passed explicitly
    function_name="$2"            # Function name
    shift 2                       # Shift to access remaining arguments
  else
    function_name="$1"            # Function name when flag is not passed
    shift                         # Shift to access remaining arguments
  fi

  if [[ "$execute_flag" != "true" ]]; then
    echo -e "🚫 Skipping logging and timing for function: $function_name (Flag set to false)"
    "$function_name" "$@" # Execute the function without logging or timing
    return 0
  fi

  echo -e "🛠️  **Starting Execution**"
  echo -e "🚀 Function: \e[1m$function_name\e[0m"

  echo -e "📦 **Parameters passed:**"
  local index=1
  for arg in "$@"; do
    echo -e "  🔸 \e[1m$index\e[0m: $arg"
    index=$((index + 1))
  done

  start_time=$(date +%s)
  "$function_name" "$@"
  end_time=$(date +%s)

  echo -e "✅ **Execution Complete**"
  echo -e "⏳ Total Time Taken: \e[1m$((end_time - start_time)) seconds\e[0m"
}



# Function to log, run commands, and continue on error
run_command() {
    local cmd="$*"
    if [[ "$function_debug_input" == "true" ]]; then
        echo -e "🔧 Running: $cmd" >&2
    fi
    local output
    output=$(eval "$cmd" 2>&1)
    local status=$?
    if [[ "$function_debug_input" == "true" ]]; then
        if [ $status -ne 0 ]; then
            echo -e "⚠️ Command failed with status: $status, continuing..." >&2
        else
            echo -e "✅ Command succeeded." >&2
        fi
    fi
    echo "$output"
    return $status
}



# Determine the correct kubectl binary
KUBECTL_BIN=$(which kubectl)


# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace-to-check) namespaces_to_check="$2"; shift 2 ;;
    --test-namespace) test_namespace="$2"; shift 2 ;;
    --test-namespace-labels) labels="$2"; shift 2 ;;
    --test-namespace-annotations) annotations="$2"; shift 2 ;;
    --pvc-test-namespace) pvc_test_namespace="$2"; shift 2 ;;
    --invoke-wrappers) wrappers_to_invoke="$2"; shift 2 ;;
    --kubeconfig) kubeconfig="--kubeconfig=$2"; shift 2 ;;
    --kubecontext) kubecontext="$2"; shift 2 ;;
    --kubecontext-list) kubecontext_list="$2"; shift 2 ;;
    --pvc-name) pvc_name="$2"; shift 2 ;;
    --storage-class) storage_class="$2"; shift 2 ;;
    --storage-size) storage_size="$2"; shift 2 ;;
    --service-name) service_name="$2"; shift 2 ;;
    --service-type) service_type="$2"; shift 2 ;;
    --watch-resources) watch_resources="$2"; shift 2 ;;
    --watch-duration) watch_duration="$2"; shift 2 ;;
    --cleanup) cleanup="$2"; shift 2 ;;
    --display-resources) display_resources="$2"; shift 2 ;;
    --global-wait) global_wait="$2"; shift 2 ;;
    --kubectl-path) KUBECTL_BIN="$2"; shift 2 ;;
    --function-debug-input) function_debug_input="$2"; shift 2 ;;
    --generate-summary) generate_summary_flag="$2"; shift 2 ;;
    --resource-action-pairs) resource_action_pairs="$2"; shift 2 ;;
    --fetch-resource-names) fetch_resource_names="$2"; shift 2 ;;
    --api-resources) api_resources="$2"; shift 2 ;;
    --webhooks) webhooks="$2"; shift 2 ;;
    --fetch-webhook-names) fetch_webhook_names="$2"; shift 2 ;;
    --help) display_help ;;
    *) echo -e "❌ Unknown parameter: $1"; display_help ;;
  esac
done

# Debug: Initial parsed values
echo "Initial kubeconfig='$kubeconfig', kubecontext='$kubecontext', kubecontext_list='$kubecontext_list'"

# Ensure kubeconfig is provided and either kubecontext or kubecontext_list is provided
if [[ -z "$kubeconfig" || ( -z "$kubecontext" && -z "$kubecontext_list" ) ]]; then
  echo -e "❌ Error: --kubeconfig is mandatory, and either --kubecontext or --kubecontext-list must be provided."
  exit 1
fi


# Preserve original values
original_kubeconfig="$kubeconfig"
original_kubecontext="$kubecontext"
original_kubecontext_list="$kubecontext_list"

# Debug: Before proceeding
echo "Debug: Preserved kubeconfig='$original_kubeconfig', kubecontext='$original_kubecontext', kubecontext_list='$original_kubecontext_list'"

# Log the kubectl binary path
echo "Using kubectl at: $KUBECTL_BIN"

# Validate kubeconfig file exists
kubeconfig_path="${original_kubeconfig#--kubeconfig=}"
if [[ ! -f "$kubeconfig_path" ]]; then
  echo "❌ Error: kubeconfig file '$kubeconfig_path' does not exist."
  exit 1
fi

# Validate kubecontext or kubecontext_list
if [[ -n "$original_kubecontext" ]]; then
  # Validate the single kubecontext
  if ! $KUBECTL_BIN --kubeconfig="$kubeconfig_path" config get-contexts "$original_kubecontext" >/dev/null 2>&1; then
    echo "❌ Error: kubecontext '$original_kubecontext' does not exist in the provided kubeconfig."
    exit 1
  fi
  echo "✅ kubecontext '$original_kubecontext' validated successfully."
elif [[ -n "$original_kubecontext_list" ]]; then
  # Validate each kubecontext in the list
  IFS=',' read -ra contexts <<< "$original_kubecontext_list"
  for ctx in "${contexts[@]}"; do
    if ! $KUBECTL_BIN --kubeconfig="$kubeconfig_path" config get-contexts "$ctx" >/dev/null 2>&1; then
      echo "❌ Error: kubecontext '$ctx' from kubecontext-list does not exist in the provided kubeconfig."
      exit 1
    fi
    echo "✅ kubecontext '$ctx' validated successfully."
  done
else
  echo "❌ Error: Neither kubecontext nor kubecontext_list is provided."
  exit 1
fi

echo "✅ kubeconfig and kubecontext(s) validated successfully."

# Log the kubectl binary path
echo "Using kubectl at: $KUBECTL_BIN"

# Global wait function
wait_after_command() {
  local wait_time="$1"
  if [[ "$wait_time" -gt 0 ]]; then
    echo -e "⏳ Waiting for $wait_time seconds..."
    sleep "$wait_time"
  fi
}

# Function to watch a resource after creation
watch_resource() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local resource_type="$3"
  local resource_name="$4"
  local namespace="$5"
  local watch_resources="$6"
  local watch_duration="${7:-30}" # Default watch duration is 30 seconds if not specified

  echo -e "🔍 Watching $resource_type '$resource_name'${namespace:+ in namespace '$namespace'} for $watch_duration seconds..."
  log_command "watch_resource" "resource_type=$resource_type, resource_name=$resource_name, namespace=$namespace, watch_duration=$watch_duration"

  local end_time=$((SECONDS + watch_duration))
  while [[ $SECONDS -lt $end_time ]]; do
    if [[ -n "$namespace" ]]; then
      run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get $resource_type $resource_name -n $namespace"
      log_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get $resource_type $resource_name -n $namespace" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace, resource_type=$resource_type, resource_name=$resource_name"
    else
      run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get $resource_type $resource_name"
       log_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get $resource_type $resource_name" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, resource_type=$resource_type, resource_name=$resource_name"
    fi
    sleep 5 # Refresh every 5 seconds
  done

  echo "🕒 Finished watching $resource_type '$resource_name'."
  #log_summary "Resource Watch - $resource_name" "Watched for $watch_duration seconds:Success"
}



# Function to display the output of resources after creation or deletion
display_resource_details() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local resource_type="$3"
  local namespace="$4"
  local resource_name="$5"
  local display_resources_flag="$6"

  if [[ "$display_resources_flag" == "true" ]]; then
    echo -e "🔍 Fetching details of $resource_type '$resource_name' in namespace '$namespace':"
    run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get $resource_type '$resource_name' -n '$namespace'"
    log_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get $resource_type '$resource_name' -n '$namespace'" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, resource_type=$resource_type, resource_name=$resource_name, namespace=$namespace"
    log_summary "Resource Details - $resource_name" "Details fetched successfully:Success"
  fi
}



# Function to check if the Kubernetes cluster is accessible
k8s_cluster_info_preflight_check() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local display_resources_flag="$3"
  local global_wait="$4"
  local watch_resources="${5:-false}"
  local watch_duration="${6:-30}"

  echo -e "🔍 Verifying K8s Cluster info..."
  log_command "k8s_cluster_info_preflight_check" "kubeconfig=$kubeconfig, kubecontext=$kubecontext"

  # Validate kubeconfig file exists
  if [[ ! -f "${kubeconfig#--kubeconfig=}" ]]; then
    echo -e "❌ Error: kubeconfig file does not exist at ${kubeconfig#--kubeconfig=}"
     log_summary "Kubernetes Cluster Access" "kubeconfig file missing:Failed"
    exit 1
  else
    echo -e "✅ kubeconfig file exists at ${kubeconfig#--kubeconfig=}"
    log_summary "Kubernetes Cluster Access" "kubeconfig file exists:Success"
  fi

  # Validate kubecontext exists in kubeconfig
  if ! run_command "$KUBECTL_BIN --kubeconfig=${kubeconfig#--kubeconfig=} --context=$kubecontext config get-contexts \"$kubecontext\" >/dev/null 2>&1"; then
    echo -e "❌ Error: kubecontext '$kubecontext' does not exist in the provided kubeconfig."
     log_summary "Kubernetes Cluster Access" "kubecontext missing:Failed"
    exit 1
  else
    echo -e "✅ kubecontext '$kubecontext' exists in the provided kubeconfig."
    log_summary "Kubernetes Cluster Access" "kubecontext exists:Success"
  fi

  # Verify cluster access
  if ! run_command "$KUBECTL_BIN --kubeconfig=${kubeconfig#--kubeconfig=} --context=$kubecontext version >/dev/null 2>&1"; then
    echo -e "❌ Error: Unable to access Kubernetes cluster. Ensure kubectl is configured correctly."
    log_summary "Kubernetes Cluster Access" "cluster access failed:Failed"
    exit 1
  else
    echo -e "✅ Successfully accessed the Kubernetes cluster using the specified kubeconfig and kubecontext."
    log_summary "Kubernetes Cluster Access" "cluster access successful:Success"
  fi

  # Retrieve and log cluster endpoint
  local cluster_endpoint
  cluster_endpoint=$(run_command "$KUBECTL_BIN --kubeconfig=\"${kubeconfig#--kubeconfig=}\" --context=\"$kubecontext\" config view --minify -o jsonpath='{.clusters[0].cluster.server}'")
  

  if [[ -n "$cluster_endpoint" ]]; then
    echo -e "💻 Cluster Endpoint: $cluster_endpoint"
    log_summary "K8S Cluster Endpoint" "$cluster_endpoint"
  else
    echo -e "❌ Failed to retrieve the cluster endpoint."
    log_summary "K8S Cluster Endpoint" "Failed to retrieve cluster endpoint"
  fi

# Fetch node details
echo -e "▶ Fetching node details..."
local node_info
node_info=$($KUBECTL_BIN --kubeconfig="${kubeconfig#--kubeconfig=}" --context="$kubecontext" get nodes -o json 2>/dev/null)

# Validate JSON output
if [[ -n "$node_info" ]] && echo "$node_info" | jq empty >/dev/null 2>&1; then
  local node_details=""
  local node_names
  node_names=$(echo "$node_info" | jq -r '.items[].metadata.name')

  for node in $node_names; do
    echo -e "\n• Node: $node"

    # Fetch details with error handling
    local labels
    labels=$($KUBECTL_BIN --kubeconfig="${kubeconfig#--kubeconfig=}" --context="$kubecontext" get node "$node" -o jsonpath='{.metadata.labels}' 2>/dev/null || echo "{}")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  💡 Labels: ${labels:-None}"
    fi
    local taints
    taints=$($KUBECTL_BIN --kubeconfig="${kubeconfig#--kubeconfig=}" --context="$kubecontext" get node "$node" -o jsonpath='{.spec.taints}' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  🚫 Taints: ${taints:-None}"
    fi
    local external_ips
    external_ips=$($KUBECTL_BIN --kubeconfig="${kubeconfig#--kubeconfig=}" --context="$kubecontext" get node "$node" -o jsonpath='{.status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  📶 External IPs: ${external_ips:-None}"
    fi
    local gpu_type
    gpu_type=$(echo "$labels" | jq -r 'to_entries[] | select(.key | test("nvidia.com/gpu.product")) | .value' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  ⚙ GPU Type: ${gpu_type:-None}"
    fi
    local cpu_architecture
    cpu_architecture=$(echo "$labels" | jq -r 'to_entries[] | select(.key == "kubernetes.io/arch") | .value' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  🛠 CPU Architecture: ${cpu_architecture:-None}"
    fi
    local instance_type
    instance_type=$(echo "$labels" | jq -r 'to_entries[] | select(.key == "node.kubernetes.io/instance-type") | .value' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  👷 Instance Type: ${instance_type:-None}"
    fi
    local capacity_cpu
    capacity_cpu=$($KUBECTL_BIN --kubeconfig="${kubeconfig#--kubeconfig=}" --context="$kubecontext" get node "$node" -o jsonpath='{.status.capacity.cpu}' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  🏋 Capacity (CPU): ${capacity_cpu:-None} cores"
    fi
    local capacity_memory
    capacity_memory=$($KUBECTL_BIN --kubeconfig="${kubeconfig#--kubeconfig=}" --context="$kubecontext" get node "$node" -o jsonpath='{.status.capacity.memory}' 2>/dev/null || echo "None")
    if [[ "$function_debug_input" == "true" ]]; then
    echo "  💾 Capacity (Memory): ${capacity_memory:-None}"
    fi

node_details+="🔹 Node: $node
  🏷️ Labels: $labels
  🚫 Taints: ${taints:-None}
  🌐 External IPs: ${external_ips:-None}
  🎮 GPU Type: ${gpu_type:-None}
  🖥️ CPU Architecture: ${cpu_architecture:-None}
  📦 Instance Type: ${instance_type:-None}
  ⚙️ Capacity (CPU): ${capacity_cpu:-None} cores
  🧠 Capacity (Memory): ${capacity_memory:-None}


"
  done

  # Add consolidated node details to the summary
  summary["Node Details"]="$node_details"
else
  echo -e "❌ Failed to fetch or parse node details."
  summary["Node Details"]="Failed to fetch node details"
fi

  # Wait for the specified time, if any
   wait_after_command "$global_wait"
}

# Add helper functions for validation
validate_k8s_name() {
  local name="$1"
  # Kubernetes names must be lowercase alphanumeric characters, '-', or '.'
  if [[ ! "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$ ]]; then
    return 1
  fi
  return 0
}

validate_k8s_label_value() {
  local value="$1"
  # Label values must be 63 characters or less
  if [[ ${#value} -gt 63 ]]; then
    return 1
  fi
  return 0
}

validate_k8s_annotation_value() {
  local value="$1"
  # Annotation values can be any valid string
  return 0
}

# Add namespace validation function
validate_namespace_name() {
  local namespace="$1"
  # Namespace names must be lowercase alphanumeric characters or '-'
  # Must start and end with alphanumeric character
  # Must be between 1 and 63 characters
  if [[ ! "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || [[ ${#namespace} -gt 63 ]]; then
    echo "❌ Error: Invalid namespace name: '$namespace'"
    echo "   - Must be lowercase alphanumeric characters or '-'"
    echo "   - Must start and end with alphanumeric character"
    echo "   - Must be between 1 and 63 characters"
    return 1
  fi
  return 0
}

create_namespace() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespace="${3:-egs-test-namespace}"
  local display_resources_flag="$4"
  local global_wait="$5"
  local watch_resources="${6:-false}"
  local watch_duration="${7:-30}"
  local function_name="create_namespace"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace"
  log_command "$function_name" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace"

  # Validate namespace name
  if ! validate_namespace_name "$namespace"; then
    echo "❌ Error: Namespace name validation failed"
    log_summary "$function_name - Namespace Validation - $namespace" "$namespace:N/A:Namespace Name Validation:Failure"
    return 1
  fi

  # Check if the namespace already exists
  echo "🔍 Checking if namespace '$namespace' exists..."
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $namespace >/dev/null 2>&1"; then
    echo -e "⚠️ Warning: Namespace '$namespace' already exists. Skipping creation."
    log_summary "$function_name - Namespace Creation - $namespace" "$namespace:N/A:Namespace Already Exists:Skipped"
  else
    # Prepare YAML with labels and annotations
    local namespace_yaml="apiVersion: v1
kind: Namespace
metadata:
  name: $namespace"

    # Add labels if provided and not empty
    if [[ -n "$labels" ]]; then
      namespace_yaml+="
  labels:"
      IFS=',' read -r -a label_pairs <<< "$labels"
      local invalid_labels=()
      
      for pair in "${label_pairs[@]}"; do
        # Skip empty pairs
        if [[ -z "$pair" ]]; then
          continue
        fi

        # Extract key and value
        local key="${pair%%=*}"
        local value="${pair#*=}"
        
        # Remove any surrounding quotes from value
        value="${value#[\"\']}"
        value="${value%[\"\']}"
        
        # Validate key
        if ! validate_k8s_name "$key"; then
          invalid_labels+=("Invalid label key format: '$key' (must be lowercase alphanumeric, '-', or '.')")
          continue
        fi
        
        # Validate value
        if ! validate_k8s_label_value "$value"; then
          invalid_labels+=("Invalid label value for '$key': value too long (max 63 characters)")
          continue
        fi
        
        namespace_yaml+="
    $key: \"$value\""
      done

      # Log invalid labels if any
      if [[ ${#invalid_labels[@]} -gt 0 ]]; then
        echo "⚠️ Warning: Some namespace labels were invalid and skipped:"
        for msg in "${invalid_labels[@]}"; do
          echo "   - $msg"
        done
      fi
    fi

    # Add annotations if provided and not empty
    if [[ -n "$annotations" ]]; then
      namespace_yaml+="
  annotations:"
      IFS=',' read -r -a annotation_pairs <<< "$annotations"
      local invalid_annotations=()
      
      for pair in "${annotation_pairs[@]}"; do
        # Skip empty pairs
        if [[ -z "$pair" ]]; then
          continue
        fi

        # Extract key and value
        local key="${pair%%=*}"
        local value="${pair#*=}"
        
        # Remove any surrounding quotes from value
        value="${value#[\"\']}"
        value="${value%[\"\']}"
        
        # Validate key
        if ! validate_k8s_name "$key"; then
          invalid_annotations+=("Invalid annotation key format: '$key' (must be lowercase alphanumeric, '-', or '.')")
          continue
        fi
        
        namespace_yaml+="
    $key: \"$value\""
      done

      # Log invalid annotations if any
      if [[ ${#invalid_annotations[@]} -gt 0 ]]; then
        echo "⚠️ Warning: Some namespace annotations were invalid and skipped:"
        for msg in "${invalid_annotations[@]}"; do
          echo "   - $msg"
        done
      fi
    fi

    # Log the YAML being applied (for debugging)
    if [[ "$function_debug_input" == "true" ]]; then
      echo "🔍 Generated namespace YAML:"
      echo "$namespace_yaml"
    fi

    # Attempt to create the namespace
    echo "🔍 Creating namespace: '$namespace'"
    if echo "$namespace_yaml" | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"; then
      echo -e "✅ Namespace '$namespace' created successfully."
      log_summary "$function_name - Namespace Creation - $namespace" "$namespace:N/A:Namespace Created:Success"

      # Display resource details if the flag is set
      if [[ "$display_resources_flag" == "true" ]]; then
        echo "🔍 Displaying details for namespace: '$namespace'"
        display_resource_details "$kubeconfig" "$kubecontext" "namespace" "$namespace" "$namespace" "$display_resources_flag"
        log_summary "$function_name - Namespace Details - $namespace" "$namespace:N/A:Namespace Details Displayed:Success"
      fi

      # Watch the namespace if enabled
      if [[ "$watch_resources" == "true" ]]; then
        echo "🔍 Watching namespace: '$namespace'"
        watch_resource "$kubeconfig" "$kubecontext" "namespace" "$namespace" "$namespace" "$watch_resources" "$watch_duration"
        log_summary "$function_name - Namespace Watch - $namespace" "$namespace:N/A:Namespace Watched:Success"
      fi
    else
      echo -e "❌ Error: Unable to create namespace '$namespace'."
      log_summary "$function_name - Namespace Creation - $namespace" "$namespace:N/A:Namespace Creation Failed:Failure"
    fi
  fi

  # Wait for the specified time, if any
  wait_after_command "$global_wait"
} 


delete_namespace() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespace="$3"
  local cleanup="$4"
  local display_resources_flag="$5"
  local global_wait="$6"
  local watch_resources="${7:-false}"          # Optional: Enable or disable watching
  local watch_duration="${8:-30}"             # Optional: Duration to watch the resource
  local function_name="delete_namespace"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace, cleanup=$cleanup"
  log_command "$function_name" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace, cleanup=$cleanup"

if [[ "$cleanup" == "true" ]]; then
  # Attempt to delete the namespace
  echo "🔍 Attempting to delete namespace: '$namespace'"
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $namespace --wait >/dev/null 2>&1"; then
    echo -e "✅ Namespace '$namespace' deleted successfully."
    log_summary "$function_name - Namespace Deletion - $namespace" "$namespace:N/A:Namespace Deletion:Success"

    # Watch the namespace deletion if enabled
    if [[ "$watch_resources" == "true" ]]; then
      echo "🔍 Watching namespace deletion: '$namespace'"
      if watch_resource "$kubeconfig" "$kubecontext" "namespace" "$namespace" "" "$watch_resources" "$watch_duration"; then
        log_summary "$function_name - Namespace Watch - $namespace" "$namespace:N/A:Namespace Deletion Watched:Success"
        echo "✅ Namespace deletion for '$namespace' was successfully watched."
      else
        log_summary "$function_name - Namespace Watch - $namespace" "$namespace:N/A:Namespace Deletion Watched:Failure"
        echo "❌ Error: Failed to watch namespace deletion for '$namespace'."
        return 1  # Exit if watching deletion fails
      fi
    fi
  else
    echo -e "❌ Error: Unable to delete namespace '$namespace'."
    log_summary "$function_name - Namespace Deletion - $namespace" "$namespace:N/A:Namespace Deletion Failed:Failure"
    return 1  # Exit if namespace deletion fails
  fi
else
  echo -e "⚠️ Deletion of namespace '$namespace' skipped due to cleanup flag."
  log_summary "$function_name - Namespace Deletion - $namespace" "$namespace:N/A:Namespace Deletion Skipped:Skipped"
fi

# Wait for the specified time, if any
wait_after_command "$global_wait"

}





namespace_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespaces_to_check="$3"
  local test_namespace="${4:-egs-test-namespace}"
  local cleanup="${5:-true}"
  local display_resources_flag="${6:-true}"
  local global_wait="${7:-0}"
  local watch_resources="${8:-false}"          # Flag to enable or disable watching
  local watch_duration="${9:-30}"             # Duration to watch the resource
  local function_name="namespace_preflight_checks"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespaces_to_check=$namespaces_to_check, test_namespace=$test_namespace, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration"

# Split the namespaces_to_check string into an array
IFS=',' read -r -a namespace_array <<< "$namespaces_to_check"
for namespace in "${namespace_array[@]}"; do
  echo "🔍 Testing namespace existence: '$namespace'"
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $namespace >/dev/null 2>&1"; then
    echo "✅ Namespace '$namespace' exists."
    log_summary "$function_name - Namespace Check - $namespace" "$namespace:N/A:Namespace Check:Success"
  else
    echo "❌ Namespace '$namespace' does not exist."
    log_summary "$function_name - Namespace Check - $namespace" "$namespace:N/A:Namespace Check:Failure"
  fi
  wait_after_command "$global_wait"
done

# Test namespace creation
echo "🔍 Testing namespace creation for: '$test_namespace'"
if create_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$display_resources_flag" "$global_wait" "$watch_resources" "$watch_duration"; then
  echo "✅ Namespace '$test_namespace' created successfully."
  log_summary "$function_name - Namespace Creation - $test_namespace" "$test_namespace:N/A:Namespace Creation:Success"
else
  echo "❌ Failed to create namespace: '$test_namespace'"
  log_summary "$function_name - Namespace Creation - $test_namespace" "$test_namespace:N/A:Namespace Creation:Failure"
  return 1  # Exit if namespace creation fails
fi

# Watch the namespace if the watch flag is enabled
if [[ "$watch_resources" == "true" ]]; then
  echo "🔍 Watching namespace: '$test_namespace'"
  if watch_resource "$kubeconfig" "$kubecontext" "namespace" "$test_namespace" "" "$watch_resources" "$watch_duration"; then
    echo "✅ Watching namespace '$test_namespace' was successful."
    log_summary "$function_name - Namespace Watch - $test_namespace" "$test_namespace:N/A:Namespace Watch:Success"
  else
    echo "❌ Failed to watch namespace: '$test_namespace'"
    log_summary "$function_name - Namespace Watch - $test_namespace" "$test_namespace:N/A:Namespace Watch:Failure"
  fi
fi

# Test namespace deletion if cleanup is enabled
if [[ "$cleanup" == "true" ]]; then
  echo "🔍 Testing namespace deletion for: '$test_namespace'"
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $test_namespace --ignore-not-found >/dev/null 2>&1"; then
    echo "✅ Namespace '$test_namespace' deleted successfully."
    log_summary "$function_name - Namespace Deletion - $test_namespace" "$test_namespace:N/A:Namespace Deletion:Success"
  else
    echo "❌ Failed to delete namespace: '$test_namespace'"
    log_summary "$function_name - Namespace Deletion - $test_namespace" "$test_namespace:N/A:Namespace Deletion:Failure"
  fi
else
  echo "⚠️ Skipping namespace deletion due to cleanup flag."
  log_summary "$function_name - Namespace Deletion - $test_namespace" "$test_namespace:N/A:Namespace Deletion Skipped:Cleanup Disabled"
fi

}

internet_access_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local test_pod_image="${3:-docker.io/aveshasystems/alpine-k8s:1.0.1}"  # Default test pod image
  local test_namespace="${4:-egs-test-namespace}"                       # Namespace for test
  local test_pod_name="${5:-internet-test-pod}"                         # Name of the test pod
  local target_urls="${6:-hub.docker.com,"https://smartscaler.nexus.aveshalabs.io"}"                   # URLs or IPs to check
  local global_wait="${7:-10}"                                          # Timeout for wget command
  local cleanup="${8:-false}"                                           # Flag to clean up resources
  local watch_resources="${9:-true}"                                    # Flag to watch the pod
  local watch_duration="${10:-30}"                                      # Duration to watch the pod
  local function_name="internet_access_preflight_checks"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_pod_image=$test_pod_image, test_namespace=$test_namespace, test_pod_name=$test_pod_name, target_urls=$target_urls, global_wait=$global_wait, cleanup=$cleanup, watch_resources=$watch_resources, watch_duration=$watch_duration"

# Check or create namespace
echo "🔍 Checking or creating namespace: '$test_namespace'"
if ! run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $test_namespace >/dev/null 2>&1"; then
  echo "⚠️ Namespace '$test_namespace' does not exist. Creating..."
  if create_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$display_resources_flag" "$global_wait" "$watch_resources" "$watch_duration"; then
    log_summary "$function_name - Namespace Creation - $test_namespace" "$test_namespace:N/A:Namespace Creation:Success"
    echo "✅ Namespace '$test_namespace' created successfully."
  else
    log_summary "$function_name - Namespace Creation - $test_namespace" "$test_namespace:N/A:Namespace Creation:Failure"
    echo "❌ Failed to create namespace '$test_namespace'."
    return 1
  fi
else
  echo "✅ Namespace '$test_namespace' exists."
  log_summary "$function_name - Namespace Check - $test_namespace" "$test_namespace:N/A:Namespace Exists:Success"
fi

# Deploy a test pod
echo "🔍 Creating test pod: '$test_pod_name'"
if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext run $test_pod_name --image=$test_pod_image --restart=Never -n $test_namespace -- sleep 3600"; then
  log_summary "$function_name - Pod Creation - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Pod Creation:Success"
else
  echo "❌ Failed to create test pod: '$test_pod_name'"
  log_summary "$function_name - Pod Creation - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Pod Creation Failed:Failure"
  return 1
fi

# Watch the pod if the watch flag is enabled
if [[ "$watch_resources" == "true" ]]; then
  echo "🔍 Watching pod: '$test_pod_name' in namespace: '$test_namespace'"
  if watch_resource "$kubeconfig" "$kubecontext" "pod" "$test_pod_name" "$test_namespace" "$watch_resources" "$watch_duration"; then
    log_summary "$function_name - Pod Watch - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Pod Watch:Success"
    echo "✅ Pod '$test_pod_name' watched successfully."
  else
    log_summary "$function_name - Pod Watch - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Pod Watch:Failure"
    echo "❌ Failed to watch pod: '$test_pod_name'"
  fi
fi

# Internet connectivity check
echo "🔍 Checking internet connectivity from pod: '$test_pod_name'"
IFS=',' read -r -a url_array <<< "$target_urls"
for url in "${url_array[@]}"; do
  echo "🔍 Testing connectivity to: '$url'"
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext exec -n $test_namespace $test_pod_name -- wget -q --spider --timeout=$global_wait $url"; then
    echo "✅ Internet connectivity to '$url' is working."
    log_summary "$function_name - Internet Connectivity - $url from Pod - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Internet Connectivity to $url:Success"
  else
    echo "❌ Failed to reach '$url' within $global_wait seconds."
    log_summary "$function_name - Internet Connectivity - $url from Pod - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Internet Connectivity to $url:Failure"
  fi
done

# Cleanup resources
if [[ "$cleanup" == "true" ]]; then
  echo "🧹 Cleaning up resources..."
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete pod $test_pod_name -n $test_namespace --ignore-not-found"; then
    log_summary "$function_name - Pod Deletion - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Pod Deletion:Success"
    echo "✅ Test pod '$test_pod_name' deleted successfully."
  else
    log_summary "$function_name - Pod Deletion - $test_pod_name in Namespace - $test_namespace" "$test_namespace:$test_pod_name:Pod Deletion Failed:Failure"
    echo "❌ Failed to delete test pod: '$test_pod_name'"
  fi

  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $test_namespace --ignore-not-found"; then
    log_summary "$function_name - Namespace Deletion - $test_namespace" "$test_namespace:N/A:Namespace Deletion:Success"
    echo "✅ Namespace '$test_namespace' deleted successfully."
  else
    log_summary "$function_name - Namespace Deletion - $test_namespace" "$test_namespace:N/A:Namespace Deletion Failed:Failure"
    echo "❌ Failed to delete namespace: '$test_namespace'"
  fi
else
  echo "⚠️ Skipping cleanup due to cleanup flag."
  log_summary "$function_name - Cleanup Skipped - $test_namespace and $test_pod_name" "$test_namespace:$test_pod_name:Cleanup Skipped:Cleanup Disabled"
fi

}






pvc_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local pvc_test_namespace="${3:-egs-test-namespace}"
  local pvc_name="${4:-egs-test-pvc}"
  local storage_class="$5"
  local storage_size="${6:-1Gi}"
  local cleanup="${7:-true}"
  local display_resources_flag="${8:-true}"
  local global_wait="${9:-0}"
  local watch_resources="${10:-false}"         
  local watch_duration="${11:-30}"   
  local function_name="pvc_preflight_checks"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, pvc_test_namespace=$pvc_test_namespace, pvc_name=$pvc_name, storage_class=$storage_class, storage_size=$storage_size, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration"
  log_command "$function_name" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, pvc_test_namespace=$pvc_test_namespace, pvc_name=$pvc_name, storage_class=$storage_class, storage_size=$storage_size, cleanup=$cleanup"

# Create namespace for PVC testing
echo "🔍 Creating namespace '$pvc_test_namespace' for PVC testing..."
if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $pvc_test_namespace >/dev/null 2>&1"; then
  # Namespace already exists
  log_summary "$function_name - Namespace for PVC Testing - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Creation:Skipped"
  echo "⚠️ Namespace '$pvc_test_namespace' already exists. Skipping creation."
else
  # Attempt to create the namespace
  if create_namespace "$kubeconfig" "$kubecontext" "$pvc_test_namespace" "$display_resources_flag" "$global_wait" "$watch_resources" "$watch_duration"; then
    log_summary "$function_name - Namespace for PVC Testing - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Creation:Success"
    echo "✅ Namespace '$pvc_test_namespace' created successfully."
  else
    log_summary "$function_name - Namespace for PVC Testing - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Creation:Failure"
    echo "❌ Error: Failed to create namespace '$pvc_test_namespace'."
    SUCCESS=false
  fi
fi


# Create the PVC
echo "🔍 Creating PVC '$pvc_name' in namespace '$pvc_test_namespace'..."
if [[ -n "$storage_class" ]]; then
  if cat <<EOF | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc_name
  namespace: $pvc_test_namespace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: $storage_size
  storageClassName: $storage_class
EOF
  then
    log_summary "$function_name - PVC Creation - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Creation with StorageClass:Success"
    echo "✅ PVC '$pvc_name' created successfully in namespace '$pvc_test_namespace' with StorageClass '$storage_class'."
  else
    log_summary "$function_name - PVC Creation - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Creation with StorageClass:Failure"
    echo "❌ Error: Failed to create PVC '$pvc_name' in namespace '$pvc_test_namespace' with StorageClass '$storage_class'."
    return 1
  fi
else
  if cat <<EOF | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc_name
  namespace: $pvc_test_namespace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: $storage_size
EOF
  then
    log_summary "$function_name - PVC Creation - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Creation without StorageClass:Success"
    echo "✅ PVC '$pvc_name' created successfully in namespace '$pvc_test_namespace' without a StorageClass."
  else
    log_summary "$function_name - PVC Creation - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Creation without StorageClass:Failure"
    echo "❌ Error: Failed to create PVC '$pvc_name' in namespace '$pvc_test_namespace' without a StorageClass."
    return 1
  fi
fi

# Check PVC status
echo "🔍 Verifying the status of PVC '$pvc_name' in namespace '$pvc_test_namespace'..."
pvc_status=$($KUBECTL_BIN $kubeconfig --context=$kubecontext get pvc $pvc_name -n $pvc_test_namespace -o jsonpath='{.status.phase}')
if [[ "$pvc_status" == "Bound" ]]; then
  echo "✅ PVC '$pvc_name' is in 'Bound' state."
  log_summary "$function_name - PVC Status Check - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Status:Bound:Success"
else
  echo "❌ PVC '$pvc_name' is in '$pvc_status' state instead of 'Bound'."
  log_summary "$function_name - PVC Status Check - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Status:$pvc_status:Failure"
  return 1
fi


  # Display the PVC details
  echo "🔍 Displaying PVC details for '$pvc_name' in namespace '$pvc_test_namespace'..."
  display_resource_details "$kubeconfig" "$kubecontext" "pvc" "$pvc_test_namespace" "$pvc_name" "$display_resources_flag"

# Watch the PVC if the watch flag is enabled
if [[ "$watch_resources" == "true" ]]; then
  echo "🔍 Checking if PVC '$pvc_name' exists in namespace '$pvc_test_namespace'..."
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get pvc $pvc_name -n $pvc_test_namespace >/dev/null 2>&1"; then
    echo "🔍 Watching PVC '$pvc_name' in namespace '$pvc_test_namespace' for $watch_duration seconds..."
    if watch_resource "$kubeconfig" "$kubecontext" "pvc" "$pvc_name" "$pvc_test_namespace" "$watch_resources" "$watch_duration"; then
      log_summary "$function_name - PVC Watch - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Watch:Success"
      echo "✅ PVC '$pvc_name' watched successfully in namespace '$pvc_test_namespace'."
    else
      log_summary "$function_name - PVC Watch - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Watch:Failure"
      echo "❌ Error: Failed to watch PVC '$pvc_name' in namespace '$pvc_test_namespace'."
      SUCCESS=false
    fi
  else
    log_summary "$function_name - PVC Watch - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Watch Skipped:Resource Not Found"
    echo "⚠️ PVC '$pvc_name' does not exist in namespace '$pvc_test_namespace'. Skipping watch."
  fi
else
  echo "⚠️ Skipping PVC watch due to watch flag being disabled."
  log_summary "$function_name - PVC Watch - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Watch Skipped:Disabled"
fi


# Delete the PVC if cleanup is enabled
if [[ "$cleanup" == "true" ]]; then
  echo "🧹 Deleting PVC '$pvc_name' in namespace '$pvc_test_namespace'..."
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get pvc $pvc_name -n $pvc_test_namespace >/dev/null 2>&1"; then
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete pvc $pvc_name -n $pvc_test_namespace --wait >/dev/null 2>&1"; then
      log_summary "$function_name - PVC Deletion - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Deletion:Success"
      echo "✅ PVC '$pvc_name' deleted successfully in namespace '$pvc_test_namespace'."
    else
      log_summary "$function_name - PVC Deletion - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Deletion:Failure"
      echo "❌ Error: Failed to delete PVC '$pvc_name' in namespace '$pvc_test_namespace'."
      SUCCESS=false
    fi
  else
    log_summary "$function_name - PVC Deletion - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Deletion Skipped:Not Found"
    echo "⚠️ PVC '$pvc_name' not found in namespace '$pvc_test_namespace'. Skipping deletion."
  fi
else
  echo "⚠️ Skipping PVC deletion due to cleanup flag."
  log_summary "$function_name - PVC Deletion - $pvc_name in Namespace - $pvc_test_namespace" "$pvc_test_namespace:$pvc_name:PVC Cleanup Skipped:Cleanup Disabled"
fi

# Delete the namespace used for PVC testing if cleanup is enabled
if [[ "$cleanup" == "true" ]]; then
  echo "🧹 Deleting namespace '$pvc_test_namespace'..."
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $pvc_test_namespace >/dev/null 2>&1"; then
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $pvc_test_namespace --wait >/dev/null 2>&1"; then
      log_summary "$function_name - Namespace Cleanup - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Cleanup:Success"
      echo "✅ Namespace '$pvc_test_namespace' deleted successfully."
    else
      log_summary "$function_name - Namespace Cleanup - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Cleanup:Failure"
      echo "❌ Error: Failed to delete namespace '$pvc_test_namespace'."
      SUCCESS=false
    fi
  else
    log_summary "$function_name - Namespace Cleanup - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Cleanup Skipped:Not Found"
    echo "⚠️ Namespace '$pvc_test_namespace' not found. Skipping deletion."
  fi
else
  echo "⚠️ Skipping namespace deletion due to cleanup flag."
  log_summary "$function_name - Namespace Cleanup - $pvc_test_namespace" "$pvc_test_namespace:N/A:Namespace Cleanup Skipped:Cleanup Disabled"
fi

}





service_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local test_namespace="${3:-egs-test-namespace}"
  local cleanup="${4:-true}"
  local display_resources_flag="${5:-true}"
  local global_wait="${6:-0}"
  local service_name="${7:-egs-test-service}"  # Base name for services
  local service_type="${8:-all}"              # Parameter for specific service type
  local watch_resources="${9:-false}"         # Flag to enable or disable watching
  local watch_duration="${10:-30}"            # Duration to watch the resource
  local function_name="service_preflight_checks"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, cleanup=$cleanup, display_resources=$display_resources_flag, service_name=$service_name, service_type=${service_type:-all}, watch_resources=$watch_resources, watch_duration=$watch_duration"
  log_command "$function_name" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, service_name=$service_name, service_type=$service_type, cleanup=$cleanup"

echo "🔍 Creating namespace '$test_namespace' for service testing..."
if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $test_namespace >/dev/null 2>&1"; then
  # Namespace already exists
  log_summary "$function_name - Namespace for Service Testing - $test_namespace" "$test_namespace:N/A:Namespace Creation:Skipped"
  echo "⚠️ Namespace '$test_namespace' already exists. Skipping creation."
else
  # Attempt to create the namespace
  if create_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$display_resources_flag" "$global_wait" "$watch_resources" "$watch_duration"; then
    log_summary "$function_name - Namespace for Service Testing - $test_namespace" "$test_namespace:N/A:Namespace Creation:Success"
    echo "✅ Namespace '$test_namespace' created successfully."
  else
    log_summary "$function_name - Namespace for Service Testing - $test_namespace" "$test_namespace:N/A:Namespace Creation:Failure"
    echo "❌ Error: Failed to create namespace '$test_namespace'."
    SUCCESS=false
  fi
fi


  local SUCCESS=true

  # Function to test a specific service type
  test_service_type() {
    local type="$1"
    local yaml="$2"
    local name="$3"   # Unique service name

echo "🔍 Testing $type service creation with name $name..."
if echo "$yaml" | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"; then
  echo "✅ $type service '$name' created successfully."
  log_summary "$function_name - Service Creation - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Creation:Success"
  display_resource_details "$kubeconfig" "$kubecontext" "service" "$test_namespace" "$name" "$display_resources_flag"

  # Watch the resource if the watch flag is enabled
  if [[ "$watch_resources" == "true" ]]; then
    echo "🔍 Watching $type service '$name' in namespace '$test_namespace' for $watch_duration seconds..."
    if watch_resource "$kubeconfig" "$kubecontext" "service" "$name" "$test_namespace" "$watch_resources" "$watch_duration"; then
      log_summary "$function_name - Service Watch - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Watch:Success"
      echo "✅ $type service '$name' successfully watched in namespace '$test_namespace'."
    else
      log_summary "$function_name - Service Watch - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Watch:Failure"
      echo "❌ Error: Failed to watch $type service '$name' in namespace '$test_namespace'."
      SUCCESS=false
    fi
  else
    echo "⚠️ Skipping watch for $type service '$name' as the watch flag is disabled."
    log_summary "$function_name - Service Watch - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Watch Skipped:Disabled"
  fi
else
  echo "❌ Error: Failed to create $type service '$name'."
  log_summary "$function_name - Service Creation - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Creation:Failure"
  SUCCESS=false
fi


# Clean up the resource if cleanup flag is true
if [[ "$cleanup" == "true" ]]; then
  echo "🧹 Cleaning up $type service '$name' in namespace '$test_namespace'..."
  
  # Check if the service exists
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get service $name -n $test_namespace >/dev/null 2>&1"; then
    # Attempt to delete the service
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete service $name -n $test_namespace --ignore-not-found"; then
      log_summary "$function_name - Service Deletion - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Deletion:Success"
      echo "✅ $type service '$name' deleted successfully."
    else
      log_summary "$function_name - Service Deletion - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Deletion:Failure"
      echo "❌ Error: Failed to delete $type service '$name' in namespace '$test_namespace'."
      SUCCESS=false
    fi
  else
    # Service does not exist
    log_summary "$function_name - Service Deletion - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Deletion Skipped:Service Not Found"
    echo "⚠️ $type service '$name' not found in namespace '$test_namespace'. Skipping deletion."
  fi
else
  echo "⚠️ Cleanup for $type service '$name' skipped as cleanup flag is set to false."
  log_summary "$function_name - Service Deletion - $name in Namespace - $test_namespace" "$test_namespace:$name:$type Service Cleanup Skipped:Cleanup Disabled"
fi

    wait_after_command "$global_wait"
  }

  # Define YAML templates for each service type
  local SERVICE_YAML_CLUSTERIP="apiVersion: v1
kind: Service
metadata:
  name: ${service_name}-clusterip
  namespace: $test_namespace
spec:
  selector:
    app: test
  ports:
    - protocol: TCP
      port: 80
"

  local SERVICE_YAML_NODEPORT="apiVersion: v1
kind: Service
metadata:
  name: ${service_name}-nodeport
  namespace: $test_namespace
spec:
  type: NodePort
  selector:
    app: test
  ports:
    - protocol: TCP
      port: 80
"

  local SERVICE_YAML_LOADBALANCER="apiVersion: v1
kind: Service
metadata:
  name: ${service_name}-loadbalancer
  namespace: $test_namespace
spec:
  type: LoadBalancer
  selector:
    app: test
  ports:
    - protocol: TCP
      port: 80
"

  # Determine which service types to test
  if [[ -z "$service_type" || "$service_type" == "all" ]]; then
    # Test all service types
    test_service_type "ClusterIP" "$SERVICE_YAML_CLUSTERIP" "${service_name}-clusterip"
    test_service_type "NodePort" "$SERVICE_YAML_NODEPORT" "${service_name}-nodeport"
    test_service_type "LoadBalancer" "$SERVICE_YAML_LOADBALANCER" "${service_name}-loadbalancer"
  else
    # Test specific service type
    case "$service_type" in
      ClusterIP)
        test_service_type "ClusterIP" "$SERVICE_YAML_CLUSTERIP" "${service_name}-clusterip"
        ;;
      NodePort)
        test_service_type "NodePort" "$SERVICE_YAML_NODEPORT" "${service_name}-nodeport"
        ;;
      LoadBalancer)
        test_service_type "LoadBalancer" "$SERVICE_YAML_LOADBALANCER" "${service_name}-loadbalancer"
        ;;
      *)
        echo "❌ Error: Invalid service type '$service_type'. Valid types are ClusterIP, NodePort, LoadBalancer, or all."
        log_summary "$function_name - Namespace Cleanup - Error: Invalid service type '$service_type'. Valid types are ClusterIP, NodePort, LoadBalancer, or all."
        ;;
    esac
  fi

# Clean up namespace if cleanup flag is true
if [[ "$cleanup" == "true" ]]; then
  echo "🧹 Cleaning up namespace '$test_namespace'..."
  
  # Check if the namespace exists
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $test_namespace >/dev/null 2>&1"; then
    # Attempt to delete the namespace
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $test_namespace --wait >/dev/null 2>&1"; then
      log_summary "$function_name - Namespace Cleanup - $test_namespace" "$test_namespace:N/A:Namespace Cleanup:Success"
      echo "✅ Namespace '$test_namespace' deleted successfully."
    else
      log_summary "$function_name - Namespace Cleanup - $test_namespace" "$test_namespace:N/A:Namespace Cleanup:Failure"
      echo "❌ Error: Failed to delete namespace '$test_namespace'."
      SUCCESS=false
    fi
  else
    # Namespace does not exist
    log_summary "$function_name - Namespace Cleanup - $test_namespace" "$test_namespace:N/A:Namespace Cleanup Skipped:Namespace Not Found"
    echo "⚠️ Namespace '$test_namespace' not found. Skipping deletion."
  fi
else
  echo "⚠️ Namespace cleanup skipped as cleanup flag is set to false."
  log_summary "$function_name - Namespace Cleanup - $test_namespace" "$test_namespace:N/A:Namespace Cleanup Skipped:Cleanup Disabled"
fi


  # Final status
  if [ "$SUCCESS" = true ]; then
    echo "✅ Service preflight checks completed successfully."
  else
    echo "❌ Service preflight checks encountered errors."
  fi
}


k8s_privilege_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local resource_action_pairs="${3:-$default_resource_action_pairs}"
  local test_resource="${4:-clusterrole}"
  local cleanup="${5:-true}"
  local display_resources_flag="${6:-true}"
  local global_wait="${7:-0}"
  local watch_resources="${8:-false}"
  local watch_duration="${9:-30}"
  local function_name="k8s_privilege_preflight_checks"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, resource_action_pairs=$resource_action_pairs, test_resource=$test_resource, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration"

  # Split the resource_action_pairs string into an array
  IFS=',' read -r -a pair_array <<< "$resource_action_pairs"

  for pair in "${pair_array[@]}"; do
    local resource=$(echo "$pair" | cut -d':' -f1)
    local action=$(echo "$pair" | cut -d':' -f2)
    local namespace="N/A" # Default as no specific namespace is associated in this context

    echo "🔍 Testing privilege for action '$action' on resource '$resource'"

    # Perform the privilege check
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext auth can-i $action $resource >/dev/null 2>&1"; then
      echo -e "✅ Privilege exists for action '$action' on resource '$resource'."
      log_summary "$function_name - $resource:$action" "$namespace $resource $action Privilege Check:Success"
    else
      echo -e "❌ Privilege missing for action '$action' on resource '$resource'."
      log_summary "$function_name - $resource:$action" "$namespace $resource $action Privilege Check:Failure"
    fi

    wait_after_command "$global_wait"
  done
}







# Function to display the summary of parameters
print_summary() {
  if [[ "$function_debug_input" == "true" ]]; then
  echo "--- Parameter Summary ---"
  echo -e "🔹 Namespace to check: ${namespaces_to_check:-Not provided}"
  echo -e "🔹 Test namespace: ${test_namespace:-egs-test-namespace}"
  echo -e "🔹 PVC test namespace: ${pvc_test_namespace:-egs-test-namespace}"
  echo -e "🔹 PVC name: ${pvc_name:-egs-test-pvc}"
  echo -e "🔹 Storage class: ${storage_class:-Not provided}"
  echo -e "🔹 Storage size: ${storage_size:-1Gi}"
  echo -e "🔹 Service name: ${service_name:-test-service}"
  echo -e "🔹 Service type: ${service_type:-all}"
  echo -e "🔹 Kubeconfig: ${kubeconfig:-Not provided}"
  echo -e "🔹 Kubecontext: ${kubecontext:-Not provided}"
  echo -e "🔹 Kubecontext list: ${kubecontext_list:-Not provided}"
  echo -e "🔹 Cleanup flag: ${cleanup:-true}"
  echo -e "🔹 Wrappers to invoke: ${wrappers_to_invoke:-Not provided}"
  echo -e "🔹 Resource-action pairs: ${resource_action_pairs:-Default set}"
  echo -e "🔹 Fetch resource names: ${fetch_resource_names:-Not provided}"
  echo -e "🔹 Fetch webhook names: ${fetch_webhook_names:-Not provided}"
  echo "-------------------------"
  fi

}

# Main execution
main() {

    if [[ "$function_debug_input" == "true" ]]; then
    echo "Entering main with arguments: $@"
    fi

    # Process command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --namespace-to-check)
                namespaces_to_check="$2"
                shift 2
                ;;
            --test-namespace)
                test_namespace="$2"
                shift 2
                ;;
            --test-namespace-labels)
                labels="$2"
                shift 2
                ;;
            --test-namespace-annotations)
                annotations="$2"
                shift 2
                ;;
            --pvc-test-namespace)
                pvc_test_namespace="$2"
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
                kubecontext="$2"
                shift 2
                ;;
            --kubecontext-list)
                kubecontext_list="$2"
                shift 2
                ;;
            --pvc-name)
                pvc_name="$2"
                shift 2
                ;;
            --storage-class)
                storage_class="$2"
                shift 2
                ;;
            --storage-size)
                storage_size="$2"
                shift 2
                ;;
            --service-name)
                service_name="$2"
                shift 2
                ;;
            --service-type)
                service_type="$2"
                shift 2
                ;;
            --cleanup)
                cleanup="$2"
                shift 2
                ;;
            --display-resources)
                display_resources="$2"
                shift 2
                ;;
            --global-wait)
                global_wait="$2"
                shift 2
                ;;
            --watch-resources)
                watch_resources="$2"
                shift 2
                ;;
            --watch-duration)
                watch_duration="$2"
                shift 2
                ;;
            --generate-summary)
                generate_summary_flag="$2"
                shift 2
                ;;
            --kubectl-path)
                KUBECTL_BIN="$2"
                shift 2
                ;;
            --api-resources)
                api_resources="$2"
                shift 2
                ;;
            --webhooks)
                webhooks="$2"
                shift 2
                ;;
            --fetch-webhook-names)
                fetch_webhook_names="$2"
                shift 2
                ;;
            --function-debug-input)
                function_debug_input="$2"
                shift 2
                ;;
            --resource-action-pairs)
                resource_action_pairs="$2"
                shift 2
                ;;
            --fetch-resource-names)
                fetch_resource_names="$2"
                shift 2
                ;;
            --help)
                display_help
                exit 0
                ;;
            *)
                echo -e "❌ Unknown parameter: $1"
                display_help
                exit 1
                ;;
        esac
    done


if [[ "$function_debug_input" == "true" ]]; then
    # Print final values (debugging)
    echo "--- Final Parameter Values ---"
    echo "🔹 namespaces_to_check: ${namespaces_to_check:-Not provided}"
    echo "🔹 test_namespace: ${test_namespace:-egs-test-namespace}"
    echo "🔹 pvc_test_namespace: ${pvc_test_namespace:-egs-test-namespace}"
    echo "🔹 wrappers_to_invoke: ${wrappers_to_invoke:-Not provided}"
    echo "🔹 kubeconfig: ${kubeconfig:-Not provided}"
    echo "🔹 kubecontext: ${kubecontext:-Not provided}"
    echo "🔹 kubecontext_list: ${kubecontext_list:-Not provided}"
    echo "🔹 pvc_name: ${pvc_name:-egs-test-pvc}"
    echo "🔹 storage_class: ${storage_class:-Not provided}"
    echo "🔹 storage_size: ${storage_size:-1Gi}"
    echo "🔹 service_name: ${service_name:-egs-test-service}"
    echo "🔹 service_type: ${service_type:-all}"
    echo "🔹 cleanup: ${cleanup:-true}"
    echo "🔹 display_resources: ${display_resources:-Not provided}"
    echo "🔹 watch_resources: ${watch_resources:-Not provided}"
    echo "🔹 watch_duration: ${watch_duration:-Not provided}"
    echo "🔹 global_wait: ${global_wait:-Not provided}"
    echo "🔹 KUBECTL_BIN: ${KUBECTL_BIN:-Not provided}"
    echo "🔹 function_debug_input: ${function_debug_input:-Not provided}"
    echo "🔹 generate_summary_flag: ${generate_summary_flag:-Not provided}"
    echo "🔹 resource_action_pairs: ${resource_action_pairs:-Default set}"
    echo "🔹 fetch_resource_names: ${fetch_resource_names:-Not provided}"
    echo "🔹 api_resources: ${api_resources:-Default set}"
    echo "🔹 webhooks: ${webhooks:-Not provided}"
    echo "🔹 fetch_webhook_names: ${fetch_webhook_names:-Not provided}"
    echo "-------------------------------"
fi


# Handle wrappers_to_invoke
invoke_wrappers() {
    local kubeconfig="$1"
    local kubecontext="$2"
    local wrappers_to_invoke="$3"

    echo "⚙️  Invoking wrappers for kubecontext: $kubecontext"

# Handle wrappers_to_invoke
if [[ -n "$wrappers_to_invoke" ]]; then
    IFS=',' read -r -a wrappers <<< "$wrappers_to_invoke"
    for wrapper in "${wrappers[@]}"; do
        case "$wrapper" in
            k8s_privilege_preflight_checks)
                log_inputs_and_time "$function_debug_input" k8s_privilege_preflight_checks "$kubeconfig" "$kubecontext" "$resource_action_pairs" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
                ;;
            namespace_preflight_checks)
                log_inputs_and_time "$function_debug_input" namespace_preflight_checks "$kubeconfig" "$kubecontext" "$namespaces_to_check" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
                ;;
            pvc_preflight_checks)
                log_inputs_and_time "$function_debug_input" pvc_preflight_checks "$kubeconfig" "$kubecontext" "$pvc_test_namespace" "$pvc_name" "$storage_class" "$storage_size" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
                ;;
            service_preflight_checks)
                log_inputs_and_time "$function_debug_input" service_preflight_checks "$kubeconfig" "$kubecontext" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$service_name" "$service_type" "$watch_resources" "$watch_duration"
                ;;
            grep_k8s_resources_with_crds_and_webhooks)
                log_inputs_and_time "$function_debug_input" grep_k8s_resources_with_crds_and_webhooks "$kubeconfig" "$kubecontext" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration" "$fetch_resource_names" "$api_resources" "$webhooks" "$fetch_webhook_names"
                ;;
            internet_access_preflight_checks)
                 log_inputs_and_time "$function_debug_input" internet_access_preflight_checks "$kubeconfig" "$kubecontext" "$test_pod_image" "$test_namespace" "$test_pod_name" "$target_urls" "$global_wait" "$cleanup" "$watch_resources" "$watch_duration"
                ;;
            *)
                echo "❌ Unknown wrapper: $wrapper"
                exit 1
                ;;
        esac
    done
else
    echo "🔍 Executing all preflight checks by default"
    log_inputs_and_time "$function_debug_input" k8s_privilege_preflight_checks "$kubeconfig" "$kubecontext" "$resource_action_pairs" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
   log_inputs_and_time "$function_debug_input" namespace_preflight_checks "$kubeconfig" "$kubecontext" "$namespaces_to_check" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
   log_inputs_and_time "$function_debug_input" pvc_preflight_checks "$kubeconfig" "$kubecontext" "$pvc_test_namespace" "$pvc_name" "$storage_class" "$storage_size" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
    log_inputs_and_time "$function_debug_input" service_preflight_checks "$kubeconfig" "$kubecontext" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$service_name" "$service_type" "$watch_resources" "$watch_duration"
    log_inputs_and_time "$function_debug_input" grep_k8s_resources_with_crds_and_webhooks "$kubeconfig" "$kubecontext" "$test_namespace" "$cleanup" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration" "$fetch_resource_names" "$api_resources" "$webhooks" "$fetch_webhook_names"
    log_inputs_and_time "$function_debug_input" internet_access_preflight_checks "$kubeconfig" "$kubecontext" "$test_pod_image" "$test_namespace" "$test_pod_name" "$target_urls" "$global_wait" "$cleanup" "$watch_resources" "$watch_duration"
fi

}
# Handle kubecontext or kubecontext_list
if [[ -n "$kubecontext" ]]; then
    echo "⚙️  Invoking wrappers for single kubecontext: $kubecontext"
    invoke_wrappers "$kubeconfig" "$kubecontext" "$wrappers_to_invoke"
elif [[ -n "$kubecontext_list" ]]; then
    IFS=',' read -r -a contexts <<< "$kubecontext_list"
    for ctx in "${contexts[@]}"; do
        echo "⚙️  Invoking wrappers for kubecontext: $ctx"
        invoke_wrappers "$kubeconfig" "$ctx" "$wrappers_to_invoke"
    done
else
    echo "❌ Error: Neither kubecontext nor kubecontext_list is provided."
    exit 1
fi

}

echo "📋 Verifying pre-requisites..."
 log_inputs_and_time "$function_debug_input" prerequisite_check

# Verify input summary
echo "📋 Verifying input summary..."
 log_inputs_and_time "$function_debug_input" print_summary

# Verify kubeconfig and kubecontext/kubecontext-list
echo "🔍 Verifying kubeconfig and kubecontext access..."
if [[ -n "$kubecontext" ]]; then
  log_inputs_and_time "$function_debug_input" k8s_cluster_info_preflight_check "$kubeconfig" "$kubecontext" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
elif [[ -n "$kubecontext_list" ]]; then
  IFS=',' read -ra contexts <<< "$kubecontext_list"
  for ctx in "${contexts[@]}"; do
    echo "🔍 Checking kubecontext: $ctx"
    log_inputs_and_time "$function_debug_input" k8s_cluster_info_preflight_check "$kubeconfig" "$ctx" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"
  done
else
  echo "❌ Error: Neither kubecontext nor kubecontext_list is provided."
  exit 1
fi

# Debugging the passed arguments
echo "🐞 Debug: Arguments passed to the script: $@"
 log_inputs_and_time "$function_debug_input" main "$@"


# Verify kubeconfig and kubecontext/kubecontext-list
echo "🔍 Verifying kubeconfig and kubecontext access..."
if [[ -n "$kubecontext" ]]; then
  # Invoke generate summary at the end
echo "📊 Generating final summary..."
 log_inputs_and_time "$function_debug_input" generate_summary "$kubecontext"
elif [[ -n "$kubecontext_list" ]]; then
  IFS=',' read -ra contexts <<< "$kubecontext_list"
  for ctx in "${contexts[@]}"; do
   # Invoke generate summary at the end
    echo "📊 Generating final summary for $ctx"
    log_inputs_and_time "$function_debug_input" generate_summary "$ctx"
  done
else
  echo "❌ Error: Neither kubecontext nor kubecontext_list is provided."
  exit 1
fi



echo "=======================EGS Preflight Check Script execution completed at: $(date)============================" >> "$output_file"
