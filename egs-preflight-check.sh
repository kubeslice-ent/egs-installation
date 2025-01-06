#!/bin/bash



# Specify the output file
output_file="egs-preflight-check-output.log"
exec > >(tee -a "$output_file") 2>&1

echo "=====================================EGS Preflight Check Script execution started at: $(date)===================================" >> "$output_file"
# Global default values
namespaces_to_check="kubeslice-controller,kubeslice-system,kubeslice-avesha"
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
global_wait="4"
KUBECTL_BIN=$(which kubectl)
service_type="all"
service_name="egs-test-service"
watch_resources="true"
watch_duration="15"
function_debug_input="false"
generate_summary_flag="true"
fetch_resource_names="prometheus,gpu-operator"
#fetch_resource_names=""
#fetch_webhook_names="aiops-mutating-webhook-configuration,kubeslice-mutating-webhook-configuration,prometheus-kube-prometheus-admission,aiops-validating-webhook-configuration,gpr-validating-webhook-configuration,kubeslice-controller-validating-webhook-configuration,kubeslice-validating-webhook-configuration,prometheus-kube-prometheus-admission"
#fetch_webhook_names=""
# Global default resource_action_pairs
resource_action_pairs="namespace:create,namespace:delete,namespace:get,namespace:list,pod:create,pod:delete,pod:list,service:create,watch,configmap:create,configmap:get,configmap:list,configmap:watch,secret:create,secret:list,secret:watch,serviceaccount:create,serviceaccount:list,clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list,clusterrolebinding:create,clusterrolebinding:get,clusterrolebinding:list,deployment:create,deployment:delete,deployment:get,deployment:list,deployment"
#resource_action_pairs="namespace:create,namespace:delete,namespace:get,namespace:list,namespace:watch,pod:create,pod:delete,pod:get,pod:list,pod:watch,service:create,service:delete,service:get,service:list,service:watch,configmap:create,configmap:delete,configmap:get,configmap:list,configmap:watch,secret:create,secret:delete,secret:get,secret:list,secret:watch,serviceaccount:create,serviceaccount:delete,serviceaccount:get,serviceaccount:list,serviceaccount:watch,clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list,clusterrolebinding:create,clusterrolebinding:delete,clusterrolebinding:get,clusterrolebinding:list,deployment:create,deployment:delete,deployment:get,deployment:list,deployment:watch,statefulset:create,statefulset:delete,statefulset:get,statefulset:list,statefulset:watch"
webhooks="all"
# Define all API resources as a single variable
#api_resources="namespace,pod,daemonset,job,service,serviceaccount,ingress,configmap,secret,persistentvolume,persistentvolumeclaim,storageclass,clusterrole,clusterrolebinding,role,rolebinding,event"
api_resources="namespace,pod,daemonset,service,persistentvolume,persistentvolumeclaim"



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
  echo -e "  📂  --pvc-test-namespace <namespace>                Namespace for PVC test creation and deletion (default: egs-test-namespace)."
  echo -e "  🛠️  --pvc-name <name>                               Name of the test PVC (default: egs-test-pvc)."
  echo -e "  🗄️  --storage-class <class>                         Storage class for the PVC (default: none)."
  echo -e "  📦  --storage-size <size>                           Storage size for the PVC (default: 1Gi)."
  echo -e "  📌  --service-name <name>                           Name of the test service (default: test-service)."
  echo -e "  ⚙️  --service-type <type>                            Type of service to create and validate (ClusterIP, NodePort, LoadBalancer, or all). Default: all."
  echo -e "  🗂️  --kubeconfig <path>                             Path to the kubeconfig file (mandatory)."
  echo -e "  🌐  --kubecontext <context>                         Context from the kubeconfig file (mandatory)."
  echo -e "  🧹  --cleanup <true|false>                          Whether to delete test resources (default: true)."
  echo -e "  ⏳  --global-wait <seconds>                         Time to wait after each command execution (default: 0)."
  echo -e "  👀  --watch-resources <true|false>                  Enable or disable watching resources after creation (default: false)."
  echo -e "  ⏱️  --watch-duration <seconds>                      Duration to watch resources after creation (default: 30 seconds)."
  echo -e "  🛠️  --invoke-wrappers <wrapper1,wrapper2,...>       Comma-separated list of wrapper functions to invoke."
  echo -e "  👁️  --display-resources <true|false>                Whether to display resources created (default: true)."
  echo -e "  ⚡  --kubectl-path <path>                            Override default kubectl binary path."
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
  🗂️  grep_k8s_resources_with_crds_and_webhooks      Validates existing resources available in cluster based on resource names. (prometheus,gpu-operator,postgresql)
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


