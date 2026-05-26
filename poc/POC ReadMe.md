#DOC URL - https://docs.avesha.io/documentation/enterprise-egs/1.17.0/

1. Create the `ai-ran` workspace by using the EGS Admin Portal and onboard the `ai-ran` namespace. 
   For more information, see: 

   * [Create a Workspace](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/create-workspace/#create-a-workspace)
   * [Onboard Namespaces](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/onboard-namespaces/)

2. Edit the policy settings of the `ai-ran` workspace, and set the high priority range. For more information, see [Edit Workspace Policies](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/workspace-policies/#edit-workspace-policies).
   
3. In the `ai-ran` workspace, create a high-priority GPR on the `far-edge` cluster from the **GPU Requests** page. For more information, 
   see [Create a GPU Request](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/gpr-provisioning/manage-gpu-requests/#create-a-gpu-request).
4. After the newly created GPR is provisioned, deploy the `fr1` deployment on the `far-edge` cluster using the following 
   command: 

   ```bash 
   kubectl apply -f fr1-deployment.yaml -n ai-ran
   ```
5. In the `ai-ran` workspace, create a high-priority GPR on the `near-edge` cluster from the **GPU Requests** page. For more information, 
   see [Create a GPU Request](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/gpr-provisioning/manage-gpu-requests/#create-a-gpu-request).
6. After the newly created GPR is provisioned, deploy the `fr1` deployment on the `near-edge` cluster using the following 
   command: 

   ```bash 
   kubectl apply -f fr1-deployment.yaml -n ai-ran
   ```
7. Create the `tenant-1` workspace by using the EGS Admin Portal and onboard the `vllm` namespace. 

   For more information, see: 

   * [Create a Workspace](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/create-workspace/#create-a-workspace)
   * [Onboard Namespaces](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/manage-workspaces/onboard-namespaces/)

8. Create `far-edge-low` and `near-edge-low` GPR templates by setting low-priority in them. For more information, 
   see [Create a GPR Template](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/gpr-provisioning/manage-gpr-templates/#create-a-gpr-template).
9. Assign `far-edge-low` and `near-edge-low` GPR templates to the `tenant-1` workspace, and select **Auto-GPR** in both templates. 
10. Deploy the `vllm-slice-ns-gateway` configuration on the `far-edge` cluster using the following commands: 

    ```bash 
    kubectl apply -f vllm-slice-ns-gateway.yaml -n vllm
    ```
11. Create a workload placement on the `far-edge` cluster by providing the Helm and manifest steps. For more information, 
    see [Create a Workload Placement](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/workload-deployment/workload-placement-ui/#create-a-workload-placement).

    a. For Helm, refer to the`vllm-WorkloadPlacement-CR.yaml` file and use the `vllm-helm-values.yaml` file for values. 
    b. For manifest, use the `vllm-serviceexport-manifest.yaml` file. 

12. Create external DNS configuration: 

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

13. After the successful deployment of the workload placement, validate it using the following example command: 

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

14. In the `ai-ran` workspace, create a high-priority GPR on the `far-edge` cluster from the **GPU Requests** page. For more information, 
    see [Create a GPU Request](https://docs.avesha.io/documentation/enterprise-egs/1.17.0/admin-operations/gpr-provisioning/manage-gpu-requests/#create-a-gpu-request).
15. After the newly created GPR is provisioned, deploy the `fr2` deployment on the `far-edge` cluster using the following 
    command: 

    ```bash 
    kubectl apply -f fr2-deployment.yaml -n ai-ran
    ```

16. On the `far-edge` cluster, as the high-priority GPR is provisioned on the `ai-ran` workspace, the low-priority GPR will be 
    evicted on the `tenant-1` workspace. 
17. Go to the `tenant-1` workspace, toggle **Enable EGS** on the `vllm` workload placement. The workload will be redistributed to 
    the `near-edge` cluster. 

18. After the successful deployment of the workload placement, validate it using the following example command on the `near-edge` cluster: 

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