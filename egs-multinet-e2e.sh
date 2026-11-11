#!/usr/bin/env bash
# egs-multinet-e2e.sh - end-to-end check that a single-network and a multi-network
# workspace (slice) work side by side across two worker clusters.
#
# What it checks, per mode:
#   - the controller accepts the SliceConfig and both workers reconcile the slice
#   - multi-network: <slice>-multinet-gateway namespace, EnvoyProxy, GatewayClass and
#     Gateway exist and the gateway pods run on both workers
#   - app pods: single-network pods get the NSM sidecar, multi-network pods do not
#   - a client on worker 1 reaches a service exported (with ports) from worker 2
#     at <svc>.<ns>.svc.slice.local
#
# Usage:
#   ./egs-multinet-e2e.sh --controller-kubeconfig ctrl.yaml --project kubeslice-avesha \
#       --worker worker-1=w1.yaml --worker worker-2=w2.yaml [--keep] [--modes single,multi]
#
# Needs: bash, kubectl. Workers need multinet.enabled=true in the worker chart and the
# Envoy Gateway CRDs (the EGS installer's envoy-gateway app).
set -euo pipefail

CTRL_KC="" PROJECT_NS="" PREFIX="e2e" KEEP=false TIMEOUT=600 MODES="single,multi"
SERVER_IMAGE="nginxinc/nginx-unprivileged:1.27-alpine" CLIENT_IMAGE="curlimages/curl:8.10.1"
QOS_PROFILE="default"
WORKERS=() KCS=()

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --controller-kubeconfig) CTRL_KC="$2"; shift 2 ;;
    --project) PROJECT_NS="$2"; shift 2 ;;
    --worker) WORKERS+=("${2%%=*}"); KCS+=("${2#*=}"); shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --modes) MODES="$2"; shift 2 ;;
    --qos-profile) QOS_PROFILE="$2"; shift 2 ;;
    --server-image) SERVER_IMAGE="$2"; shift 2 ;;
    --client-image) CLIENT_IMAGE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --keep) KEEP=true; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown flag: $1" >&2; usage 1 ;;
  esac
done
[ -n "$CTRL_KC" ] && [ -n "$PROJECT_NS" ] && [ "${#WORKERS[@]}" -eq 2 ] || usage 1

W1="${WORKERS[0]}" W1_KC="${KCS[0]}" W2="${WORKERS[1]}" W2_KC="${KCS[1]}"
ctrl() { kubectl --kubeconfig "$CTRL_KC" "$@"; }
w1() { kubectl --kubeconfig "$W1_KC" "$@"; }
w2() { kubectl --kubeconfig "$W2_KC" "$@"; }
wk() { local kc="$1"; shift; kubectl --kubeconfig "$kc" "$@"; }

PASS=0 FAIL=0 RESULTS=()
ok()   { PASS=$((PASS + 1)); RESULTS+=("PASS  $*"); echo "  PASS  $*"; }
bad()  { FAIL=$((FAIL + 1)); RESULTS+=("FAIL  $*"); echo "  FAIL  $*"; }
step() { printf '\n==> %s\n' "$*"; }

# wait_for <description> <seconds> <command...>: retries the command every 5s.
wait_for() {
  local what="$1" secs="$2"; shift 2
  local end=$((SECONDS + secs))
  until "$@" >/dev/null 2>&1; do
    [ "$SECONDS" -ge "$end" ] && { bad "$what (timed out after ${secs}s)"; return 1; }
    sleep 5
  done
  ok "$what"
}

slice_name() { echo "${PREFIX}-$1"; }          # e2e-single / e2e-multi
app_ns()     { echo "${PREFIX}-$1-app"; }
subnet()     { [ "$1" = single ] && echo "10.231.0.0/16" || echo "10.232.0.0/16"; }
mode_value() { [ "$1" = single ] && echo "single-network" || echo "multi-network"; }