# Function to add summary details
log_summary() {
  local key="$1"
  local value="$2"
  summary["$key"]="$value"
}


# Function to generate a summary
generate_summary() {
  if [ "$generate_summary_flag" == "true" ]; then
    # Display Inputs Used
    echo -e "\n📥 ====================== INPUTS USED ==============================================="
    printf "| %-30s | %-50s |\n" "🔧 Input Parameter" "🔢 Value"
    echo "------------------------------------------------------------------------------------------"
    printf "| %-30s | %-50s |\n" "Namespaces to Check" "${namespaces_to_check:-None}"
    printf "| %-30s | %-50s |\n" "Test Namespace" "${test_namespace:-egs-test-namespace}"
    printf "| %-30s | %-50s |\n" "PVC Test Namespace" "${pvc_test_namespace:-egs-test-namespace}"
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
    echo -e "\n📊 ====================== KUBERNETES CLUSTER DETAILS =========================================================================================================================================================================================="
    printf "| %-30s | %-50s |\n" "🔧 Parameter" "📦 Value"
    echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
    printf "| %-30s | %-50s |\n" "🔧 Kubeconfig" "${kubeconfig:-None}"
    printf "| %-30s | %-50s |\n" "🌐 Kubecontext" "${kubecontext:-default-context}"
    printf "| %-30s | %-50s |\n" "📡 Cluster Endpoint" "$(echo "${summary[K8S Cluster Endpoint]:-❌ Missing}" | grep -oE 'https?://[^ ]+')"
    printf "| %-30s | %-50s |\n" "🔒 Cluster Access" "${summary[Kubernetes Cluster Access]:-❌ Missing}"

    echo -e "\n📊 ====================== KUBERNETES NODE DETAILS =========================================================================================================================================================================================="

    printf "| %-30s | %-500s |\n" "📊 Node Details" "${summary[Node Details]:-❌ Missing}"

    echo "================================ END OF KUBERNETES CLUSTER DETAILS================================================================================================================================================================================="

      declare -A grouped_results
      declare -A unspecified_results
      declare -A privilege_checks

      # Loop through all summary keys and categorize
      for key in "${!summary[@]}"; do
        # Extract details
        resource_name=$(echo "$key" | awk -F' - ' '{print $2}')
        function_type=$(echo "$key" | awk -F' ' '{print $NF " Check"}')
        parameter_function=$(echo "$key" | awk -F' - ' '{print $1}' | sed "s/ $function_type//")
        status=$(echo "${summary[$key]##*:}")
        found_status=$([[ "$status" == "Success" ]] && echo "Found" || echo "Notfound")
        icon=$([[ "$status" == "Success" ]] && echo "✅" || echo "⚠️")

        # Identify and group Privilege Checks separately
        if [[ "$function_type" == "Privilege Check" ]]; then
          privilege_checks["$resource_name"]+="$parameter_function|$found_status|$status|$icon;"
        elif [[ -n "$resource_name" ]]; then
          grouped_results["$resource_name"]+="$parameter_function|$found_status|$status|$icon;"
        else
          unspecified_results["$parameter_function"]="$found_status|$status|$icon"
        fi
      done

      # # Display Privilege Check results
      # if [[ ${#privilege_checks[@]} -gt 0 ]]; then
      #   echo -e "\n📊 ====================== VALIDATION SUMMARY FOR PRIVILEGE CHECKS ======================="
      #   printf "| %-51s | %-15s | %-18s | %-5s |\n" "Resource Name" "Found/Notfound" "📈 Status" "✔/✖"
      #   echo "-----------------------------------------------------------------------------------------------"
      #   for resource_name in "${!privilege_checks[@]}"; do
      #     IFS=';' read -ra entries <<< "${privilege_checks[$resource_name]}"
      #     for entry in "${entries[@]}"; do
      #       IFS='|' read -r parameter_function found_status status icon <<< "$entry"
      #       printf "| %-51s | %-15s | %-18s | %-5s |\n" "$resource_name" "$found_status" "$status" "$icon"
      #     done
      #   done
      #   echo "=================================================================================================="
      # fi

      # Display grouped results
      for resource_name in "${!grouped_results[@]}"; do
        echo -e "\n📊 ====================== VALIDATION SUMMARY FOR RESOURCE: $resource_name ==========================="
        printf "| %-51s | %-15s | %-18s | %-5s |\n" "Parameter/Function" "Found/Notfound" "📈 Status" "✔/✖"
        echo "-------------------------------------------------------------------------------------------------"
        IFS=';' read -ra entries <<< "${grouped_results[$resource_name]}"
        for entry in "${entries[@]}"; do
          IFS='|' read -r parameter_function found_status status icon <<< "$entry"
          printf "| %-51s | %-15s | %-18s | %-5s |\n" "$parameter_function" "$found_status" "$status" "$icon"
        done
        echo "===================================================================================================="
      done

      # # Display unspecified results
      # if [[ ${#unspecified_results[@]} -gt 0 ]]; then
      #   echo -e "\n📊 ====================== VALIDATION SUMMARY FOR UNSPECIFIED RESULTS ================================"
      #   printf "| %-51s | %-15s | %-18s | %-5s |\n" "Parameter/Function" "Found/Notfound" "📈 Status" "✔/✖"
      #   echo "------------------------------------------------------------------------------------------------------------"
      #   for key in "${!unspecified_results[@]}"; do
      #     IFS='|' read -r found_status status icon <<< "${unspecified_results[$key]}"
      #     printf "| %-51s | %-15s | %-18s | %-5s |\n" "$key" "$found_status" "$status" "$icon"
      #   done
      #   echo "=============================================================================================================="
      # fi


  else
    echo "📋 Summary generation is disabled."
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

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration, fetch_resource_names=$fetch_resource_names, api_resources=$api_resources, webhooks=$webhooks, fetch_webhook_names=$fetch_webhook_names"
  log_command "grep_k8s_resources_with_crds_and_webhooks" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, cleanup=$cleanup"

  # Determine the resource names to process
  local resource_name_array
  if [[ "$api_resources" == "all" ]]; then
    echo "🌍 Fetching all API resources from the cluster..."
    resource_name_array=($(run_command kubectl $kubeconfig --context=$kubecontext api-resources --no-headers --all-namespaces | awk '{print $1}' | tr '\n' ' '))
    if [[ ${#resource_name_array[@]} -eq 0 ]]; then
      echo "❌ Failed to fetch API resources. Ensure your Kubernetes context is valid."
      log_summary "API Resources Check" "Not Found:Failure"
      return 1
    fi
  else
    IFS=',' read -r -a resource_name_array <<< "$api_resources"
  fi

  # Perform resource checks if fetch_resource_names is provided
  if [[ -n "$fetch_resource_names" ]]; then
    for resource_type in "${resource_name_array[@]}"; do
      local resource_summary=""
      if [[ "$function_debug_input" == "true" ]]; then
      echo -e "\n🔍 Searching for resource type: $resource_type"
      fi
      IFS=',' read -r -a fetch_names_array <<< "$fetch_resource_names"
      for resource_name in "${fetch_names_array[@]}"; do
       if [[ "$function_debug_input" == "true" ]]; then
        echo "🔍 Filtering for resource type '$resource_type' with name containing '$resource_name'..."
        fi
        local resource_matches
        resource_matches=$(run_command kubectl $kubeconfig --context=$kubecontext get $resource_type --all-namespaces -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -i "$resource_name")

        if [[ -n "$resource_matches" ]]; then
          if [[ "$function_debug_input" == "true" ]]; then
          echo "✅ Found matching resources for type '$resource_type' with name '$resource_name':"
          echo "$resource_matches"
          fi
          log_summary "$resource_type Check - $resource_name" "$resource_type Found:Success"
          resource_summary+="✅ Found for '$resource_name':\n$resource_matches\n"
        else
          if [[ "$function_debug_input" == "true" ]]; then
          echo "❌ No resources found for type '$resource_type' containing name '$resource_name'."
          fi
          log_summary "$resource_type Check - $resource_name" "$resource_type Not Found:Failure"
          resource_summary+="❌ Not Found for '$resource_name'\n"
        fi
      done
    done
  else
    echo "⏩ Skipping resource checks because fetch_resource_names is empty."
  fi

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
      local webhook_summary=""

      if [[ "$webhook_type" == "mutatingwebhookconfigurations" ]]; then
        for fetch_name in "${mutating_webhook_names[@]}"; do
        if [[ "$function_debug_input" == "true" ]]; then
          echo "🔍 Filtering $webhook_type for name containing '$fetch_name'..."
          fi
          local webhook_matches
          webhook_matches=$(run_command kubectl $kubeconfig --context=$kubecontext get $webhook_type --all-namespaces -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -i "$fetch_name")

          if [[ -n "$webhook_matches" ]]; then
          if [[ "$function_debug_input" == "true" ]]; then
            echo "✅ Found $webhook_type for '$fetch_name':"
            echo "$webhook_matches"
            fi
            log_summary "$webhook_type Check - $fetch_name" "$webhook_type Found:Success"
            webhook_summary+="✅ Found for '$fetch_name':\n$webhook_matches\n"
          else
          if [[ "$function_debug_input" == "true" ]]; then
            echo "❌ No $webhook_type containing name '$fetch_name' found."
            fi
            log_summary "$webhook_type Check - $fetch_name" "$webhook_type Not Found:Failure"
            webhook_summary+="❌ Not Found for '$fetch_name'\n"
          fi
        done
      elif [[ "$webhook_type" == "validatingwebhookconfigurations" ]]; then
        for fetch_name in "${validating_webhook_names[@]}"; do
        if [[ "$function_debug_input" == "true" ]]; then
          echo "🔍 Filtering $webhook_type for name containing '$fetch_name'..."
          fi
          local webhook_matches
          webhook_matches=$(run_command kubectl $kubeconfig --context=$kubecontext get $webhook_type --all-namespaces -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -i "$fetch_name")

          if [[ -n "$webhook_matches" ]]; then
          if [[ "$function_debug_input" == "true" ]]; then
            echo "✅ Found $webhook_type for '$fetch_name':"
            echo "$webhook_matches"
            fi
            log_summary "$webhook_type Check - $fetch_name" "$webhook_type Found:Success"
            webhook_summary+="✅ Found for '$fetch_name':\n$webhook_matches\n"
          else
          if [[ "$function_debug_input" == "true" ]]; then
            echo "❌ No $webhook_type containing name '$fetch_name' found."
            fi
            log_summary "$webhook_type Check - $fetch_name" "$webhook_type Not Found:Failure"
            webhook_summary+="❌ Not Found for '$fetch_name'\n"
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



# Function to log and run commands
run_command() {
  local cmd="$*"
  echo -e "🔧 Running: $cmd"
  eval "$cmd"
}



# Determine the correct kubectl binary
KUBECTL_BIN=$(which kubectl)


while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace-to-check) namespaces_to_check="$2"; shift 2 ;;
    --test-namespace) test_namespace="$2"; shift 2 ;;
    --pvc-test-namespace) pvc_test_namespace="$2"; shift 2 ;;
    --invoke-wrappers) wrappers_to_invoke="$2"; shift 2 ;;
    --kubeconfig) kubeconfig="--kubeconfig=$2"; shift 2 ;;
    --kubecontext) kubecontext="$2"; shift 2 ;;
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
echo "Debug: Initial kubeconfig='$kubeconfig', kubecontext='$kubecontext'"

