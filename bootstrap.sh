#!/usr/bin/env bash

# source logging utilities first
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils/logging.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils/common.sh"

if [[ "${GET_ENVIRONMENT_BY_BRANCH:-false}" == "true" ]]; then
    get_environment_by_branch
fi


# Resolve repo directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add repo to PATH if you want to expose scripts
export PATH="$REPO_DIR/bin:$PATH"

# Source all function files
for file in "$REPO_DIR"/*/*.sh; do
  [ -r "$file" ] && [ -f "$file" ] && source "$file"
done

# Optional: print a success message
echo "✅ Shell functions loaded from $REPO_DIR"
