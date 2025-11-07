# sync local folder to s3 bucket
sync_folder_to_s3() {
    local local_folder="${1:-}"
    local s3_bucket="${2:-}"
    local s3_path="${3:-}"  # Optional sub-path in the bucket

    if [[ -z "${local_folder}" || -z "${s3_bucket}" ]]; then
        log_error "Local folder and S3 bucket are required"
        return 1
    fi

    ls -la

    local destination="s3://${s3_bucket}/${s3_path}"

    log_info "Syncing local folder '${local_folder}' to S3 bucket '${destination}'"

    if aws s3 sync "${local_folder}" "${destination}" --delete; then
        log_info "Successfully synced folder to S3"
        return 0
    else
        log_error "Failed to sync folder to S3"
        return 1
    fi
}

list_s3_buckets() {
    log_info "Listing all S3 buckets"

    if aws s3 ls; then
        return 0
    else
        log_error "Failed to list S3 buckets"
        return 1
    fi
}