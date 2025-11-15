#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:?CLUSTER_NAME env var is required}"
REGION="${REGION:-eu-west-1}"
DRY_RUN="${DRY_RUN:-true}"

echo "🔎 Searching for load balancers tagged with: elbv2.k8s.aws/cluster = ${CLUSTER_NAME}"
echo "Region: $REGION"
echo "Dry run mode: $DRY_RUN"
echo

LB_ARN_LIST=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[].LoadBalancerArn" --output text)

if [[ -z "$LB_ARN_LIST" ]]; then
  echo "No load balancers found."
  exit 0
fi

TO_DELETE=()

for lb_arn in $LB_ARN_LIST; do
  tag_value=$(aws elbv2 describe-tags --resource-arns "$lb_arn" \
    --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster'].Value | [0]" \
    --region "$REGION" --output text || echo "")

  if [[ "$tag_value" == "$CLUSTER_NAME" ]]; then
    TO_DELETE+=("$lb_arn")
  fi
done

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  echo "No load balancers found for cluster: $CLUSTER_NAME"
  exit 0
fi

echo "🛑 Load Balancers to be deleted:"
printf '%s\n' "${TO_DELETE[@]}"
echo

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry-run enabled. Exiting without deleting."
  exit 0
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
