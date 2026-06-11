# AVESHA – ELASTIC GRID SERVICE

## QUICK INSTALLATION

### Baseline Setup

- Single Node with K3S installed
- Node has NVidia GPU with GPU Operator installed
- EGS installer will install Prometheus, KT-Postgres and Kserve. No previous installation of these is expected.

### Prerequisites (install before running)

> The installer checks these up front and **aborts before downloading anything** if any is missing.

```bash
# Debian/Ubuntu example
sudo apt-get update && sudo apt-get install -y git jq

# yq v4.44.2+ (binary install)
sudo curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 \
  -o /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq

# kubectl and helm are also required (RKE2/K3s already provide kubectl)
```

### Register for EGS license

<https://avesha.io/egs-registration>

You will need to generate a cluster key during registration. Use the **full** value (creation
timestamp *immediately followed by* the UID — paste the entire output):

```bash
kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'
```

Download `egs-license.yaml` from the email sent from Avesha.

### Installation Command

> **Note:** Use the IP of the master node with port 6443.

```bash
export CONTROLLER_ENDPOINT="https://<NodeIP>:6443"
export WORKER_ENDPOINT="https:////<NodeIP>:6443"
export WORKER_NAME="worker-1"

curl -fsSL https://repo.egs.avesha.io/install-egs.sh | bash -s -- \
  --license-file egs-license.yaml \
  --kubeconfig ~/.kube/config \
  --cluster-name $WORKER_NAME \
  --skip-gpu-operator \
  --controller-endpoint $CONTROLLER_ENDPOINT \
  --worker-endpoint $WORKER_ENDPOINT \
  --ui-service-type NodePort
```

> If cluster registration fails once with `namespaces "kubeslice-<project>" not found`, simply
> **re-run the same command** — the controller creates the project namespace on the first pass and
> the re-run completes registration. Cluster state is not rolled back.

**Link to Quick Install Guide for Reference**
<https://github.com/kubeslice-ent/egs-installation/blob/main/docs/Quick-Install-README.md>

---

### Note - For k3s if nsmgr pod is restarting increase the following limits and restart the pod

```bash
Raised inotify limits:max_user_instances=8192,max_queued_events=32768(persisted in/etc/sysctl.d/)
Raised k3sLimitNOFILE=1048576+ulimit -n 65536on thensmgrcontainer
Restartednsmgr+ recreated the vLLM pod
```

## ACCESS THE EGS UI

The EGS UI is exposed by the `kubeslice-ui-proxy` service. With `--ui-service-type NodePort` it is
reachable at `https://<master-node-ip>:<nodePort>`. Find the assigned NodePort:

```bash
kubectl get svc kubeslice-ui-proxy -n kubeslice-controller
# NAME                 TYPE       CLUSTER-IP      PORT(S)
# kubeslice-ui-proxy   NodePort   10.43.x.x       443:32724/TCP   <-- nodePort = 32724
```

### Step 1 — Reach the UI via port-forward (recommended)

When the NodePort is not directly reachable from your laptop (cloud security list / firewall / NAT
in front of the node), forward it to localhost. Either method works:

```bash
# Option A: kubectl port-forward (cloud-agnostic; needs kubeconfig access)
kubectl port-forward -n kubeslice-controller svc/kubeslice-ui-proxy 8443:443

# Option B: SSH local port-forward to the node's NodePort
ssh -L 8443:<master-node-ip>:<nodePort> <user>@<master-node-ip>
#   e.g. ssh -L 8443:10.0.0.5:32724 ubuntu@<public-ip>
```

Leave the command running, then open the UI in your browser:

```
https://localhost:8443
```

> A request to the UI returns `302` (redirect to `/login`) and the login page then returns `200` —
> confirming the UI is serving. If the node port is directly reachable in your network, you can
> instead browse `https://<master-node-ip>:<nodePort>` directly.

### Step 2 — Get the admin login token

The project namespace is `kubeslice-<project>` (default project `avesha` → `kubeslice-avesha`):

