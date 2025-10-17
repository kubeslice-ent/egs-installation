# Prometheus Setup with NGINX Ingress, cert-manager, and Mutual TLS (mTLS)

This document provides a **complete step-by-step guide** to set up **Prometheus** on Kubernetes using:
- **NGINX Ingress Controller**
- **cert-manager** (for automatic TLS certificates)
- **Client Certificate Authentication (Mutual TLS)**

---

## 📋 Overview

This setup covers:

1. NGINX Ingress Controller setup  
2. cert-manager installation  
3. Prometheus deployment  
4. Server and Client certificate generation  
5. Kubernetes secrets management  
6. Ingress resource configuration  
7. Browser/client certificate usage and testing  

---

## 🚀 1. Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx   --namespace ingress-nginx   --create-namespace

kubectl get svc -n ingress-nginx   # Note the EXTERNAL-IP for DNS
```

---

## 🔐 2. Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager   --namespace cert-manager   --create-namespace   --set installCRDs=true

kubectl get pods -n cert-manager
```

> **Note:** Enable the workaround for HTTP01 challenge if using client certificate authentication:

```bash
helm upgrade cert-manager jetstack/cert-manager   --namespace cert-manager   --set config.featureGates.ACMEHTTP01IngressPathTypeExact=false
```

---

## 📈 3. Deploy Prometheus

Example using **kube-prometheus-stack**:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack   --namespace egs-monitoring   --create-namespace

kubectl get svc -n egs-monitoring  # Find service name for ingress backend
```

> **Note:** Use the Prometheus charts provided in the **egs-installation** package for deploying on the target cluster.

---

## 🌐 4. Configure DNS

Map your DNS record to the NGINX Ingress LoadBalancer IP:

```
prometheus.dev.aveshalabs.io → <EXTERNAL-IP of ingress-nginx>
```

---

## 📜 5. Create ClusterIssuer for cert-manager

Create a file named **`cluster-issuer.yaml`**:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@yourdomain.com   # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply the issuer:

```bash
kubectl apply -f cluster-issuer.yaml
```

---

## 🔑 6. Generate CA, Server, and Client Certificates

### a. Create CA Certificate

```bash
openssl genpkey -algorithm RSA -out ca.key -pkeyopt rsa_keygen_bits:2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650   -out ca.crt -subj "/CN=K8sClientCA"
```

### b. Generate Server Certificate

```bash
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key server.key -out server.csr   -subj "/CN=prometheus.dev.aveshalabs.io"

cat > san.ext <<EOF
subjectAltName = DNS:prometheus.dev.aveshalabs.io
extendedKeyUsage = serverAuth
EOF

openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key   -CAcreateserial -out server.crt -days 365 -sha256 -extfile san.ext
```

### c. Generate Client Certificate

```bash
openssl genpkey -algorithm RSA -out client.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key client.key -out client.csr -subj "/CN=my-client"

cat > client.ext <<EOF
extendedKeyUsage = clientAuth
EOF

openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key   -CAcreateserial -out client.crt -days 365 -sha256 -extfile client.ext
```

---

## 🔒 7. Create Kubernetes Secrets for Certificates

```bash
kubectl create secret generic ca-secret   --from-file=ca.crt=ca.crt   -n egs-monitoring

kubectl delete secret prometheus-tls -n egs-monitoring  # If it exists

kubectl create secret tls prometheus-tls   --cert=server.crt   --key=server.key   -n egs-monitoring
```

---

## ⚙️ 8. Configure Prometheus Ingress Resource

Create **`prometheus-ingress.yaml`**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: egs-monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/auth-tls-verify-client: "on"
    nginx.ingress.kubernetes.io/auth-tls-secret: "egs-monitoring/ca-secret"
    nginx.ingress.kubernetes.io/auth-tls-verify-depth: "1"
    nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.dev.aveshalabs.io   # Your domain name
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
  tls:
  - hosts:
    - prometheus.dev.aveshalabs.io
    secretName: prometheus-tls
```

Apply the ingress:

```bash
kubectl apply -f prometheus-ingress.yaml
```

---

## 🧪 9. Test Functionality

### With Client Certificate:
```bash
curl --cert client.crt --key client.key https://prometheus.dev.aveshalabs.io
```

### Without Certificate:
```bash
curl https://prometheus.dev.aveshalabs.io
# Expected: 400 Bad Request
```

# 🔐 TLS Authentication for Prometheus

This guide explains how to configure **TLS-based authentication** for secure communication between **Prometheus** and the **API Gateway** using Kubernetes secrets.

---

## 📘 Overview

The **API Gateway** supports **TLS-based authentication** to ensure that metrics are exchanged over an **encrypted and authenticated channel** between Prometheus and the gateway.

> **Info**
> - Applicable for **EGS version 1.15.0 and later**  
> - **TLS-based Prometheus authentication** is supported **only** for **Ingress endpoints**  
> - It does **not** apply to other service types such as:
>   - LoadBalancer  
>   - NodePort  
>   - ClusterIP  

---

## ✅ Prerequisites

Before configuring TLS-based Prometheus authentication, ensure that:

1. You have a **valid TLS certificate** and **private key** for the API Gateway.  
   - The certificate should be issued by a **trusted Certificate Authority (CA)**.  
2. You have **access to the controller cluster** where the API Gateway is deployed.  
3. You have the **base64-encoded** values of your TLS certificate, private key, and CA certificate.

---

## 🧩 Define Secrets with TLS Certificates

To define secrets for TLS authentication, follow these steps.

### 1. Create the `secrets.yaml` file

Create a file named **`secrets.yaml`** with the following content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <cluster-name>-prometheus-cert     # Replace <cluster-name> with your worker cluster name
  namespace: <project-namespace>           # Replace <project-namespace> with your project namespace
data:
  ca.crt: <ca.crt base64 encoded>          # Base64-encoded CA certificate
  tls.crt: <client.crt base64 encoded>     # Base64-encoded TLS certificate
  tls.key: <client.key base64 encoded>     # Base64-encoded private key
```

> 💡 **Tip:** You can encode files using:
> ```bash
> base64 -w 0 ca.crt
> base64 -w 0 client.crt
> base64 -w 0 client.key
> ```

---

### 2. Apply the Secret to the Cluster

Run the following command to apply the secret:

```bash
kubectl apply -f secrets.yaml
```

This will create the TLS secret on the **controller cluster**, allowing Prometheus to authenticate securely over TLS.

---

## 🧾 Summary

You have now:
- Created a Kubernetes secret with TLS certificates  
- Enabled secure, encrypted communication between Prometheus and the API Gateway  
- Ensured authentication using trusted CA-based certificates  

---

## 🔍 References

- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Prometheus Configuration Docs](https://prometheus.io/docs/)
