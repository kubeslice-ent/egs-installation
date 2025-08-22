# EGS Preflight Check Script

![Kubernetes](https://img.shields.io/badge/Kubernetes-✔️-blue?logo=kubernetes) ![Bash](https://img.shields.io/badge/Shell_Script-Bash-121011?logo=gnu-bash) ![License](https://img.shields.io/badge/License-@Avesha-orange)

A robust preflight check script designed for EGS setup on Kubernetes. This script verifies Kubernetes resource configurations, permissions, and connectivity to ensure the environment is ready for deployment.

## Features

- 🛠️ **Resource Validation**: Checks namespaces, services, PVCs, and privileges.
- 🔍 **Comprehensive Preflight Checks**: Validates Kubernetes configurations and access.
- 🌐 **Internet Connectivity Checks**: Ensures cluster access to external resources.
- 🧹 **Resource Cleanup**: Optionally deletes created resources after validation.
- ⚡ **Multi-context Support**: Operates on multiple Kubernetes contexts.
- 🐛 **Debugging**: Provides detailed logs for troubleshooting.

## Usage

```bash
./egs-preflight-check.sh [OPTIONS]
```

## Multi Cluster Example
```bash
./egs-preflight-check.sh \
--kubeconfig ~/.kube/config \
--kubecontext-list context1,context2
```

### Key Options:

| Option                     | Description                                                                                  |
|----------------------------|----------------------------------------------------------------------------------------------|
| `--namespace-to-check`     | 🗂️ Comma-separated list of namespaces to check existence.                                    |
| `--test-namespace`         | 🏷️ Namespace for test creation and deletion (default: `egs-test-namespace`).                |
| `--pvc-test-namespace`     | 📂 Namespace for PVC test creation and deletion (default: `egs-test-namespace`).            |
| `--pvc-name`               | 🛠️ Name of the test PVC (default: `egs-test-pvc`).                                          |
| `--storage-class`          | 🗄️ Storage class for the PVC (default: none).                                               |
| `--storage-size`           | 📦 Storage size for the PVC (default: `1Gi`).                                               |
| `--service-name`           | 📌 Name of the test service (default: `test-service`).                                       |
| `--service-type`           | ⚙️ Type of service to create and validate (`ClusterIP`, `NodePort`, `LoadBalancer`, or `all`). Default: `all`. |
| `--kubeconfig`             | 🗂️ Path to the kubeconfig file (mandatory).                                                 |
| `--kubecontext`            | 🌐 Context from the kubeconfig file (mandatory).                                             |
| `--kubecontext-list`       | 🌐 Comma-separated list of context names to operate on.                                      |
| `--cleanup`                | 🧹 Whether to delete test resources (`true` or `false`). Default: `true`.                   |
| `--global-wait`            | ⏳ Time to wait after each command execution (default: `0`).                                 |
| `--watch-resources`        | 👀 Enable or disable watching resources after creation (default: `false`).                  |
| `--watch-duration`         | ⏱️ Duration to watch resources after creation (default: `30` seconds).                     |
| `--invoke-wrappers`        | 🛠️ Comma-separated list of wrapper functions to invoke.                                      |
| `--display-resources`      | 👁️ Whether to display resources created (default: `true`).                                  |
| `--kubectl-path`           | ⚡ Override default kubectl binary path.                                                     |
| `--function-debug-input`   | 🐞 Enable or disable function debugging (default: `false`).                                  |
| `--generate-summary`       | 📊 Enable or disable summary generation (default: `true`).                                  |
| `--resource-action-pairs`  | 🔐 Override default resource-action pairs (e.g., `pod:create,service:get`).                |
| `--fetch-resource-names`   | 🔍 Fetch all resource names from the cluster (default: `false`).                             |
| `--fetch-webhook-names`    | 🔍 Fetch all webhook names from the cluster (default: `false`).                              |
| `--api-resources`          | 🌍 Comma-separated list of API resources to include or operate on.                          |
| `--webhooks`               | 🌍 Comma-separated list of webhooks to include or operate on.                                |
| `--help`                   | ❓ Display this help message.                                                               |

### Default Resource-Action Pairs:

📌 The default resource-action pairs used for privilege checks are:

- `namespace:create,namespace:delete,namespace:get,namespace:list,namespace:watch`
- `pod:create,pod:delete,pod:get,pod:list,pod:watch`
- `service:create,service:delete,service:get,service:list,service:watch`
- `configmap:create,configmap:delete,configmap:get,configmap:list,configmap:watch`
- `secret:create,secret:delete,secret:get,secret:list,secret:watch`
- `serviceaccount:create,serviceaccount:delete,serviceaccount:get,serviceaccount:list,serviceaccount:watch`
- `clusterrole:create,clusterrole:delete,clusterrole:get,clusterrole:list`
- `clusterrolebinding:create,clusterrolebinding:delete,clusterrolebinding:get,clusterrolebinding:list`

### Wrapper Functions:

| Wrapper Function                  | Description                                                                 |
|-----------------------------------|-----------------------------------------------------------------------------|
| 🗂️ `namespace_preflight_checks`   | Validates namespace creation and existence.                                |
| 🔍 `grep_k8s_resources_with_crds_and_webhooks` | Validates existing resources available in the cluster based on resource names. (e.g., prometheus, gpu-operator, postgresql) |
| 📂 `pvc_preflight_checks`         | Validates PVC creation, deletion, and storage properties.                   |
| ⚙️ `service_preflight_checks`     | Validates the creation and deletion of services (`ClusterIP`, `NodePort`, `LoadBalancer`). |
| 🔐 `k8s_privilege_preflight_checks` | Validates privileges for Kubernetes actions on resources.                  |
| 🌐 `internet_access_preflight_checks` | Validates internet connectivity from within the Kubernetes cluster.         |

### Examples

```bash
./egs-preflight-check.sh --namespace-to-check my-namespace --test-namespace test-ns --invoke-wrappers namespace_preflight_checks
./egs-preflight-check.sh --pvc-test-namespace pvc-ns --pvc-name test-pvc --storage-class standard --storage-size 1Gi --invoke-wrappers pvc_preflight_checks
./egs-preflight-check.sh --test-namespace service-ns --service-name test-service --service-type NodePort --watch-resources true --watch-duration 60 --invoke-wrappers service_preflight_checks
./egs-preflight-check.sh --invoke-wrappers namespace_preflight_checks,pvc_preflight_checks,service_preflight_checks
./egs-preflight-check.sh --resource-action-pairs pod:create,namespace:delete --invoke-wrappers k8s_privilege_preflight_checks
./egs-preflight-check.sh --function-debug-input true --invoke-wrappers namespace_preflight_checks
./egs-preflight-check.sh --generate-summary false --invoke-wrappers namespace_preflight_checks
./egs-preflight-check.sh --fetch-resource-names true --invoke-wrappers service_preflight_checks
./egs-preflight-check.sh --api-resources pod,service --invoke-wrappers namespace_preflight_checks
```

> **Note**: If no wrapper function is specified, all preflight check functions will be executed by default.

## Sample Output

<img width="1436" height="980" alt="image" src="https://github.com/user-attachments/assets/0fa45220-f2b3-4df5-9495-48374ab441b8" />

- 📝 **Logs**: Detailed logs are generated for each step, including successes and failures.
- 📊 **Summary**: A final summary is displayed, highlighting the status of all checks.

## ⚠️ Important: Interpreting Preflight Check Results

**📋 Review Failures Before Proceeding:**
After running the preflight check script, carefully review any failures or warnings in the output. These issues should be addressed before proceeding with EGS installation to ensure a smooth deployment process.

**🔍 Understanding Check Requirements:**
Not all preflight checks may be required to pass depending on your specific setup and requirements:

- **🔴 Critical Failures**: Must be resolved before proceeding (e.g., namespace creation permissions, basic Kubernetes access) and may be ignored if not applicable.
- **🟡 Warnings**: Review and resolve if they impact your specific use case and can be ignored if not applicable
- **🟢 Optional Checks**: Checks are passing for your deployment scenario 

**💡 Examples of Setup-Dependent Checks:**
- **Storage Class Checks**: May fail if you don't need persistent storage
- **Service Type Checks**: LoadBalancer services may not be available in all environments
- **Internet Connectivity**: May not be required for air-gapped deployments
- **Resource Quotas**: May not apply if your cluster doesn't use resource quotas

**📚 Next Steps:**
1. **Review the summary** to identify failed checks
2. **Analyze failures** to understand their impact on your deployment
3. **Resolve critical issues** that affect basic functionality
4. **Evaluate optional failures** based on your specific requirements
5. **Re-run checks** after resolving issues to verify fixes

**📄 Detailed Logs for Troubleshooting:**
The preflight check script generates a comprehensive log file `egs-preflight-check-output.log` that contains:
- **Detailed execution logs** for each check performed
- **Command outputs** and error messages
- **Resource creation/deletion details** for test resources
- **Permission check results** with specific failure reasons
- **Timing information** for performance analysis
- **Context-specific details** for multi-cluster setups

**🔍 Using the Log File:**
- **Location**: Generated in the same directory as the script
- **Format**: Human-readable with timestamps and clear section separators
- **Search**: Use `grep` to find specific failures (e.g., `grep -i "fail\|error" egs-preflight-check-output.log`)
- **Debugging**: Enable `--function-debug-input true` for additional verbose logging
- **Retention**: Logs are preserved between runs for comparison and analysis

## Related Files

- **`egs-preflight-check.sh`**: The main preflight check script
- **`egs-preflight-check-output.log`**: Detailed execution logs and troubleshooting information
- **Test Resources**: Temporary namespaces, services, and PVCs created during checks (cleaned up by default)