```bash
kubectl get secret kubeslice-rbac-rw-admin -n kubeslice-avesha \
  -o jsonpath='{.data.token}' | base64 -d; echo
```

> The installer also prints the Access URL and this token in its final summary. Alternatively run the
> helper copied into your working directory:
> `./fetch_egs_slice_token.sh -k ~/.kube/config -p avesha -a -u admin`

### Step 3 — Log in

On the EGS login screen, paste the token into the **Service Account Token** field and sign in.

---

# Example Inference Deployments

## Option-1: Deploy inference endpoints using EGS workload placement with vllm framework


### Step 1 — Create the `tenant-1` workspace by using the EGS Admin Portal and onboard the `vllm` namespace.

   For more information, see: 

   * [Create a Workspace](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/create-workspace/#create-a-workspace)
   * [Onboard Namespaces](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/onboard-namespaces/)

### Step 2 — Deploy the `vllm-slice-ns-gateway` configuration on the worker cluster using the following commands: (Select ClusterIP for the gatewayRef service)
Note: This will be deployed via workloadplacement CR in the next release.

```bash
kubectl apply -f vllm-slice-ns-gateway.yaml -n vllm
```

### Step 3 — Create a workload placement on the worker cluster by providing the Helm and manifest steps. For more information, 
    see [Create a Workload Placement](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/workload-deployment/workload-placement-ui/#create-a-workload-placement).

    a. Select worker cluster
   
    b. Add step-1: add the Helm values - refer to the`vllm-WorkloadPlacement-CR.yaml` file and use the `vllm-helm-values.yaml` file for values

    c. Add step-2: add manifest - use the `vllm-serviceexport-manifest.yaml` file. 

### Step 4 — After the successful deployment of the workload placement, get the service and validate it using the following example command on the `worker` cluster: 

```bash 
kubectl get svc -n vllm
```

```bash 
curl -X POST "http://<ClusterIP of vllm-llama3-engine-service>/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
       "model": "meta-llama/Llama-3.2-1B-Instruct",
       "messages": [
         {
          "role": "user",
          "content": "Explain Kubernetes in simple terms"
         }
       ],
      "temperature": 0.7, 
      "max_tokens": 100
   }'
```


## Option-2: Deploying Inference Endpoint with K-Serve/vllm framework

### Step 1 — Create the workspace by using the EGS Admin Portal (select No Network for Network Type for single node cluster)

### Step 2 — Edit the policy settings of the workspace, and disable the Enable Auto Eviction & Requeue on Failure (To avoid hitting the known issue.)

### Step 3 — Create inference endpoint for the workspace by using EGS Admin Portal (Change the Maximum Exit Duration to less than one week as per the workspace policy settings)   
For more information, see: 

   * [deploy-inference-endpoints](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/tutorials/deploy-inference-endpoints/)

Attaching an example snapshot for reference when creating the inference endpoint. Below is an example model specification for the inference endpoint.

<img width="1843" height="904" alt="image" src="https://github.com/user-attachments/assets/65b89e24-fdb4-4301-9448-ef0131aff65a" />


```bash
spec:
  predictor:
    model:
      modelFormat:
        name: huggingface
      args:
        - --model_name=llama3
        - --model_id=meta-llama/Llama-3.2-1B-Instruct
      env:
        - name: HF_TOKEN
          value: <HF TOKEN>   # REPLACE HuggingFace token with access to meta-llama
      resources:
        limits:
          cpu: "1"
          memory: 8Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: "1"
          memory: 6Gi
          nvidia.com/gpu: "1"
```

### Step 4 — Once the inference endpoint is ready, use the following curl command to verify that the endpoint is working correctly. Below is an example of the complete curl command for the inference endpoint.

```bash
curl -X POST "http://inf-lama2-inf-lama2.kubeslice.com/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
       "model": "meta-llama/Llama-3.2-1B-Instruct",
       "messages": [
         {
          "role": "user",
          "content": "Explain Kubernetes in simple terms"
         }
       ],
      "temperature": 0.7, 
      "max_tokens": 100
   }'
```

