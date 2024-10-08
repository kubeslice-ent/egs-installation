# Kubeslice Enterprise Worker Helm Charts



The Slice Operator, also known as a Kubeslice Worker is a Kubernetes Operator component that manages the life-cycle of the KubeSlice related Custom Resource Definitions (CRDs). Please refer to the [documentation](https://docs.avesha.io/documentation/enterprise/1.6.0/architecture) for more details.

# Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

Once Helm is set up properly, add the repo as follows:

```console
helm repo add kubeslice https://kubeslice.aveshalabs.io/repository/kubeslice-helm-ent-prod/ 
```

You can then run `helm search repo kubeslice` to see the charts.

## Setting Up Kubeslice Worker

### Install Chart

For setting up Worker Operator on cloud platforms, refer to the [Kubeslice Worker Installation on Cloud](https://docs.avesha.io/documentation/enterprise/1.6.0/install-kubeslice/yaml/yaml-controller-install).

### Uninstall Chart

Please refer the following Kubeslice Worker [uninstallation](https://docs.avesha.io/documentation/enterprise/1.6.0/uninstall-kubeslice/) steps.

### Upgrading Chart

```console
helm upgrade [RELEASE_NAME] kubeslice/kubeslice-worker [flags]
```

Guide
---
A full and comprehensive documentation is available on our enterprise [documentation](https://docs.avesha.io/documentation/enterprise/) website.
