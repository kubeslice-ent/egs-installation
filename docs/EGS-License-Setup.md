---
layout: page
title: EGS License Setup Guide
description: Instructions for setting up EGS license and credentials
permalink: /docs/license-setup/
---

# EGS License Setup Guide

This document provides step-by-step instructions for obtaining and applying the EGS (Elastic GPU Service) license required for KubeSlice Controller operation.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [1. EGS Registration Process](#1-egs-registration-process)
- [2. License Retrieval](#2-license-retrieval)
- [3. License Application](#3-license-application)

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

After successful registration, Avesha will process your license request and send the license YAML file to your registered email address.

**Expected Delivery Time**: Within 5 minutes of registration

### 2.2 License Email Details

You will receive an email from "Avesha Team" (`avesha@avesha.io`) with the subject "Your Elastic GPU Service License". The email contains:

- **Welcome message** explaining the EGS platform capabilities
- **Installation guidance** directing you to EGS documentation
- **License file attachment** named `egs-license.yaml`
- **Support information** with contact details at `support@avesha.io`

**📧 Email Screenshot Reference**: The email will show the license file `egs-license.yaml` as an attachment, clearly visible in the Gmail interface with the file name displayed below the email content.

<img width="397" height="766" alt="image" src="https://github.com/user-attachments/assets/f332bbb4-3c6a-4e18-acff-23ec86b5747b" />


### 2.3 License File Format

The license file will be named:
```
egs-license.yaml
```

This file is attached to the email and contains your EGS license configuration.

### 2.4 License File Contents

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
kubectl apply -f egs-license.yaml

# Verify the secret was created
kubectl get secret -n kubeslice-controller
```

### 3.3 Verify License Application

Confirm the license secret was created successfully:

```bash
# Check if the secret exists
kubectl get secret -n kubeslice-controller

# Verify secret details
kubectl describe secret egs-license-file -n kubeslice-controller
```

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