cleanup() {
  [ "$KEEP" = true ] && { echo "--keep set: leaving test slices and namespaces"; return; }
  step "Cleaning up"
  for m in ${MODES//,/ }; do
    local s ns; s=$(slice_name "$m"); ns=$(app_ns "$m")
    for kc in "$W1_KC" "$W2_KC"; do
      wk "$kc" -n "$ns" delete serviceexport,deploy,svc,pod --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
    done
    ctrl -n "$PROJECT_NS" patch sliceconfig "$s" --type=merge \
      -p '{"spec":{"namespaceIsolationProfile":{"applicationNamespaces":[]}}}' >/dev/null 2>&1 || true
    sleep 10
    ctrl -n "$PROJECT_NS" delete sliceconfig "$s" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    for kc in "$W1_KC" "$W2_KC"; do wk "$kc" delete ns "$ns" --ignore-not-found --wait=false >/dev/null 2>&1 || true; done
  done
}
trap cleanup EXIT

step "Preflight"
for i in 0 1; do
  kc="${KCS[$i]}" name="${WORKERS[$i]}"
  if wk "$kc" get crd envoyproxies.gateway.envoyproxy.io >/dev/null 2>&1; then
    ok "$name has the Envoy Gateway CRDs"
  else
    bad "$name is missing envoyproxies.gateway.envoyproxy.io (install the envoy-gateway app)"
  fi
  flag=$(wk "$kc" -n kubeslice-system get deploy kubeslice-operator \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="manager")].env[?(@.name=="ENABLE_MULTINET_RECONCILER")].value}' 2>/dev/null || true)
  if [ "$flag" = "true" ]; then ok "$name has ENABLE_MULTINET_RECONCILER=true"
  else bad "$name has ENABLE_MULTINET_RECONCILER='${flag:-unset}' (set multinet.enabled=true)"; fi
done
[ "$FAIL" -eq 0 ] || { echo "Preflight failed; fix the worker setup first."; exit 1; }

