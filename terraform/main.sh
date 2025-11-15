#!/usr/bin/env bash
###############################################################################
# terraform.sh — Terraform wrapper for CI/CD workflows
#
# Version: 3.0
# Maintainer: Transit Account Infra Team
#
# Requires:
#   - terraform
#   - jq
#   - logging.sh
###############################################################################

set -euo pipefail

log_debug "Sourcing $(basename "${BASH_SOURCE[0]}")"

##
# INTERNAL HELPERS
##

_pushd() {
  pushd "$1" >/dev/null || log_fatal "Failed to cd into $1"
}

_popd() {
  popd >/dev/null || true
}

terraform_exec() {
  log_exec terraform "$@"
}

parse_vars_and_targets() {
  local -n _env="$1"
  local -n _targets="$2"
  shift 2

  local reading_targets=false

  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      reading_targets=true
      continue
    fi
    if [[ "$reading_targets" == false ]]; then
      _env+=("$arg")
    else
      _targets+=("$arg")
    fi
  done
}

build_var_args() {
  local -n _vars="$1"
  local args=()
  for v in "${_vars[@]}"; do args+=("-var=$v"); done
  echo "${args[@]}"
}

build_target_args() {
  local -n _targets="$1"
  local args=()
  for t in "${_targets[@]}"; do args+=("-target=$t"); done
  echo "${args[@]}"
}

##
# TERRAFORM CORE OPERATIONS
##

terraform_init() {
  local bucket="$1" key="$2" region="$3" path="$4"

  log_info "Terraform init in $path"
  _pushd "$path"

  rm -rf .terraform .terraform.lock.hcl || true

  terraform_exec init -no-color \
    -backend-config="bucket=$bucket" \
    -backend-config="key=$key" \
    -backend-config="region=$region" \
    || log_fatal "Terraform init failed"

  log_info "Terraform init completed"
  _popd
}

terraform_validate() {
  local path="$1"

  log_info "Validating Terraform in $path"
  _pushd "$path"
  terraform_exec validate -no-color || log_fatal "Terraform validate failed"
  log_info "Terraform validate OK"
  _popd
}

terraform_plan() {
  local path="$1"; shift

  local vars=() targets=()
  parse_vars_and_targets vars targets "$@"

  log_info "Terraform plan"
  _pushd "$path"

  terraform_exec plan -no-color \
    $(build_var_args vars) \
    $(build_target_args targets) \
    || log_fatal "Terraform plan failed"

  log_info "Terraform plan OK"
  _popd
}

terraform_apply() {
  local path="$1"; shift

  local vars=() targets=()
  parse_vars_and_targets vars targets "$@"

  log_info "Terraform apply"
  _pushd "$path"

  terraform_exec apply -no-color -auto-approve \
    $(build_var_args vars) \
    $(build_target_args targets) \
    || log_fatal "Terraform apply failed"

  log_info "Terraform apply OK"
  _popd
}

terraform_destroy() {
  local path="$1"; shift

  local vars=() targets=()
  parse_vars_and_targets vars targets "$@"

  log_warn "Terraform destroy starting!"
  _pushd "$path"

  terraform_exec destroy -no-color -auto-approve \
    $(build_var_args vars) \
    $(build_target_args targets) \
    || log_fatal "Terraform destroy failed"

  log_info "Terraform destroy OK"
  _popd
}

terraform_output_env_vars() {
  local path="$1"

  log_info "Collecting Terraform outputs"
  _pushd "$path"

  terraform_exec output -json

  _popd
}

##
# ACTION DISPATCHER
##

run_terraform_action() {
  local action="$1"
  local path="$2"
  shift 2

  [[ -z "${TERRAFORM_STATE_BUCKET:-}" ]] && log_fatal "TERRAFORM_STATE_BUCKET not set"
  [[ -z "${TERRAFORM_STATE_KEY:-}" ]] && log_fatal "TERRAFORM_STATE_KEY not set"
  [[ -z "${REGION:-}" ]] && log_fatal "REGION not set"

  terraform_init "$TERRAFORM_STATE_BUCKET" "$TERRAFORM_STATE_KEY" "$REGION" "$path"
  terraform_validate "$path"

  case "$action" in
    plan)
      terraform_plan "$path" "$@"
      ;;
    apply)
      terraform_apply "$path" "$@"
      ;;
    destroy)
      terraform_destroy "$path" "$@"
      ;;
    *)
      log_error "Unknown action: $action"
      return 1
      ;;
  esac
}