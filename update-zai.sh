#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ZAI_NPM_DIR="$HOME/.cc-mirror/zai/npm"
ZAI_TEAM_NPM_DIR="$HOME/.cc-mirror/zai-team/npm"
ZAI_VARIANT="$HOME/.cc-mirror/zai/variant.json"
ZAI_TEAM_VARIANT="$HOME/.cc-mirror/zai-team/variant.json"

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "${YELLOW}▶${NC} $1"
}

get_installed_version() {
    local dir="$1"
    if [[ -f "$dir/node_modules/@anthropic-ai/claude-code/package.json" ]]; then
        jq -r '.version' "$dir/node_modules/@anthropic-ai/claude-code/package.json" 2>/dev/null || echo "unknown"
    else
        echo "not installed"
    fi
}

get_latest_version() {
    npm view @anthropic-ai/claude-code version 2>/dev/null || echo "unknown"
}

update_variant_json() {
    local variant_file="$1"
    local version="$2"
    local timestamp="$3"

    if [[ -f "$variant_file" ]]; then
        jq --arg version "$version" \
           --arg timestamp "$timestamp" \
           '.npmVersion = $version | .claudeOrig = "npm:@anthropic-ai/claude-code@" + $version | .updatedAt = $timestamp' \
           "$variant_file" > "${variant_file}.tmp" && \
        mv "${variant_file}.tmp" "$variant_file"
        log_success "Updated $(basename "$variant_file")"
    fi
}

update_mirror() {
    local name="$1"
    local npm_dir="$2"
    local variant_file="$3"

    log_step "Updating $name..."

    # Check if directory exists
    if [[ ! -d "$npm_dir" ]]; then
        log_error "$name npm directory not found: $npm_dir"
        return 1
    fi

    # Get current version
    local current_version=$(get_installed_version "$npm_dir")
    log_info "Current version: $current_version"

    # Update package.json to use caret range for latest 2.x
    cat > "$npm_dir/package.json" << 'EOF'
{
  "dependencies": {
    "@anthropic-ai/claude-code": "^2.1.29"
  }
}
EOF

    # Run npm install
    cd "$npm_dir"
    if npm install; then
        local new_version=$(get_installed_version "$npm_dir")
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

        # Update variant.json
        update_variant_json "$variant_file" "$new_version" "$timestamp"

        log_success "$name updated: $current_version → $new_version"
    else
        log_error "Failed to update $name"
        return 1
    fi
}

# Main script
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Claude Code ZAI/ZAI-Team Mirror Updater          ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    # Get latest version available
    log_step "Checking latest version available..."
    LATEST_VERSION=$(get_latest_version)
    log_info "Latest version: $LATEST_VERSION"
    echo ""

    # Show current versions
    log_info "Current versions:"
    echo "  zai:       $(get_installed_version "$ZAI_NPM_DIR")"
    echo "  zai-team:  $(get_installed_version "$ZAI_TEAM_NPM_DIR")"
    echo ""

    # Update zai
    update_mirror "zai" "$ZAI_NPM_DIR" "$ZAI_VARIANT"
    echo ""

    # Update zai-team
    update_mirror "zai-team" "$ZAI_TEAM_NPM_DIR" "$ZAI_TEAM_VARIANT"
    echo ""

    # Final summary
    echo "═══════════════════════════════════════════════════════"
    log_success "Update complete!"
    echo ""
    log_info "Final versions:"
    echo "  zai:       $(get_installed_version "$ZAI_NPM_DIR")"
    echo "  zai-team:  $(get_installed_version "$ZAI_TEAM_NPM_DIR")"
    echo "  latest:    $LATEST_VERSION"
    echo ""
}

# Run main
main "$@"
