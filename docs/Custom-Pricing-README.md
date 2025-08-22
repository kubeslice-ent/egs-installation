# Custom Pricing Upload Script

## 🔑 Key Features

1. **Define cloud instance pricing data** in YAML
2. **Specify Kubernetes connection details** (via kubeconfig and kubecontext) in the same YAML
3. **Automatically port-forward** to a Kubernetes service
4. **Convert the YAML pricing info** to CSV
5. **Upload the CSV** to a pricing API running inside the cluster

## 📁 Files

- **custom-pricing-data.yaml**: YAML input file with Kubernetes config and pricing data
- **custom-pricing-upload.sh**: Bash script to read YAML, port-forward, generate CSV, and upload

## 📦 Prerequisites

Make sure the following tools are installed:

- **kubectl**: Communicate with Kubernetes
- **yq**: Parse YAML in shell
- **jq**: Parse JSON in shell
- **curl**: Upload CSV via API

## Input custom-pricing-data YAML Format

The input YAML file should follow this format:

```yaml
kubernetes:
  kubeconfig: ""         #absolute path og kubeconfig
  kubecontext: ""        #kubecontext name
  namespace: "kubeslice-controller"
  service: "kubetally-pricing-service"

#we can add as many cloud providers and instance types as needed
cloud_providers:
  - name: "gcp"
    instances:
      - region: "us-east1"
        component: "Compute Instance"
        instance_type: "a2-highgpu-2g"
        vcpu: 1
        price: 20
        gpu: 1
      - region: "us-east1"
        component: "Compute Instance"
        instance_type: "e2-standard-8"
        vcpu: 1
        price: 5
        gpu: 0
```

## Running the Script

Make the script executable:

```bash
chmod +x custom-pricing-upload.sh
```

Run the script:

```bash
./custom-pricing-upload.sh 
```

## Summary

1. **Reads Kubernetes config** from YAML
2. **Auto-discovers the service port** (e.g., kubetally-pricing-service:80)
3. **Picks a random local port**
4. **Starts a background port-forward** to that service
5. **Converts pricing data** in YAML → CSV
6. **Uploads CSV** to:
```
http://localhost:<random_port>/api/v1/prices
```

## 📝 Notes

- Ensure the YAML configuration file is correctly formatted and contains all necessary fields. 📄
- The script will exit with an error if any critical steps fail unless configured to skip on failure. ❌
- Paths specified in the YAML file should be relative to the `base_path` unless absolute paths are used. 📁

## 🛠️ Troubleshooting

- **Missing Binaries**: Ensure all required binaries are installed and accessible in your system's `PATH`. ⚠️
- **Cluster Access Issues**: Verify that kubeconfig files are correctly configured and that the script can access the clusters specified in the YAML configuration. 🔧
- **Timeouts**: If a component fails to install within the specified timeout, increase the `verify_install_timeout` in the YAML file. ⏳
