## Workload Placement and Redistribution

The following are the steps to deploy and redistribute workloads across tiers/clusters using EGS Workload Routing and Placement features.

 ### DOC reference URL - https://docs.avesha.io/documentation/enterprise-egs/1.17.0/

1. Create the `ai-ran` workspace by using the EGS Admin Portal and onboard the `ai-ran` namespace. 
   For more information, see: 

   * [Create a Workspace](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/create-workspace/#create-a-workspace)
   * [Onboard Namespaces](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/onboard-namespaces/)

2. Edit the policy settings of the `ai-ran` workspace, and set the high priority range and increase the Max Num Of Gpus. For more information, see [Edit Workspace Policies](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/workspace-policies/#edit-workspace-policies).
   
3. In the 'ai-ran' workspace, create a fr1 WorkloadPlacement:select far-edge cluster, for step use the manifest file 'fr1-workload-placement.yaml' and auto gpu selection with Memory for GPR. see [Create a Workload Placement](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/workload-deployment/workload-placement-ui/#create-a-workload-placement).
   
4. In the 'ai-ran' workspace, create a fr1 WorkloadPlacement:select near-edge cluster, for step use the manifest file 'fr1-workload-placement.yaml' and auto gpu selection with Memory for GPR. Verify the deployment on the AI workloads page.
   
5. Create the `tenant-1` workspace by using the EGS Admin Portal and onboard the `vllm` namespace. And Edit the policy settings of the `tenant` workspace and increase the Max Num Of Gpus.

   For more information, see: 

   * [Create a Workspace](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/create-workspace/#create-a-workspace)
   * [Onboard Namespaces](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/onboard-namespaces/)

6. Deploy the `vllm-slice-ns-gateway` configuration on the `far-edge` cluster using the following commands: 

    ```bash 
    kubectl apply -f vllm-slice-ns-gateway.yaml -n vllm
    ```
7. Create a workload placement on the `far-edge` cluster by providing the Helm and manifest steps. For more information, 
    see [Create a Workload Placement](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/workload-deployment/workload-placement-ui/#create-a-workload-placement).

    a. Select Enable EGS & far-edge cluster
   
    b. Add step-1: add the Helm values - refer to the`vllm-WorkloadPlacement-CR.yaml` file and use the `vllm-helm-values.yaml` file for values
    
    <img width="723" height="796" alt="image" src="https://github.com/user-attachments/assets/459cd008-4292-4c2d-9bb8-a00d617f412c" />

    c. Add step-2: add manifest - use the `vllm-serviceexport-manifest.yaml` file. 

9. Create external DNS configuration: 

    a. Create a secret using the following command for AWS route 53: 

       ```bash 
       kubectl create secret generic external-dns -n kube-system \
       --from-literal=AWS_ACCESS_KEY_ID='<KEY>' \
       --from-literal=AWS_SECRET_ACCESS_KEY='<SECRET>' \
       --from-literal=AWS_DEFAULT_REGION='us-east-1'
       ```
    b. Install the external DNS Helm chart using the following command: 

       ```bash 
       helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
       helm repo update
       helm install external-dns external-dns/external-dns \
       --namespace kube-system \
       --version 1.20.0 \
       -f external-dns-values-far-edge.yaml
       ```
    
    c. Annotate the Slice NS Gateway service using the following example command: 

       ```bash 
       kubectl annotate svc vllm-gateway -n vllm external-dns.alpha.kubernetes.io/hostname=vllm.inference.smartscaler.io
       ```

10. After the successful deployment of the workload placement, validate it using the following example command: 

    ```bash 
    curl -X POST "http://vllm.inference.smartscaler.io/v1/chat/completions" \
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

11. In the 'ai-ran' workspace, create a fr2 WorkloadPlacement:select far-edge cluster, for step use the manifest file 'fr2-workload-placement.yaml' and auto gpu selection with Memory for GPR

12. On the `far-edge` cluster, as the high-priority GPR is provisioned on the `ai-ran` workspace, the low-priority GPR will be evicted on the `tenant-1` workspace.
    
13. Go to the `tenant-1` workspace and observe the workload will be redistributed to the `near-edge` cluster from the 'far-edge' cluster. 

14. After the successful deployment of the workload placement, validate it using the following example command on the `near-edge` cluster: 

    ```bash 
    curl -X POST "http://vllm.inference.smartscaler.io/v1/chat/completions" \
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