# Ensure kubeconfig and kubecontext are provided
if [[ -z "$kubeconfig" || -z "$kubecontext" ]]; then
  echo -e "❌ Error: Both --kubeconfig and --kubecontext are mandatory parameters."
  exit 1
fi

# Preserve original values
original_kubeconfig="$kubeconfig"
original_kubecontext="$kubecontext"

# Debug: Before proceeding
echo "Debug: Preserved kubeconfig='$original_kubeconfig', kubecontext='$original_kubecontext'"

# Log the kubectl binary path
echo "Using kubectl at: $KUBECTL_BIN"

# Validate kubeconfig file exists
kubeconfig_path="${original_kubeconfig#--kubeconfig=}"
if [[ ! -f "$kubeconfig_path" ]]; then
  echo "❌ Error: kubeconfig file '$kubeconfig_path' does not exist."
  exit 1
fi

# Validate kubecontext exists
if ! $KUBECTL_BIN --kubeconfig="$kubeconfig_path" config get-contexts "$original_kubecontext" >/dev/null 2>&1; then
  echo "❌ Error: kubecontext '$original_kubecontext' does not exist in the provided kubeconfig."
  exit 1
fi

echo "✅ kubeconfig and kubecontext validated successfully."


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


# Function to create a namespace
create_namespace() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespace="${3:-egs-test-namespace}"
  local display_resources_flag="$4"
  local global_wait="$5"
  local watch_resources="${6:-false}"
  local watch_duration="${7:-30}"

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace"
  log_command "create_namespace" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace"

  # Check if the namespace already exists
  if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $namespace >/dev/null 2>&1"; then
    echo -e "⚠️ Warning: Namespace '$namespace' already exists. Skipping creation."
    log_summary "Namespace Creation - $namespace" "Namespace already exists:Skipped"
  else
    # Attempt to create the namespace
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext create namespace $namespace >/dev/null 2>&1"; then
      echo -e "✅ Namespace '$namespace' created successfully."
      log_summary "Namespace Creation - $namespace" "Namespace created:Success"
      display_resource_details "$kubeconfig" "$kubecontext" "namespace" "$namespace" "$namespace" "$display_resources_flag"

      # Watch the namespace if enabled
      if [[ "$watch_resources" == "true" ]]; then
        watch_resource "$kubeconfig" "$kubecontext" "namespace" "$namespace" "$namespace" "$watch_resources" "$watch_duration"
      fi
    else
      echo -e "❌ Error: Unable to create namespace '$namespace'."
      #log_summary "Namespace Creation - $namespace" "Namespace creation failed:Failed"
      exit 1
    fi
  fi

  # Wait for the specified time, if any
  wait_after_command "$global_wait"
}

