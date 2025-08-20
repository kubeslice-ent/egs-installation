# EGS License Setup Guide

This document provides step-by-step instructions for obtaining and applying the EGS (Elastic GPU Service) license required for KubeSlice Controller operation.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [1. EGS Registration Process](#1-egs-registration-process)
- [2. License Retrieval](#2-license-retrieval)
- [3. License Application](#3-license-application)
- [4. Verification Steps](#4-verification-steps)
- [5. Troubleshooting](#5-troubleshooting)

## Overview

The EGS license is a mandatory requirement for operating the KubeSlice Controller with Elastic GPU Service capabilities. The license enables GPU sharing, observability, and cost management features across your Kubernetes clusters.

## Prerequisites

- Access to the internet for EGS registration
- Valid email address for license delivery
- Access to the Kubernetes cluster where KubeSlice Controller will be installed
- `kubectl` configured and authenticated to the controller cluster
- Cluster administrator privileges

## 1. EGS Registration Process

### 1.1 Access EGS Registration Portal

Navigate to the [EGS Registration page](https://avesha.io/egs-registration) to begin the license acquisition process.

### 1.2 Complete Registration Form

Fill out the registration form with the following required information:

- **Full Name**: Your complete name
- **Company Name**: Your organization's name
- **Title/Position/Role**: Your role in the organization
- **Work Email**: Your professional email address
- **Cluster Fingerprint**: Unique identifier for your Kubernetes cluster

### 1.3 Cluster Fingerprint Generation

To determine your cluster fingerprint, run the following command in your controller cluster:

```bash
# Generate cluster fingerprint
kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'
```

**Note**: This command generates a unique identifier based on your cluster's kube-system namespace creation timestamp and UID, which serves as the cluster fingerprint for license registration.

### 1.4 Submit Registration

After completing all required fields:
1. Review the information for accuracy
2. Accept the Terms and Conditions
3. Click the "Register" button to submit your application

### 1.5 Registration Confirmation

Upon successful registration, you will receive:
- An immediate confirmation message
- A confirmation email with registration details
- License processing notification

## 2. License Retrieval

### 2.1 Check Email for License

After successful registration, Avesha will process your license request and send the license secret YAML file to your registered email address.

**Expected Delivery Time**: 1-2 business days (may vary based on request volume)

### 2.2 License File Format

The license file will be named in the following format:
```
egs-license-secret-<customer-name>.yaml
```

**Example**: `egs-license-secret-acme-corp.yaml`

### 2.3 License File Contents

The license file contains a Kubernetes secret with the following structure:

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: egs-license-file
  namespace: kubeslice-controller
  labels:
    app.kubernetes.io/managed-by: kubeslice-controller
    app.kubernetes.io/license-type: egs_30_days_trial_license
data:
  customer-name: <base64-encoded-customer-name>
  grace-period: <base64-encoded-grace-period>
  license-expiration: <base64-encoded-expiration-date>
  license-type: <base64-encoded-license-type>
  license-created: <base64-encoded-creation-date>
  license-updated: <base64-encoded-update-date>
  license-id: <base64-encoded-license-id>
  license.key: <base64-encoded-license-key>
  machine.file: <base64-encoded-machine-file>
  gpu-count: <base64-encoded-gpu-count>
  overage: <base64-encoded-overage-limit>
```

**Note**: The actual values in the `data` section are base64-encoded strings. The sample above shows the structure with placeholder values for security reasons.

## 3. License Application

### 3.1 Create Required Namespace

Before applying the license, ensure the `kubeslice-controller` namespace exists:

```bash
# Create the kubeslice-controller namespace
kubectl create namespace kubeslice-controller

# Verify namespace creation
kubectl get namespace kubeslice-controller
```

### 3.2 Apply License Secret

Apply the license secret to your controller cluster:

```bash
# Apply the license secret
kubectl apply -f egs-license-secret-<customer-name>.yaml

# Example:
kubectl apply -f egs-license-secret-acme-corp.yaml
```

### 3.3 Verify License Application

Confirm the license secret was created successfully:

```bash
# Check if the secret exists
kubectl get secret -n kubeslice-controller

# Verify secret details
kubectl describe secret egs-license-file -n kubeslice-controller
```

## 4. Verification Steps

### 4.1 License Secret Verification

```bash
# Verify secret exists and has correct data
kubectl get secret egs-license-file -n kubeslice-controller -o yaml

# Check secret labels and annotations
kubectl get secret egs-license-file -n kubeslice-controller --show-labels
```

### 4.2 Namespace Verification

```bash
# Verify namespace exists and is ready
kubectl get namespace kubeslice-controller

# Check namespace labels and annotations
kubectl get namespace kubeslice-controller -o yaml
```

### 4.3 License Status Check

After installing KubeSlice Controller, verify the license is being used:

```bash
# Check controller logs for license validation
kubectl logs -f deployment/kubeslice-controller-manager -n kubeslice-controller | grep -i license

# Verify license status in controller status
kubectl get kubesliceconfig -n kubeslice-system -o yaml
```

## 5. Troubleshooting

### 5.1 Registration Issues

**Problem**: Registration form submission fails
**Solution**: 
- Ensure all required fields are completed
- Verify email format is correct
- Check internet connection
- Try refreshing the page and resubmitting

**Problem**: No confirmation email received
**Solution**:
- Check spam/junk folder
- Verify email address was entered correctly
- Wait 24-48 hours for processing
- Contact Avesha support if issue persists

### 5.2 License File Issues

**Problem**: License file not received
**Solution**:
- Check email delivery timeframe (1-2 business days)
- Verify email address in registration
- Contact Avesha support for assistance
- Check if license request was approved

**Problem**: License file format is incorrect
**Solution**:
- Ensure file has `.yaml` extension
- Verify file contains valid YAML content
- Check if file is corrupted during download
- Re-download the license file

### 5.3 Application Issues

**Problem**: Namespace creation fails
**Solution**:
- Verify cluster permissions: `kubectl auth can-i create namespace`
- Check if namespace already exists: `kubectl get namespace kubeslice-controller`
- Ensure cluster is accessible and healthy

**Problem**: License secret application fails
**Solution**:
- Verify namespace exists: `kubectl get namespace kubeslice-controller`
- Check file syntax: `kubectl apply --dry-run=client -f egs-license-secret-<customer-name>.yaml`
- Verify cluster permissions: `kubectl auth can-i create secret -n kubeslice-controller`
- Check for naming conflicts with existing secrets

**Problem**: License validation fails in controller
**Solution**:
- Verify secret name matches controller configuration (`egs-license-file`)
- Check secret data format and encoding
- Ensure secret is in the correct namespace
- Review controller logs for specific error messages

## Additional Information

### License Renewal

EGS licenses typically have expiration dates. Monitor your license status and renew before expiration to avoid service interruption.

### Support Contacts

For license-related issues or questions:
- **Email**: [support@avesha.io](mailto:support@avesha.io)
- **Documentation**: [docs.avesha.io](https://docs.avesha.io)
- **Community**: [KubeSlice Community](https://kubeslice.io/community)

### License Types

EGS offers different license tiers:
- **Trial License**: For evaluation and testing
- **Standard License**: For production workloads
- **Enterprise License**: For advanced features and support

## Next Steps

After successfully applying the license:

1. **Install KubeSlice Controller**: Follow the [EGS Controller Prerequisites](EGS-Controller-Prerequisites.md) guide
2. **Configure Monitoring**: Set up Prometheus and PostgreSQL as outlined in the prerequisites
3. **Deploy EGS Components**: Install the controller and worker components
4. **Verify Operation**: Ensure all components are functioning with the applied license

## Additional Resources

- [EGS Registration Portal](https://avesha.io/egs-registration)
- [EGS Controller Prerequisites](EGS-Controller-Prerequisites.md)
- [EGS Worker Prerequisites](EGS-Worker-Prerequisites.md)
- [KubeSlice Documentation](https://docs.avesha.io)
- [Avesha Support Portal](https://support.avesha.io)

## Support

For additional support or questions regarding EGS license setup, please refer to:
- EGS Documentation: [docs.avesha.io](https://docs.avesha.io)
- Avesha Support: [support@avesha.io](mailto:support@avesha.io)
- GitHub Issues: [EGS Repository](https://github.com/kubeslice/egs)
- Community Support: [KubeSlice Community](https://kubeslice.io/community)
