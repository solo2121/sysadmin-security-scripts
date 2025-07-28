#!/usr/bin/env bash
# pacstall-maintenance.sh
# Update, upgrade, clean cache, and remove orphans
# Fix: Add proper error handling and improve orphan detection logic

set -euo pipefail
shopt -s nullglob

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
status() {
    printf "==> ${GREEN}%s${NC}\n" "$1"
}

# Function to print warnings
warning() {
    printf "    ${YELLOW}%s${NC}\n" "$1"
}

# Function to print errors
error() {
    printf "    ${RED}%s${NC}\n" "$1" >&2
}

# 1. Update pacstall itself
status "Updating pacstall ..."
if ! pacstall -U; then
    error "Failed to update pacstall"
    exit 1
fi

# 2. Upgrade all pacstall packages
status "Upgrading installed pacstall packages ..."
if ! pacstall -Up; then
    error "Failed to upgrade packages"
    exit 1
fi

# 3. Clean cached .deb files
CACHEDIR="/var/cache/pacstall"
if [[ -d "$CACHEDIR" ]]; then
    status "Cleaning cached .deb files ..."
    if ! find "$CACHEDIR" -type f -name '*.deb' -delete; then
        error "Failed to clean cache"
        exit 1
    fi
    printf "    Removed cached .deb files from %s\n" "$CACHEDIR"
else
    warning "No cache directory found at $CACHEDIR - nothing to clean."
fi

# 4. Remove orphaned Pacstall packages
status "Detecting orphaned Pacstall packages ..."

mapfile -t installed < <(pacstall -L || { error "Failed to list installed packages"; exit 1; })
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

for pkg in "${installed[@]}"; do
    if ! pacstall -S "$pkg" >"$WORKDIR/$pkg" 2>/dev/null; then
        warning "Failed to get info for package $pkg"
    fi
done

mapfile -t needed < <(grep -h '^[^#]' "$WORKDIR"/* | sort -u)

# Explicitly declare and initialize associative arrays
declare -A installedSet=()
declare -A neededSet=()

# Populate the sets
for p in "${installed[@]}"; do
    installedSet["$p"]=1
done
for p in "${needed[@]}"; do
    neededSet["$p"]=1
done

orphans=()
for p in "${installed[@]}"; do
    [[ ${neededSet["$p"]:-} ]] && continue
    orphans+=("$p")
done

if ((${#orphans[@]} > 0)); then
    printf "    Orphans detected: %s\n" "${orphans[*]}"
    for pkg in "${orphans[@]}"; do
        printf "    Removing %s ...\n" "$pkg"
        if ! yes | pacstall -R "$pkg"; then
            error "Failed to remove package $pkg"
        fi
    done
else
    printf "    No orphaned packages found.\n"
fi

status "Pacstall maintenance complete."
