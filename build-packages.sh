#!/bin/bash
set -euo pipefail

source ./config.sh

packages=()

GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
NC='\e[0m'

log_success() {
    echo -e "${GREEN}[✔] $1${NC}"
}

log_error() {
    echo -e "${RED}[✖] $1${NC}" >&2
}

log_info() {
    echo -e "${YELLOW}[i] $1${NC}"
}

usage() {
    echo "Usage: $0 --package <package-folder> [<package-folder> ...]"
    echo "       $0 --package all  (build all packages in '$deb_source')"
    exit 1
}

if [[ $# -lt 2 || "$1" != "--package" ]]; then
    usage
fi

shift
if [[ "$1" == "all" ]]; then
    if [ ! -d "$deb_source" ]; then
        log_error "Source folder '$deb_source' does not exist."
        exit 1
    fi
    mapfile -t packages < <(ls -1 "$deb_source")
else
    while [[ $# -gt 0 ]]; do
        packages+=("$1")
        shift
    done
fi

if [ ! -d "$build" ]; then
    log_info "Creating output folder: $build"
    mkdir -p "$build"
fi

for package_name in "${packages[@]}"; do
    package_dir="$deb_source/$package_name"

    if [ ! -d "$package_dir" ]; then
        log_error "Package folder '$package_name' not found!"
        exit 1
    fi

    control_file="$package_dir/DEBIAN/control"
    if [ ! -f "$control_file" ]; then
        log_error "Control file missing in $package_name."
        exit 1
    fi

    package=$(grep -i '^Package:' "$control_file" | awk '{print $2}')
    version=$(grep -i '^Version:' "$control_file" | awk '{print $2}')
    architecture=$(grep -i '^Architecture:' "$control_file" | awk '{print $2}')

    if [[ -z "$package" || -z "$version" || -z "$architecture" ]]; then
        log_error "Control file for '$package_name' missing Package, Version, or Architecture."
        exit 1
    fi

    if [ "$architecture" == "all" ]; then
        target_arch=("all")
    else
        target_arch=("$architecture")
    fi

    for arch_item in "${target_arch[@]}"; do
        deb_filename="${package}_${version}_${arch_item}.deb"
        log_info "Building package: $deb_filename"

        dpkg-deb --build "$package_dir" "$build/$deb_filename" > /dev/null

        if [ $? -eq 0 ]; then
            log_success "$deb_filename built successfully."
        else
            log_error "Failed to build $deb_filename."
            exit 1
        fi
    done
done

log_success "All packages built successfully. Output in '$build'."
