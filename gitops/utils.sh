render_gitops_files() {
  local template_dir="$1"
  local output_dir="$2"

  if [[ -z "$template_dir" || -z "$output_dir" ]]; then
    echo "Usage: render_gitops_files <template_dir> <output_dir>"
    return 1
  fi

  if [[ ! -d "$template_dir" ]]; then
    echo "Error: Template directory '$template_dir' does not exist"
    return 1
  fi

  mkdir -p "$output_dir"
  local processed_count=0

  echo "Rendering template files recursively from '$template_dir' to '$output_dir'"

  set +e  # disable exit-on-error during file processing
  while IFS= read -r -d '' template; do
    local relative_path="${template#$template_dir/}"
    local output_file_path="$output_dir/$relative_path"
    local output_file_dir
    output_file_dir=$(dirname "$output_file_path")
    mkdir -p "$output_file_dir"

    echo "Processing: $relative_path"

    if envsubst < "$template" > "$output_file_path" 2>/dev/null; then
      echo "✅ Processed: $relative_path"
    else
      echo "⚠️  Warning: Issues processing: $relative_path (copied as-is)"
      cp "$template" "$output_file_path"
    fi
    ((processed_count++))
  done < <(find "$template_dir" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0)
  set -e  # restore exit-on-error

  echo "Completed: $processed_count files processed"
  return 0
}


sync_gitops_repo() {
  local repo_url="$1"
  local branch="${2:-main}"
  local local_dir="$3"

  if [[ -z "$repo_url" || -z "$local_dir" ]]; then
    log_error "Usage: sync_gitops_repo <repo_url> [branch] <local_dir>"
    return 1
  fi

  # Prepare authenticated repo URL if token is available
  local git_auth_url="$repo_url"
  if [[ -n "${ARGOCD_GH_APP_TOKEN:-}" ]]; then
    log_info "Using ARGOCD_GH_APP_TOKEN for Git authentication"
    
    if [[ "$repo_url" == https://github.com/* ]]; then
      git_auth_url="https://x-access-token:${ARGOCD_GH_APP_TOKEN}@github.com/${repo_url#https://github.com/}"
    elif [[ "$repo_url" == git@github.com:* ]]; then
      git_auth_url="https://x-access-token:${ARGOCD_GH_APP_TOKEN}@github.com/${repo_url#git@github.com:}"
    elif [[ "$repo_url" == https://* ]]; then
      local domain_path="${repo_url#https://}"
      git_auth_url="https://x-access-token:${ARGOCD_GH_APP_TOKEN}@${domain_path}"
    fi
  else
    log_warn "No ARGOCD_GH_APP_TOKEN found, using unauthenticated Git access"
  fi

  # Clone or update the GitOps repository
  if [[ ! -d "gitops" ]]; then
    log_info "Cloning GitOps repository..."
    if ! git clone -b "$branch" "$git_auth_url" gitops; then
      log_error "❌ Failed to clone repository"
      return 1
    fi
  else
    log_info "Updating existing GitOps repository..."
    cd gitops || return 1
    git pull origin "$branch"
    cd - >/dev/null || return 1
  fi

  # Copy files with proper directory handling
  log_info "Copying files from $local_dir to gitops/${ENVIRONMENT}/${PROJECT_NAME}/ ..."
  mkdir -p "gitops/${ENVIRONMENT}/${PROJECT_NAME}"
  cp -rf "$local_dir"/* "gitops/${ENVIRONMENT}/${PROJECT_NAME}/"

  cd gitops || return 1

  git config user.email "github-actions[bot]@users.noreply.github.com"
  git config user.name "github-actions[bot]"

  if [[ -n "$(git status --porcelain)" ]]; then
    log_info "Changes detected — committing and pushing..."
    git add .
    git commit -m "chore: automated GitOps update [$(date '+%Y-%m-%d %H:%M:%S')]"
    if git push origin "$branch"; then
      log_info "✅ Successfully pushed changes to $branch"
    else
      log_error "❌ Failed to push changes"
      cd - >/dev/null || return 1
      return 1
    fi
  else
    log_info "No changes detected — nothing to push"
  fi

  cd - >/dev/null || return 1
  return 0
}