# Function to delete a namespace
delete_namespace() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespace="$3"
  local cleanup="$4"
  local display_resources_flag="$5"
  local global_wait="$6"
  local watch_resources="${7:-false}"          # Optional: Enable or disable watching
  local watch_duration="${8:-30}"        # Optional: Duration to watch the resource

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace, cleanup=$cleanup"
  log_command "delete_namespace" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespace=$namespace, cleanup=$cleanup"

  if [[ "$cleanup" == "true" ]]; then
    # Attempt to delete the namespace
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $namespace --wait >/dev/null 2>&1"; then
      echo -e "✅ Namespace '$namespace' deleted successfully."
     # log_summary "Namespace Deletion - $namespace" "Namespace deleted:Success"

      # Watch the namespace deletion if enabled
      if [[ "$watch_resources" == "true" ]]; then
        watch_resource "$kubeconfig" "$kubecontext" "namespace" "$namespace" "" "$watch_resources" "$watch_duration"
      fi
    else
      echo -e "❌ Error: Unable to delete namespace '$namespace'."
      #log_summary "Namespace Deletion - $namespace" "Namespace deletion failed:Failed"
      exit 1
    fi
  else
    echo -e "⚠️ Deletion of namespace '$namespace' skipped due to cleanup flag."
    #log_summary "Namespace Deletion - $namespace" "Namespace deletion skipped:Skipped"
  fi

  # Wait for the specified time, if any
  wait_after_command "$global_wait"
}




