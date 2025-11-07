# Enhanced install_react_dependencies function
install_react_dependencies() {
    local app_dir="${1:-.}"
    local package_manager="${PACKAGE_MANAGER:-npm}"  # npm or yarn
    local yarn_version="${YARN_VERSION:-}"
    local install_command

    log_info "Installing React app dependencies in directory: ${app_dir} using ${package_manager}"

    pushd "${app_dir}" > /dev/null || {
        log_error "Failed to navigate to directory: ${app_dir}"
        return 1
    }

    # Optional: set yarn version if defined
    if [ "$package_manager" = "yarn" ] && [ -n "$yarn_version" ]; then
        log_info "Setting Yarn version to ${yarn_version}"
        yarn policies set-version "${yarn_version}"
    fi

    # Build install command depending on manager
    if [ "$package_manager" = "yarn" ]; then
        install_command="yarn install --frozen-lockfile"
    else
        install_command="npm install --legacy-peer-deps"
    fi

    # Run install
    if eval "${install_command}"; then
        log_info "✅ Successfully installed dependencies"
        popd > /dev/null
        return 0
    else
        log_error "❌ Failed to install dependencies"
        popd > /dev/null
        return 1
    fi
}

# Enhanced build_react_app function
build_react_app() {
    local app_dir="${1:-.}"
    local theme_name="${THEME_NAME:-}"
    local build_command="${BUILD_COMMAND:-npm run build}"
    local package_manager="${PACKAGE_MANAGER:-npm}"
    
    CI=false

    log_info "Building React app in directory: ${app_dir}"

    pushd "${app_dir}" > /dev/null || {
        log_error "Failed to navigate to directory: ${app_dir}"
        return 1
    }

    # Optional: handle theme copy
    if [ -n "${theme_name}" ]; then
        local theme_dir="src/themes/${theme_name}"
        if [ -d "${theme_dir}" ]; then
            log_info "Applying theme '${theme_name}' from ${theme_dir}"
            cp -r "${theme_dir}/"* src/
        else
            log_warn "Theme '${theme_name}' not found at ${theme_dir}"
        fi
    fi

    # Execute build command
    if eval "${build_command}"; then
        log_info "✅ Successfully built React app"
        popd > /dev/null
        return 0
    else
        log_error "❌ Failed to build React app"
        popd > /dev/null
        return 1
    fi
}
