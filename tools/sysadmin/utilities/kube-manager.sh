#!/usr/bin/env bash
#
# kube-manager.sh
#
# Modern Kubernetes Administration Utility
#
# Requirements:
#   Bash 5+
#   kubectl
#   jq
#   yq
#   timeout (GNU coreutils)
#
# shellcheck disable=SC2317

set -Eeuo pipefail

###############################################################################
# Bash version check
###############################################################################

if ((BASH_VERSINFO[0] < 5)); then
    printf "ERROR: this script requires Bash 5+ (found %s)\n" "${BASH_VERSION}" >&2
    exit 1
fi

###############################################################################
# Globals
###############################################################################

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.1.0"

DRY_RUN=false
VERBOSE=false
INTERACTIVE=true

###############################################################################
# Colors
###############################################################################

if [[ -t 1 ]]; then
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    YELLOW=$'\e[33m'
    BLUE=$'\e[34m'
    CYAN=$'\e[36m'
    BOLD=$'\e[1m'
    RESET=$'\e[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

###############################################################################
# Logging
###############################################################################

log_info() {
    printf "%b[INFO]%b %s\n" "$BLUE" "$RESET" "$*"
}

log_success() {
    printf "%b[SUCCESS]%b %s\n" "$GREEN" "$RESET" "$*"
}

log_warn() {
    printf "%b[WARN]%b %s\n" "$YELLOW" "$RESET" "$*" >&2
}

log_error() {
    printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$*" >&2
}

