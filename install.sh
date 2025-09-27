#!/bin/bash

set -euo pipefail

# Configuration
readonly REPO_OWNER="Antoine-Flo"
readonly REPO_NAME="kubelocal"
readonly GITHUB_API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
readonly TEMP_DIR="/tmp/kubelocal-install"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Detect platform
detect_platform() {
    local os=""
    local arch=""
    
    case "$(uname -s)" in
        Linux*)     os="linux" ;;
        *)          echo "Platforme non supportée: $(uname -s). Seul Linux AMD64 est supporté pour l'instant." >&2; exit 1 ;;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        *)             echo "Architecture non supportée: $(uname -m). Seul AMD64 est supporté pour l'instant." >&2; exit 1 ;;
    esac
    
    echo "${os}-${arch}"
}

# Get latest release and download URL
get_download_url() {
    local platform="$1"
    local api_response
    
    api_response=$(curl -s "$GITHUB_API_URL") || exit 1
    echo "$api_response" | grep -o "\"browser_download_url\": \"[^\"]*${platform}[^\"]*\"" | cut -d'"' -f4
}

# Download and install
install_binary() {
    local download_url="$1"
    local platform="$2"
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    local filename="kubelocal-${platform}.tar.gz"
    curl -fsSL -o "$filename" "$download_url" || exit 1
    tar -xzf "$filename" >/dev/null 2>&1 || exit 1
    
    local binary_path
    binary_path=$(find . -name "kubelocal" -type f | head -n1) || exit 1
    chmod +x "$binary_path"
    
    if [[ $EUID -eq 0 ]]; then
        cp "$binary_path" "/usr/local/bin/kubelocal"
    else
        mkdir -p "$HOME/.local/bin"
        cp "$binary_path" "$HOME/.local/bin/kubelocal"
    fi
}

# Main
platform=$(detect_platform)
download_url=$(get_download_url "$platform")
install_binary "$download_url" "$platform"
