#!/usr/bin/env bash
# ecr-utils.sh - ECR utility functions for CI/CD pipelines
# Version: 1.0.0
# Requires: logging.sh to be sourced first

set -euo pipefail

# Prevent multiple sourcing
if [[ -n "${ECR_UTILS_LOADED:-}" ]]; then
    return 0
fi
readonly ECR_UTILS_LOADED=1

# Validate required environment variables
validate_ecr_env() {
    local required_vars=("AWS_REGION" "AWS_ACCOUNT_ID" "PROJECT_NAME")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    log_debug "Environment validation successful"
    return 0
}

# Login to Amazon ECR
ecr_login() {
    log_info "Logging in to Amazon ECR in region: ${AWS_REGION}"
    
    if ! validate_ecr_env; then
        log_error "Environment validation failed"
        return 1
    fi

    local ecr_registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    if aws ecr get-login-password --region "${AWS_REGION}" | \
       docker login --username AWS --password-stdin "${ecr_registry}" 2>&1 | \
       log_exec cat; then
        log_info "Successfully logged in to ECR: ${ecr_registry}"
        return 0
    else
        log_error "Failed to login to ECR"
        return 1
    fi
}

# Check if ECR repository exists, create if it doesn't
check_if_ecr_exists() {
    log_info "Checking if ECR repository exists: ${PROJECT_NAME}"
    
    if ! validate_ecr_env; then
        return 1
    fi

    if aws ecr describe-repositories \
        --repository-names "${PROJECT_NAME}" \
        --region "${AWS_REGION}" \
        --output json > /dev/null 2>&1; then
        log_info "ECR repository '${PROJECT_NAME}' already exists"
        return 0
    else
        log_warn "ECR repository '${PROJECT_NAME}' does not exist. Creating..."
        
        if aws ecr create-repository \
            --repository-name "${PROJECT_NAME}" \
            --region "${AWS_REGION}" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --output json > /dev/null; then
            log_info "Successfully created ECR repository: ${PROJECT_NAME}"
            return 0
        else
            log_error "Failed to create ECR repository: ${PROJECT_NAME}"
            return 1
        fi
    fi
}

# Push Docker image to ECR
push_image_to_ecr() {
    log_info "Preparing to push image: ${DOCKER_IMAGE_NAME}"
    
    if [[ -z "${DOCKER_IMAGE_NAME:-}" ]]; then
        log_error "DOCKER_IMAGE_NAME is not set"
        return 1
    fi

    if ! check_if_ecr_exists; then
        log_error "Failed to verify/create ECR repository"
        return 1
    fi

    if ! docker image inspect "${DOCKER_IMAGE_NAME}" > /dev/null 2>&1; then
        log_error "Docker image '${DOCKER_IMAGE_NAME}' not found locally"
        return 1
    fi

    log_info "Pushing image to ECR: ${DOCKER_IMAGE_NAME}"
    
    if docker push "${DOCKER_IMAGE_NAME}"; then
        log_info "Successfully pushed image: ${DOCKER_IMAGE_NAME}"
        return 0
    else
        log_error "Failed to push image to ECR"
        return 1
    fi
}

# Tag and push image with multiple tags
tag_and_push_image() {
    local base_image="${1:-}"
    local ecr_repo="${2:-${PROJECT_NAME}}"
    local tags="${3:-latest}"
    
    if [[ -z "${base_image}" ]]; then
        log_error "Base image name is required"
        return 1
    fi

    local ecr_registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    if ! check_if_ecr_exists; then
        return 1
    fi

    for tag in ${tags}; do
        local full_image_name="${ecr_registry}/${ecr_repo}:${tag}"
        log_info "Tagging image: ${base_image} -> ${full_image_name}"
        
        if docker tag "${base_image}" "${full_image_name}"; then
            log_info "Pushing tagged image: ${full_image_name}"
            if docker push "${full_image_name}"; then
                log_info "Successfully pushed: ${full_image_name}"
            else
                log_error "Failed to push: ${full_image_name}"
                return 1
            fi
        else
            log_error "Failed to tag image"
            return 1
        fi
    done

    return 0
}