# Namespace checks
namespace_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local namespaces_to_check="$3"
  local test_namespace="${4:-egs-test-namespace}"
  local cleanup="$5"
  local display_resources_flag="$6"
  local global_wait="$7"
  local watch_resources="${8:-false}"          # Flag to enable or disable watching
  local watch_duration="${9:-30}"        # Duration to watch the resource

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, namespaces_to_check=$namespaces_to_check, test_namespace=$test_namespace, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration"

  # Split the namespaces_to_check string into an array
  IFS=',' read -r -a namespace_array <<< "$namespaces_to_check"
  for namespace in "${namespace_array[@]}"; do
    echo "🔍 Testing namespace existence: '$namespace'"
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $namespace >/dev/null 2>&1"; then
      echo -e "✅ Namespace '$namespace' exists."
      log_summary "Namespace Check - $namespace" "Namespace Exists:Success"
    else
      echo -e "❌ Namespace '$namespace' does not exist."
      log_summary "Namespace Check - $namespace" "Namespace Missing:Failure"
    fi
    wait_after_command "$global_wait"
  done

  # Test namespace creation
  echo "🔍 Testing namespace creation for: '$test_namespace'"
  log_inputs_and_time "$function_debug_input" create_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$display_resources_flag" "$global_wait"
  log_summary "Namespace Creation - $test_namespace" "Namespace Created:Success"

  # Watch the namespace if the watch flag is enabled
  if [[ "$watch_resources" == "true" ]]; then
    watch_resource "$kubeconfig" "$kubecontext" "namespace" "$test_namespace" "" "$watch_resources" "$watch_duration"
  # log_summary "Namespace Watch - $test_namespace" "Watched for $watch_duration seconds:Success"
  fi

  # Test namespace deletion if cleanup is enabled
  if [[ "$cleanup" == "true" ]]; then
    echo "🔍 Testing namespace deletion for: '$test_namespace'"
    log_inputs_and_time "$function_debug_input" delete_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$cleanup" "$display_resources_flag" "$global_wait"
   # log_summary "Namespace Deletion - $test_namespace" "Namespace Deleted:Success"
  else
    echo "⚠️ Skipping namespace deletion due to cleanup flag."
    #log_summary "Namespace Deletion - $test_namespace" "Skipped:Cleanup Disabled"
  fi
}

