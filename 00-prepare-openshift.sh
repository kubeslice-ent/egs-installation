#!/bin/bash
#
# EGS Pre-Installation Script for OpenShift
# This script must be run BEFORE egs-install-prerequisites.sh
# It creates namespaces and grants SCC permissions required by EGS components
#

set -e

echo "========================================="
echo "EGS OpenShift Preparation Script"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Creating required namespaces...${NC}"
kubectl create namespace egs-gpu-operator 2>/dev/null || echo "  ✓ egs-gpu-operator namespace already exists"
kubectl create namespace egs-monitoring 2>/dev/null || echo "  ✓ egs-monitoring namespace already exists"
kubectl create namespace kt-postgresql 2>/dev/null || echo "  ✓ kt-postgresql namespace already exists"
kubectl create namespace envoy-gateway-system 2>/dev/null || echo "  ✓ envoy-gateway-system namespace already exists"
kubectl create namespace kubeslice-controller 2>/dev/null || echo "  ✓ kubeslice-controller namespace already exists"
kubectl create namespace kubeslice-system 2>/dev/null || echo "  ✓ kubeslice-system namespace already exists"
kubectl create namespace spire 2>/dev/null || echo "  ✓ spire namespace already exists"
kubectl create namespace kubeslice-nsm-webhook-system 2>/dev/null || echo "  ✓ kubeslice-nsm-webhook-system namespace already exists"
echo -e "${GREEN}✓ All namespaces created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Granting 'anyuid' SCC to all service accounts in EGS namespaces...${NC}"
echo "  This allows pods to run with any UID (required for Prometheus, PostgreSQL, etc.)"
oc adm policy add-scc-to-group anyuid system:serviceaccounts:egs-monitoring
oc adm policy add-scc-to-group anyuid system:serviceaccounts:egs-gpu-operator
oc adm policy add-scc-to-group anyuid system:serviceaccounts:kt-postgresql
oc adm policy add-scc-to-group anyuid system:serviceaccounts:envoy-gateway-system
oc adm policy add-scc-to-group anyuid system:serviceaccounts:kubeslice-controller
oc adm policy add-scc-to-group anyuid system:serviceaccounts:kubeslice-system
echo -e "${GREEN}✓ anyuid SCC granted to all EGS namespaces${NC}"
echo ""

echo -e "${YELLOW}Step 3: Granting 'privileged' SCC for GPU and system components...${NC}"
echo "  This allows GPU operator to access host devices"
oc adm policy add-scc-to-group privileged system:serviceaccounts:egs-gpu-operator
oc adm policy add-scc-to-group privileged system:serviceaccounts:kube-system
echo -e "${GREEN}✓ privileged SCC granted${NC}"
echo ""

echo -e "${YELLOW}Step 4: Granting SPIRE and NSM required permissions...${NC}"
echo "  Granting privileged SCC to SPIRE namespace (for SPIRE agent/server)"
oc adm policy add-scc-to-group privileged system:serviceaccounts:spire
oc adm policy add-scc-to-group anyuid system:serviceaccounts:spire
oc adm policy add-scc-to-group hostmount-anyuid system:serviceaccounts:spire
oc adm policy add-scc-to-group hostaccess system:serviceaccounts:spire
echo "  Granting privileged SCC to NSM webhook namespace"
oc adm policy add-scc-to-group privileged system:serviceaccounts:kubeslice-nsm-webhook-system
oc adm policy add-scc-to-group anyuid system:serviceaccounts:kubeslice-nsm-webhook-system
echo "  Granting privileged SCC to nsmgr-acc service account (for hostPath volumes)"
oc adm policy add-scc-to-user privileged -z nsmgr-acc -n kubeslice-system
echo -e "${GREEN}✓ SPIRE and NSM permissions granted${NC}"
echo ""

echo -e "${YELLOW}Step 5: Setting pod security level for kubeslice-system...${NC}"
echo "  Setting namespace to 'privileged' to allow CSI drivers and hostPath volumes"
oc label namespace kubeslice-system pod-security.kubernetes.io/enforce=privileged --overwrite 2>/dev/null || true
oc label namespace kubeslice-system pod-security.kubernetes.io/audit=privileged --overwrite 2>/dev/null || true
oc label namespace kubeslice-system pod-security.kubernetes.io/warn=privileged --overwrite 2>/dev/null || true
echo -e "${GREEN}✓ Pod security level set${NC}"
echo ""

echo -e "${YELLOW}Step 6: Configuring NSM admission webhook to not block pods...${NC}"
echo "  Setting webhook failurePolicy to 'Ignore' (will be applied after EGS installation)"
echo "  Note: This ensures pods can be created even if webhook is temporarily unavailable"
cat > /tmp/nsm-webhook-fix.sh << 'WEBHOOK_EOF'
#!/bin/bash
# Wait for webhook to be created by EGS installer
sleep 5
if oc get mutatingwebhookconfiguration nsm-mutating-webhook-configuration 2>/dev/null; then
  echo "Found NSM webhook, patching failurePolicy..."
  oc patch mutatingwebhookconfiguration nsm-mutating-webhook-configuration \
    --type='json' \
    -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]' 2>/dev/null || true
  echo "✓ NSM webhook configured"
else
  echo "NSM webhook not found yet (will be created during EGS installation)"
fi
WEBHOOK_EOF
chmod +x /tmp/nsm-webhook-fix.sh
echo -e "${GREEN}✓ Webhook fix script created at /tmp/nsm-webhook-fix.sh${NC}"
echo ""

echo "========================================="
echo -e "${GREEN}✓ OpenShift preparation complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Run: ./egs-install-prerequisites.sh --input-yaml egs-installer-config.yaml"
echo "  2. After EGS installation completes, run: /tmp/nsm-webhook-fix.sh"
echo "     (This fixes NSM webhook to not block pod creation)"
echo "  3. All components will work properly with OpenShift security policies"
echo ""



