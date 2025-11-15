#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kube-system"
RELEASE_NAME="aws-load-balancer-controller"
DRY_RUN="${DRY_RUN:-false}"

echo "🔎 Checking for AWS Load Balancer Controller in namespace: $NAMESPACE"

if ! kubectl get deployment "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "No aws-load-balancer-controller deployment found. Nothing to remove."
  exit 0
fi

echo "🛑 Found AWS Load Balancer Controller:"
kubectl get deployment "$RELEASE_NAME" -n "$NAMESPACE"
echo

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry-run enabled. Exit safely. No changes made."
  exit 0
fi

echo "🔥 Deleting AWS Load Balancer Controller deployment..."
kubectl delete deployment "$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found

echo "🧹 Deleting service account..."
kubectl delete sa "$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found

echo "🔐 Deleting associated ClusterRole & ClusterRoleBinding..."
kubectl delete clusterrole "$RELEASE_NAME" --ignore-not-found
kubectl delete clusterrolebinding "$RELEASE_NAME" --ignore-not-found

echo "⚠️ Optionally removing CRDs (if you want):"
echo "kubectl delete crd ingressclasses.networking.k8s.io"
echo "kubectl delete crd targetgroupbindings.elbv2.k8s.aws"
echo
echo "⚙ Waiting for resources to fully terminate..."
sleep 5

echo "🔍 Verifying..."
kubectl get pods -n "$NAMESPACE" | grep -i 'load-balancer' || true

echo
echo "✅ AWS Load Balancer Controller cleanup complete."