step "Creating slices"
for m in ${MODES//,/ }; do
  s=$(slice_name "$m") ns=$(app_ns "$m")
  for kc in "$W1_KC" "$W2_KC"; do wk "$kc" create ns "$ns" --dry-run=client -o yaml | wk "$kc" apply -f - >/dev/null; done
  cat <<EOF | ctrl apply -f - >/dev/null
apiVersion: controller.kubeslice.io/v1alpha1
kind: SliceConfig
metadata:
  name: $s
  namespace: $PROJECT_NS
spec:
  sliceSubnet: $(subnet "$m")
  sliceType: Application
  overlayNetworkDeploymentMode: $(mode_value "$m")
  maxClusters: 16
  sliceIpamType: Local
  sliceGatewayProvider:
    sliceGatewayType: OpenVPN
    sliceCaType: Local
    sliceGatewayServiceType:
      - cluster: "*"
        type: NodePort
        protocol: UDP
  standardQosProfileName: $QOS_PROFILE
  clusters: [$W1, $W2]
  namespaceIsolationProfile:
    isolationEnabled: false
    applicationNamespaces:
      - namespace: $ns
        clusters: ["*"]
EOF
  ok "controller accepted SliceConfig $s ($(mode_value "$m"))"
done

step "Waiting for workers to reconcile the slices"
for m in ${MODES//,/ }; do
  s=$(slice_name "$m")
  for i in 0 1; do
    kc="${KCS[$i]}" name="${WORKERS[$i]}"
    wait_for "$name reconciled slice $s" "$TIMEOUT" \
      bash -c "kubectl --kubeconfig '$kc' -n kubeslice-system get slice.networking.kubeslice.io '$s' -o jsonpath='{.status.sliceConfig.sliceOverlayNetworkDeploymentMode}' | grep -q ." || true
    wait_for "$name slice gateway pods for $s running" "$TIMEOUT" \
      bash -c "kubectl --kubeconfig '$kc' -n kubeslice-system get pods -l kubeslice.io/slice='$s',kubeslice.io/pod-type=slicegateway --no-headers 2>/dev/null | grep -q Running" || true
  done
done

if [[ ",$MODES," == *",multi,"* ]]; then
  step "Checking the per-slice Envoy gateway (multi-network)"
  s=$(slice_name multi) gwns="$(slice_name multi)-multinet-gateway"
  for i in 0 1; do
    kc="${KCS[$i]}" name="${WORKERS[$i]}"
    wait_for "$name has namespace $gwns" "$TIMEOUT" wk "$kc" get ns "$gwns" || continue
    wait_for "$name has EnvoyProxy in $gwns" 120 \
      bash -c "kubectl --kubeconfig '$kc' -n '$gwns' get envoyproxies.gateway.envoyproxy.io --no-headers | grep -q ." || true
    wait_for "$name has GatewayClass for $s" 120 \
      bash -c "kubectl --kubeconfig '$kc' get gatewayclass --no-headers | grep -q '$s'" || true
    wait_for "$name has a Gateway in $gwns" 120 \
      bash -c "kubectl --kubeconfig '$kc' -n '$gwns' get gateway --no-headers | grep -q ." || true
    wait_for "$name Envoy gateway pods running in $gwns" "$TIMEOUT" \
      bash -c "! kubectl --kubeconfig '$kc' -n '$gwns' get pods --no-headers 2>/dev/null | grep -v -E 'Running|Completed' | grep -q . && kubectl --kubeconfig '$kc' -n '$gwns' get pods --no-headers | grep -q Running" || true
  done
fi

step "Deploying a server on $W2 and a client on $W1"
for m in ${MODES//,/ }; do
  s=$(slice_name "$m") ns=$(app_ns "$m")
  w2 -n "$ns" create deployment echo --image="$SERVER_IMAGE" --port=8080 --dry-run=client -o yaml | w2 apply -f - >/dev/null
  w2 -n "$ns" expose deployment echo --port=80 --target-port=8080 --dry-run=client -o yaml | w2 apply -f - >/dev/null
  cat <<EOF | w2 apply -f - >/dev/null
apiVersion: networking.kubeslice.io/v1beta1
kind: ServiceExport
metadata:
  name: echo
  namespace: $ns
spec:
  slice: $s
  selector:
    matchLabels:
      app: echo
  ports:
    - name: http
      containerPort: 8080
      protocol: TCP
      servicePort: 80
      serviceProtocol: HTTP
EOF
  ok "ServiceExport echo created in $ns on $W2 (port 80 -> 8080)"
  w1 -n "$ns" delete pod client --ignore-not-found --wait=true >/dev/null 2>&1 || true
  w1 -n "$ns" run client --image="$CLIENT_IMAGE" --restart=Never \
    --dry-run=client -o yaml --command -- sleep 3600 | w1 apply -f - >/dev/null
done

step "Checking sidecars and cross-cluster requests"
for m in ${MODES//,/ }; do
  ns=$(app_ns "$m")
  wait_for "$W2 echo server ready in $ns" "$TIMEOUT" w2 -n "$ns" rollout status deploy/echo --timeout=10s || true
  wait_for "$W1 client pod ready in $ns" "$TIMEOUT" w1 -n "$ns" wait pod/client --for=condition=Ready --timeout=10s || true
  containers=$(w1 -n "$ns" get pod client -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)
  count=$(echo "$containers" | wc -w | tr -d ' ')
  if [ "$m" = single ]; then
    [ "$count" -gt 1 ] && ok "single-network client pod has the overlay sidecar ($containers)" \
                       || bad "single-network client pod has no sidecar ($containers)"
  else
    [ "$count" -eq 1 ] && ok "multi-network client pod has no overlay sidecar ($containers)" \
                       || bad "multi-network client pod has extra containers ($containers)"
  fi
  wait_for "$W1 has ServiceImport echo in $ns" "$TIMEOUT" w1 -n "$ns" get serviceimport echo || true
  url="http://echo.$ns.svc.slice.local:80/"
  wait_for "$(mode_value "$m"): $W1 client reaches $url" "$TIMEOUT" \
    w1 -n "$ns" exec client -- curl -fsS -m 5 -o /dev/null "$url" || true
done

step "Summary"
printf '%s\n' "${RESULTS[@]}"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
