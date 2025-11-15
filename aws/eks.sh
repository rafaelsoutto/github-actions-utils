eks_login() {
  local cluster_name="$1"
  local region="$2"
  local profile="${3:-}"

  if [[ -z "$cluster_name" ]]; then
    echo "❌ eks_login: missing cluster name" >&2
    return 1
  fi

  if [[ -z "$region" ]]; then
    echo "❌ eks_login: missing AWS region" >&2
    return 1
  fi

  echo "🔐 Logging into EKS cluster: $cluster_name"
  echo "🌍 Region: $region"
  [[ -n "$profile" ]] && echo "👤 AWS Profile: $profile"

  local profile_args=()
  [[ -n "$profile" ]] && profile_args+=(--profile "$profile")

  # Update kubeconfig
  if ! aws eks update-kubeconfig \
      --region "$region" \
      --name "$cluster_name" \
      "${profile_args[@]}"; then
    echo "❌ Failed to update kubeconfig for cluster: $cluster_name" >&2
    return 2
  fi

  # Test access
  if ! kubectl get svc kube-dns -n kube-system >/dev/null 2>&1; then
    echo "⚠️  Connected, but unable to query kube-system/kube-dns" >&2
    echo "   Possible IAM or RBAC config issue."
  else
    echo "✅ Successfully connected to cluster: $cluster_name"
  fi
}
