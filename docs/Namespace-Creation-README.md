---
layout: page
title: Namespace Creation Script
description: Script for pre-creating required namespaces in Kubernetes
permalink: /docs/namespace-creation/
---

# Namespace Creation Script

This script automates the creation of Kubernetes namespaces with specified annotations and labels based on a YAML configuration file. It dynamically supports multiple Kubernetes contexts and provides detailed success/failure logs with a final summary.

## Features

- Dynamically processes namespaces and contexts from an input YAML file.
- Supports multiple Kubernetes contexts in a single execution.
- Logs detailed success/failure information for each namespace creation.
- Provides a summary of operations at the end.
- Handles annotations and labels for each namespace.
- Deletes temporary YAML files after applying the configuration.

## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and configured.
- [yq](https://github.com/mikefarah/yq) installed for parsing YAML files.

## Script Parameters

| Parameter               | Description                                                |
|-------------------------|------------------------------------------------------------|
| `--input-yaml`          | Path to the input YAML file containing namespace definitions. |
| `--kubeconfig`          | Path to the Kubernetes kubeconfig file.                    |
| `--kubecontext-list`    | Comma-separated list of Kubernetes contexts to process.    |
| `--help` or `-h`        | Display the help message and usage information.            |

## Input YAML Format

The input YAML file should follow this format:

```yaml
auto_create_namespace: true
namespaces:
  - name: egs-gpu-operator
    annotations:
      - key: application
        value: egs
    labels:
      - key: avesha-tower-name
        value: development
      - key: application
        value: egs

  - name: egs-monitoring
    annotations:
      - key: application
        value: egs
    labels:
      - key: avesha-tower-name
        value: development
      - key: application
        value: egs
```

## Usage

### Running the Script

Save the script as `create-namespaces.sh` and make it executable:

```bash
chmod +x create-namespaces.sh
```

Run the script with the desired parameters:

```bash
./create-namespaces.sh \
  --input-yaml namespace-input.yaml \
  --kubeconfig ~/.kube/config \
  --kubecontext-list context1,context2,context3
```

### Help Option

To see usage information, run:

```bash
./create-namespaces.sh --help
```

## Output Example

### Console Logs
```bash
🔄 Processing context: context1
🔧 Creating namespace: egs-gpu-operator in context: context1
✅ Successfully created namespace: egs-gpu-operator in context: context1
🔧 Creating namespace: egs-monitoring in context: context1
❌ Failed to create namespace: egs-monitoring in context: context1
   Reason: Namespace already exists

📋 Summary:
✅ Successful operations: 1
   - egs-gpu-operator (context: context1)
❌ Failed operations: 1
   - egs-monitoring (context: context1): Namespace already exists
```

## Summary

This script simplifies the namespace creation process in Kubernetes, making it ideal for environments with multiple clusters and namespaces. Customize the input YAML to suit your needs and track results through the detailed logs and summary provided.

## Related Files

- **`create-namespaces.sh`**: The main namespace creation script
- **`namespace-input.yaml`**: Example input configuration file