# Internet Access Checks
internet_access_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local test_pod_image="${3:-docker.io/aveshasystems/alpine-k8s:1.0.1}"           # Default test pod image
  local test_namespace="${4:-egs-test-namespace}" # Namespace for test
  local test_pod_name="${5:-internet-test-pod}"         # Name of the test pod
  local target_urls="${6:-hub.docker.com,google.com}"          # URLs or IPs to check
  local global_wait="${7:-10}"                              # Timeout for wget command
  local cleanup="${8:-false}"                            # Flag to clean up resources
  local watch_resources="${9:-true}"                  # Flag to watch the pod
  local watch_duration="${10:-30}"                     # Duration to watch the pod

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_pod_image=$test_pod_image, test_namespace=$test_namespace, test_pod_name=$test_pod_name, target_urls=$target_urls, global_wait=$global_wait, cleanup=$cleanup, watch_resources=$watch_resources, watch_duration=$watch_duration"

  # Create the test namespace if it doesn't exist
  echo "🔍 Checking or creating namespace: '$test_namespace'"
  if ! run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext get namespace $test_namespace >/dev/null 2>&1"; then
    echo "⚠️ Namespace '$test_namespace' does not exist. Creating..."
    run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext create namespace $test_namespace"
    log_summary "Namespace Creation - $test_namespace" "Namespace Created:Success"
  else
    echo "✅ Namespace '$test_namespace' exists."
    log_summary "Namespace Check - $test_namespace" "Namespace Exists:Success"
  fi

  # Deploy a test pod
  echo "🔍 Creating test pod: '$test_pod_name'"
  run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext run $test_pod_name --image=$test_pod_image --restart=Never -n $test_namespace -- sleep 3600"
  log_summary "Pod Creation - $test_pod_name" "Pod Created:Success"

  # Watch the pod if the watch flag is enabled
  if [[ "$watch_resources" == "true" ]]; then
    echo "🔍 Watching pod: '$test_pod_name'"
    watch_resource "$kubeconfig" "$kubecontext" "pod" "$test_pod_name" "$test_namespace" "$watch_resources" "$watch_duration"
   # log_summary "Pod Watch - $test_pod_name" "Watched for $watch_duration seconds:Success"
  fi

  # Check internet connectivity from the pod
  echo "🔍 Checking internet connectivity from pod: '$test_pod_name'"
  IFS=',' read -r -a url_array <<< "$target_urls"
  for url in "${url_array[@]}"; do
    echo "🔍 Testing connectivity to: '$url'"
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext exec -n $test_namespace $test_pod_name -- wget -q --spider --timeout=$global_wait $url"; then
      echo "✅ Internet connectivity to '$url' is working."
      log_summary "Internet Connectivity - $url" "Success"
    else
      echo "❌ Failed to reach '$url' within $global_wait seconds."
      log_summary "Internet Connectivity - $url" "Failure"
    fi
  done

  # Cleanup test pod and namespace if cleanup is enabled
  if [[ "$cleanup" == "true" ]]; then
    echo "🔍 Cleaning up resources..."
    run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete pod $test_pod_name -n $test_namespace --ignore-not-found"
    run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete namespace $test_namespace --ignore-not-found"
    #log_summary "Cleanup - $test_namespace and $test_pod_name" "Resources Cleaned:Success"
  else
    echo "⚠️ Skipping cleanup due to cleanup flag."
   # log_summary "Cleanup - $test_namespace and $test_pod_name" "Skipped:Cleanup Disabled"
  fi
}




