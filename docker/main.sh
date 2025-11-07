build_docker_image() {
    local dockerfile_path="${1:-Dockerfile}"
    local image_name="${2:-${PROJECT_NAME}}"
    local build_args="${3:-}"

    log_info "Building Docker image: ${image_name} using ${dockerfile_path}"

    dockerfile_context_dir=$(dirname "${dockerfile_path}")

    # The context should be the project root (where your scripts/ folder exists)
    local build_command="docker build -f ${dockerfile_path} -t ${image_name} ${dockerfile_context_dir}"

    for arg in ${build_args}; do
        build_command+=" --build-arg ${arg}"
    done


    log_info "Running: ${build_command}"
    if eval "${build_command}"; then
        log_info "✅ Successfully built image: ${image_name}"
        return 0
    else
        log_error "❌ Failed to build Docker image"
        return 1
    fi
}
