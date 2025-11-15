eks_login() {
  local cluster_name="$1"
  local region="$2"
  local profile="${3:-}"

  log_debug "Entering eks_login() with cluster=$cluster_name, region=$region, profile=$profile"

  if [[ -z "$cluster_name" ]]; then
    log_fatal "eks_login: missing cluster name"
  fi

  if [[ -z "$region" ]]; then
    log_fatal "eks_login: missing AWS region"
  fi

  log_info "🔐 Logging into EKS cluster: $cluster_name"
  log_info "🌍 Region: $region"
  [[ -n "$profile" ]] && log_info "👤 AWS Profile: $profile"

  local profile_args=()
  if [[ -n "$profile" ]]; then
    profile_args+=(--profile "$profile")
  fi

  log_debug "Running: aws eks update-kubeconfig --name $cluster_name"
  if ! log_exec aws eks update-kubeconfig \
      --region "$region" \
      --name "$cluster_name" \
      "${profile_args[@]}"; then
    log_fatal "Failed to update kubeconfig for cluster '$cluster_name'"
  fi

  log_info "Kubeconfig updated successfully."

  log_debug "Testing kubectl access..."
  if ! kubectl get svc kube-dns -n kube-system >/dev/null 2>&1; then
    log_warn "Connected, but unable to query kube-system/kube-dns."
    log_warn "This may indicate missing IAM or RBAC permissions."
  else
    log_info "✅ Successfully connected to EKS cluster '$cluster_name'"
  fi

  log_debug "eks_login() completed successfully"
}