# PVC preflight checks
pvc_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local pvc_test_namespace="${3:-egs-test-namespace}"
  local pvc_name="${4:-egs-test-pvc}"
  local storage_class="$5"
  local storage_size="${6:-1Gi}"
  local cleanup="$7"
  local display_resources_flag="$8"
  local global_wait="$9"
  local watch_resources="${10:-false}"         
  local watch_duration="${11:-30}"   

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, pvc_test_namespace=$pvc_test_namespace, pvc_name=$pvc_name, storage_class=$storage_class, storage_size=$storage_size, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration"
  log_command "pvc_preflight_checks" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, pvc_test_namespace=$pvc_test_namespace, pvc_name=$pvc_name, storage_class=$storage_class, storage_size=$storage_size, cleanup=$cleanup"

  # Create namespace for PVC testing
  log_inputs_and_time "$function_debug_input" create_namespace "$kubeconfig" "$kubecontext" "$pvc_test_namespace" "$display_resources_flag" "$global_wait"
  log_summary "Namespace for PVC Testing - $pvc_test_namespace" "Namespace Created:Success"

  # Create the PVC
  echo "🔍 Creating PVC '$pvc_name' in namespace '$pvc_test_namespace'"
  if [[ -n "$storage_class" ]]; then
    cat <<EOF | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"
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
    log_summary "PVC Creation - $pvc_name" "PVC with StorageClass Created:Success"
  else
    cat <<EOF | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"
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
    log_summary "PVC Creation - $pvc_name" "PVC without StorageClass Created:Success"
  fi

  # Display the PVC details
  display_resource_details "$kubeconfig" "$kubecontext" "pvc" "$pvc_test_namespace" "$pvc_name" "$display_resources_flag"

  # Watch the PVC if the watch flag is enabled
  if [[ "$watch_resources" == "true" ]]; then
    watch_resource "$kubeconfig" "$kubecontext" "pvc" "$pvc_name" "$pvc_test_namespace" "$watch_resources" "$watch_duration"
   # log_summary "PVC Watch - $pvc_name" "Watched for $watch_duration seconds:Success"
  fi

  # Delete the PVC if cleanup is enabled
  if [[ "$cleanup" == "true" ]]; then
    echo "🔍 Deleting PVC '$pvc_name' in namespace '$pvc_test_namespace'"
    run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete pvc $pvc_name -n $pvc_test_namespace --wait >/dev/null 2>&1"
    echo "🧹 PVC '$pvc_name' deleted."
   # log_summary "PVC Deletion - $pvc_name" "PVC Deleted:Success"
  else
    echo "⚠️ Skipping PVC deletion due to cleanup flag."
   # log_summary "PVC Deletion - $pvc_name" "Skipped:Cleanup Disabled"
  fi

  # Delete the namespace used for PVC testing if cleanup is enabled
  log_inputs_and_time "$function_debug_input" delete_namespace "$kubeconfig" "$kubecontext" "$pvc_test_namespace" "$cleanup" "$display_resources_flag" "$global_wait"
  #log_summary "Namespace Cleanup - $pvc_test_namespace" "Namespace Deleted:Success"
}





# Function to test service creation and deletion
service_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local test_namespace="${3:-egs-test-namespace}"
  local cleanup="$4"
  local display_resources_flag="$5"
  local global_wait="$6"
  local service_name="${7:-egs-test-service}"  # Base name for services
  local service_type="${8:-all}"              # Parameter for specific service type
  local watch_resources="$9"                  # Flag to enable or disable watching
  local watch_duration="${10:-30}"            # Duration to watch the resource

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, cleanup=$cleanup, display_resources=$display_resources_flag, service_name=$service_name, service_type=${service_type:-all}, watch_resources=$watch_resources, watch_duration=$watch_duration"
  log_command "service_preflight_checks" "kubeconfig=$kubeconfig, kubecontext=$kubecontext, test_namespace=$test_namespace, service_name=$service_name, service_type=$service_type, cleanup=$cleanup"

  # Create a temporary namespace for service testing
  log_inputs_and_time "$function_debug_input" create_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$display_resources_flag" "$global_wait"
  log_summary "Namespace for Service Testing - $test_namespace" "Namespace Created:Success"

  local SUCCESS=true

  # Function to test a specific service type
  test_service_type() {
    local type="$1"
    local yaml="$2"
    local name="$3"   # Unique service name

    echo "🔍 Testing $type service creation with name $name..."
    if echo "$yaml" | run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext apply -f -"; then
      echo "✅ $type service '$name' created successfully."
      log_summary "Service Creation - $name" "$type Service Created:Success"
      display_resource_details "$kubeconfig" "$kubecontext" "service" "$test_namespace" "$name" "$display_resources_flag"

      # Watch the resource if the watch flag is enabled
      if [[ "$watch_resources" == "true" ]]; then
        watch_resource "$kubeconfig" "$kubecontext" "service" "$name" "$test_namespace" "$watch_resources" "$watch_duration"
        #log_summary "Service Watch - $name" "Watched for $watch_duration seconds:Success"
      fi

      # Clean up the resource if cleanup flag is true
      if [[ "$cleanup" == "true" ]]; then
        run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext delete service $name -n $test_namespace --ignore-not-found"
        echo "🧹 Cleanup: $type service '$name' deleted."
        #log_summary "Service Deletion - $name" "$type Service Deleted:Success"
      else
        echo "⚠️ Cleanup for $type service '$name' skipped as cleanup flag is set to false."
        #log_summary "Service Deletion - $name" "$type Service Cleanup Skipped:Cleanup Disabled"
      fi
    else
      echo "❌ Error: Failed to create $type service '$name'."
      #log_summary "Service Creation - $name" "$type Service Creation Failed:Failure"
      SUCCESS=false
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
        exit 1
        ;;
    esac
  fi

  # Clean up namespace if cleanup flag is true
  if [[ "$cleanup" == "true" ]]; then
    log_inputs_and_time "$function_debug_input" delete_namespace "$kubeconfig" "$kubecontext" "$test_namespace" "$cleanup" "$display_resources_flag" "$global_wait"
    #log_summary "Namespace Cleanup - $test_namespace" "Namespace Deleted:Success"
  else
    echo "⚠️ Namespace cleanup skipped as cleanup flag is set to false."
    #log_summary "Namespace Cleanup - $test_namespace" "Namespace Cleanup Skipped:Cleanup Disabled"
  fi

  # Final status
  if [ "$SUCCESS" = true ]; then
    echo "✅ Service preflight checks completed successfully."
  else
    echo "❌ Service preflight checks encountered errors."
    exit 1
  fi
}