log_debug() {
    "$VERBOSE" || return 0
    printf "%b[DEBUG]%b %s\n" "$CYAN" "$RESET" "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

###############################################################################
# Error Handling
###############################################################################

cleanup() {
    :
}

on_error() {
    local exit_code=$?
    local line=$1

    log_error "Command failed (line ${line})"
    exit "$exit_code"
}

on_interrupt() {
    log_warn "Interrupted."
    exit 130
}

trap cleanup EXIT
trap 'on_error $LINENO' ERR
trap on_interrupt INT TERM

###############################################################################
# Dependency Check
###############################################################################

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

check_dependencies() {
    local deps=(
        kubectl
        jq
        yq
        timeout
    )

    local dep

    for dep in "${deps[@]}"; do
        require_command "$dep"
    done
}

###############################################################################
# Utilities
###############################################################################

run() {
    if "$DRY_RUN"; then
        printf "[DRY-RUN] %q" "$1"
        shift
        printf " %q" "$@"
        printf "\n"
        return 0
    fi

    log_debug "Running: $*"

    "$@"
}

confirm() {

    if ! "$INTERACTIVE"; then
        return 0
    fi

    # Fail safe (i.e. decline) instead of crashing when there's no
    # interactive terminal to read a response from (CI, cron, pipes, etc.)
    if [[ ! -t 0 ]]; then
        log_warn "No interactive terminal detected; skipping (use --yes to proceed non-interactively)."
        return 1
    fi

    local reply

    read -r -p "Continue? [y/N]: " reply || return 1

    [[ "$reply" =~ ^[Yy]$ ]]
}

###############################################################################
# Help
###############################################################################

usage() {

cat <<EOF

${SCRIPT_NAME} v${VERSION}

Modern Kubernetes Administration Utility

Usage:

  ${SCRIPT_NAME} [OPTIONS] COMMAND

Options

  --dry-run
  --yes
  --verbose
  -h, --help

Commands

  health
  nodes
  pods
  namespaces
  resources
  describe
  logs
  top
  apply
  delete
  context
  contexts
  version

Examples

  ${SCRIPT_NAME} health

  ${SCRIPT_NAME} pods default

  ${SCRIPT_NAME} logs nginx-pod

  ${SCRIPT_NAME} apply deployment.yaml

  ${SCRIPT_NAME} delete pod nginx

  ${SCRIPT_NAME} context production

EOF

}

###############################################################################
# Cluster
###############################################################################

cluster_health() {

    log_info "Cluster information"

    kubectl cluster-info

    echo

    # componentstatuses is deprecated/unavailable on many managed clusters
    # (EKS, GKE, AKS) so failures here are expected and non-fatal.
    kubectl get componentstatuses 2>/dev/null || true

    echo

    kubectl get nodes
}

###############################################################################
# Resources
###############################################################################

list_nodes() {
    kubectl get nodes -o wide
}

list_pods() {

    local namespace="${1:-default}"

    kubectl get pods \
        -n "$namespace" \
        -o wide
}

list_namespaces() {
    kubectl get namespaces
}

list_resources() {

    local namespace="${1:-default}"

    # NOTE: `kubectl get all` is a known-incomplete shortcut — it omits
    # ConfigMaps, Secrets, Ingresses, PVCs, NetworkPolicies, etc. Extend
    # the resource list below if you need full visibility.
    kubectl get all \
        -n "$namespace" \
        -o wide
}

###############################################################################
# Describe
###############################################################################

describe_resource() {

    local type="${1:?Missing resource type}"
    local name="${2:?Missing resource name}"
    local namespace="${3:-default}"

    kubectl describe \
        "$type" \
        "$name" \
        -n "$namespace"
}

###############################################################################
# Logs
###############################################################################

show_logs() {

    local pod="${1:?Missing pod}"
    local namespace="${2:-default}"

    kubectl logs \
        "$pod" \
        -n "$namespace" \
        --tail=200
}

###############################################################################
# Metrics
###############################################################################

top_resources() {

    kubectl top nodes || true

    echo

    kubectl top pods --all-namespaces || true
}

###############################################################################
# Apply
###############################################################################

apply_manifest() {

    local file="${1:?Manifest required}"

    [[ -f "$file" ]] || die "Manifest not found: $file"

    run kubectl apply -f "$file"
}

###############################################################################
# Delete
###############################################################################

delete_resource() {

    local type="${1:?Type required}"
    local name="${2:?Name required}"
    local namespace="${3:-default}"

    log_warn "Deleting ${type}/${name}"

    if confirm; then
        run kubectl delete \
            "$type" \
            "$name" \
            -n "$namespace"
    else
        log_warn "Cancelled."
    fi
}

###############################################################################
# Contexts
###############################################################################

list_contexts() {
    kubectl config get-contexts
}

switch_context() {

    local ctx="${1:?Context required}"

    run kubectl config use-context "$ctx"
}

###############################################################################
# Version
###############################################################################

show_version() {

    printf "%s %s\n" "$SCRIPT_NAME" "$VERSION"

    # `kubectl version --short` was removed in kubectl 1.28+.
    # Fall back gracefully across old and new clients.
    kubectl version 2>/dev/null || kubectl version --client
}

###############################################################################
# CLI
###############################################################################

parse_global_options() {

    while (($#)); do

        case "$1" in

            --dry-run)
                DRY_RUN=true
                shift
                ;;

            --yes)
                INTERACTIVE=false
                shift
                ;;

            --verbose)
                VERBOSE=true
                shift
                ;;

            -h|--help)
                usage
                exit 0
                ;;

            *)
                break
                ;;

        esac

    done

    COMMAND="${1:-}"

    shift || true

    ARGS=("$@")
}

###############################################################################
# Main
###############################################################################

main() {

    check_dependencies

    parse_global_options "$@"

    case "${COMMAND:-}" in

        health)
            cluster_health
            ;;

        nodes)
            list_nodes
            ;;

        pods)
            list_pods "${ARGS[@]}"
            ;;

        namespaces)
            list_namespaces
            ;;

        resources)
            list_resources "${ARGS[@]}"
            ;;

        describe)
            describe_resource "${ARGS[@]}"
            ;;

        logs)
            show_logs "${ARGS[@]}"
            ;;

        top)
            top_resources
            ;;

        apply)
            apply_manifest "${ARGS[@]}"
            ;;

        delete)
            delete_resource "${ARGS[@]}"
            ;;

        contexts)
            list_contexts
            ;;

        context)
            switch_context "${ARGS[@]}"
            ;;

        version)
            show_version
            ;;

        ""|-h|--help)
            usage
            ;;

        *)
            die "Unknown command: ${COMMAND}"
            ;;

    esac
}

main "$@"
