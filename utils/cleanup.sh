#!/usr/bin/env bash
set -euo pipefail

cleanup_aws_lb_controller() {
  local NAMESPACE="${1:-kube-system}"
  local RELEASE_NAME="${2:-aws-load-balancer-controller}"
  local DRY_RUN="${3:-false}"

  echo "🔎 Checking for AWS Load Balancer Controller in namespace: $NAMESPACE"

  if ! kubectl get deployment "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "No aws-load-balancer-controller deployment found. Nothing to remove."
    return 0
  fi

  echo "🛑 Found AWS Load Balancer Controller:"
  kubectl get deployment "$RELEASE_NAME" -n "$NAMESPACE"
  echo

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry-run enabled. Exit safely. No changes made."
    return 0
  fi

  echo "🔥 Deleting AWS Load Balancer Controller deployment..."
  kubectl delete deployment "$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found

  echo "🧹 Deleting service account..."
  kubectl delete sa "$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found

  echo "🔐 Deleting associated ClusterRole & ClusterRoleBinding..."
  kubectl delete clusterrole "$RELEASE_NAME" --ignore-not-found
  kubectl delete clusterrolebinding "$RELEASE_NAME" --ignore-not-found

  echo "⚠️ Optionally removing CRDs (manual step):"
  echo "kubectl delete crd ingressclasses.networking.k8s.io"
  echo "kubectl delete crd targetgroupbindings.elbv2.k8s.aws"
  echo

  echo "⚙ Waiting for resources to fully terminate..."
  sleep 5

  echo "🔍 Verifying..."
  kubectl get pods -n "$NAMESPACE" | grep -i 'load-balancer' || true

  echo
  echo "✅ AWS Load Balancer Controller cleanup complete."
  return 0
}

#!/usr/bin/env bash
set -euo pipefail

delete_cluster_load_balancers() {
  local CLUSTER_NAME="${1:?Cluster name is required}"
  local REGION="${2:-eu-west-1}"
  local DRY_RUN="${3:-true}"

  echo "🔎 Searching for load balancers tagged with: elbv2.k8s.aws/cluster = ${CLUSTER_NAME}"
  echo "Region: $REGION"
  echo "Dry run mode: $DRY_RUN"
  echo

  local LB_ARN_LIST
  LB_ARN_LIST=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[].LoadBalancerArn" --output text)

  if [[ -z "$LB_ARN_LIST" ]]; then
    echo "No load balancers found."
    return 0
  fi

  local TO_DELETE=()

  for lb_arn in $LB_ARN_LIST; do
    local tag_value
    tag_value=$(aws elbv2 describe-tags --resource-arns "$lb_arn" \
      --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster'].Value | [0]" \
      --region "$REGION" --output text || echo "")

    if [[ "$tag_value" == "$CLUSTER_NAME" ]]; then
      TO_DELETE+=("$lb_arn")
    fi
  done

  if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
    echo "No load balancers found for cluster: $CLUSTER_NAME"
    return 0
  fi

  echo "🛑 Load Balancers to be deleted:"
  printf '%s\n' "${TO_DELETE[@]}"
  echo

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry-run enabled. Exiting without deleting."
    return 0
  fi

  echo "🔥 Deleting load balancers..."

  for arn in "${TO_DELETE[@]}"; do
    echo "→ Deleting $arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$REGION"
  done

  echo
  echo "⏳ Waiting for deletion..."

  for arn in "${TO_DELETE[@]}"; do
    aws elbv2 wait load-balancer-deleted --load-balancer-arns "$arn" --region "$REGION" || true
  done

  echo "✅ All matching load balancers deleted."
  return 0
}