k8s_privilege_preflight_checks() {
  local kubeconfig="$1"
  local kubecontext="$2"
  local resource_action_pairs="${3:-$default_resource_action_pairs}"
  local test_resource="${4:-clusterrole}"
  local cleanup="$5"
  local display_resources_flag="$6"
  local global_wait="$7"
  local watch_resources="${8:-false}"       # Flag to enable or disable watching
  local watch_duration="${9:-30}"          # Duration to watch the resource

  echo -e "🔹 Input used: kubeconfig=$kubeconfig, kubecontext=$kubecontext, resource_action_pairs=$resource_action_pairs, test_resource=$test_resource, cleanup=$cleanup, display_resources=$display_resources_flag, watch_resources=$watch_resources, watch_duration=$watch_duration"

  # Split the resource_action_pairs string into an array
  IFS=',' read -r -a pair_array <<< "$resource_action_pairs"
  for pair in "${pair_array[@]}"; do
    resource=$(echo "$pair" | cut -d':' -f1)
    action=$(echo "$pair" | cut -d':' -f2)
    if [[ "$function_debug_input" == "true" ]]; then
    echo "🔍 Testing privilege for action '$action' on resource '$resource'"
    fi
    if run_command "$KUBECTL_BIN $kubeconfig --context=$kubecontext auth can-i $action $resource >/dev/null 2>&1"; then
      echo -e "✅ Privilege exists for action '$action' on resource '$resource'."
      log_summary "Privilege Check - $resource:$action" "Privilege Exists:Success"
    else
      echo -e "❌ Privilege missing for action '$action' on resource '$resource'."
      log_summary "Privilege Check - $resource:$action" "Privilege Missing:Failure"
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
  # Statements to execute only when function_debug_input is true
    # Print final values (debugging)
    echo "--- Final Parameter Values ---"
    echo "🔹 namespaces_to_check: ${namespaces_to_check:-Not provided}"
    echo "🔹 test_namespace: ${test_namespace:-Not provided}"
    echo "🔹 pvc_test_namespace: ${pvc_test_namespace:-Not provided}"
    echo "🔹 wrappers_to_invoke: ${wrappers_to_invoke:-Not provided}"
    echo "🔹 kubeconfig: ${kubeconfig:-Not provided}"
    echo "🔹 kubecontext: ${kubecontext:-Not provided}"
    echo "🔹 pvc_name: ${pvc_name:-Not provided}"
    echo "🔹 storage_class: ${storage_class:-Not provided}"
    echo "🔹 storage_size: ${storage_size:-Not provided}"
    echo "🔹 service_name: ${service_name:-Not provided}"
    echo "🔹 service_type: ${service_type:-Not provided}"
    echo "🔹 cleanup: ${cleanup:-Not provided}"
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


# Verify input summary 
echo "📋 Verifying input summary..."
log_inputs_and_time "$function_debug_input" print_summary

# Verify kubeconfig and kubecontext
echo "🔍 Verifying K8s Cluster info..."
log_inputs_and_time "$function_debug_input" k8s_cluster_info_preflight_check "$kubeconfig" "$kubecontext" "$display_resources" "$global_wait" "$watch_resources" "$watch_duration"

# Debugging the passed arguments
echo "🐞 Debug: Arguments passed to the script: $@"
log_inputs_and_time "$function_debug_input" main "$@"

# Invoke generate summary at the end
echo "📊 Generating final summary..."
log_inputs_and_time "$function_debug_input" generate_summary

echo "=======================EGS Preflight Check Script execution completed at: $(date)============================" >> "$output_file"
