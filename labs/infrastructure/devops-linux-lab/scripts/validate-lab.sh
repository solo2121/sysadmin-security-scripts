#!/usr/bin/env bash
#
# DevOps Lab Validation Script
# Tests infrastructure health, connectivity, and service availability
#
set -Eeuo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0

# Helper functions
log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${1}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# System requirements
check_system_requirements() {
    header "SYSTEM REQUIREMENTS"

    # Check RAM
    total_mem=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$total_mem" -ge 16 ]; then
        log_pass "RAM: $total_mem GB (sufficient)"
    elif [ "$total_mem" -ge 8 ]; then
        log_warn "RAM: $total_mem GB (minimum met, may be slow)"
    else
        log_fail "RAM: $total_mem GB (insufficient, need 8+ GB)"
    fi

    # Check CPU cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -ge 8 ]; then
        log_pass "CPU: $cpu_cores cores (sufficient)"
    elif [ "$cpu_cores" -ge 4 ]; then
        log_warn "CPU: $cpu_cores cores (may be tight)"
    else
        log_fail "CPU: $cpu_cores cores (insufficient, need 4+ cores)"
    fi

    # Check disk space
    disk_free=$(df -h . | awk '/\// {print $4}' | sed 's/G//')
    if [ "${disk_free%.*}" -ge 100 ]; then
        log_pass "Disk: ${disk_free}GB free (sufficient)"
    elif [ "${disk_free%.*}" -ge 50 ]; then
        log_warn "Disk: ${disk_free}GB free (borderline)"
    else
        log_fail "Disk: ${disk_free}GB free (insufficient, need 100+ GB)"
    fi
}

# Installed tools
check_tools() {
    header "INSTALLED TOOLS"

    local tools=("vagrant" "virsh" "ansible" "terraform" "kubectl" "helm" "jq")

    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            version=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
            log_pass "$tool: $version"
        else
            log_fail "$tool: NOT INSTALLED"
        fi
    done
}

# Vagrant status
check_vagrant() {
    header "VAGRANT VMS"

    if ! command -v vagrant &> /dev/null; then
        log_fail "Vagrant not installed"
        return
    fi

    local vms=($(vagrant status --machine-readable 2>/dev/null | grep ',state,' | cut -d',' -f2 | sort -u))

    if [ ${#vms[@]} -eq 0 ]; then
        log_warn "No VMs found"
        return
    fi

    for vm in "${vms[@]}"; do
        state=$(vagrant status "$vm" 2>/dev/null | grep "$vm" | awk '{print $NF}')
        if [ "$state" = "running" ]; then
            log_pass "VM: $vm ($state)"
        else
            log_warn "VM: $vm ($state)"
        fi
    done
}

# Kubernetes cluster
check_kubernetes() {
    header "KUBERNETES CLUSTER"

    if ! command -v kubectl &> /dev/null; then
        log_warn "kubectl not installed, skipping K8s checks"
        return
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_fail "Kubernetes cluster unreachable"
        return
    fi
    log_pass "Cluster connectivity"

    # Check nodes
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
    
    if [ "$node_count" -gt 0 ]; then
        log_pass "Nodes: $ready_nodes/$node_count ready"
    else
        log_fail "No nodes found in cluster"
    fi

    # Check pod status
    local total_pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "Running" || true)
    
    if [ "$total_pods" -gt 0 ]; then
        log_pass "Pods: $running_pods/$total_pods running"
    fi

    # Check API server
    if kubectl get componentstatus &> /dev/null; then
        local api_status=$(kubectl get componentstatus --no-headers 2>/dev/null | grep "api" | awk '{print $2}')
        if [ "$api_status" = "Healthy" ]; then
            log_pass "API Server: Healthy"
        else
            log_fail "API Server: $api_status"
        fi
    fi

    # Check services
    local services=$(kubectl get svc -a --no-headers 2>/dev/null | wc -l)
    log_pass "Services: $services total"
}

# CIS Kubernetes Benchmark (kube-bench)
check_kube_bench() {
    header "CIS BENCHMARK (kube-bench)"

    if ! command -v kubectl &> /dev/null; then
        log_warn "kubectl not installed, skipping kube-bench"
        return
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_warn "Kubernetes cluster unreachable, skipping kube-bench"
        return
    fi

    log_info "Running kube-bench as a Kubernetes Job (this can take a minute)..."

    local job_name="kube-bench-validate-$$"
    local manifest
    manifest=$(curl -sfL https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-node.yaml 2>/dev/null \
        | sed "s/name: kube-bench/name: ${job_name}/")

    if [ -z "$manifest" ]; then
        log_warn "Could not fetch kube-bench job manifest, skipping"
        return
    fi

    if ! echo "$manifest" | kubectl apply -f - &> /dev/null; then
        log_warn "Failed to schedule kube-bench Job, skipping"
        return
    fi

    if kubectl wait --for=condition=complete --timeout=120s "job/${job_name}" &> /dev/null; then
        local pod
        pod=$(kubectl get pods -l "job-name=${job_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        local summary
        summary=$(kubectl logs "$pod" 2>/dev/null | grep -A 4 "^== Summary ==" | tail -4)

        if [ -n "$summary" ]; then
            log_pass "kube-bench completed"
            echo "$summary" | sed 's/^/    /'
        else
            log_warn "kube-bench completed but the summary could not be parsed"
        fi
    else
        log_fail "kube-bench Job did not complete within the 120s timeout"
    fi

    kubectl delete job "$job_name" &> /dev/null || true
}

# Network connectivity
check_network() {
    header "NETWORK CONNECTIVITY"

    # Check internet
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_pass "Internet connectivity"
    else
        log_fail "Internet connectivity"
    fi

    # Check DNS
    if nslookup google.com &> /dev/null; then
        log_pass "DNS resolution"
    else
        log_fail "DNS resolution"
    fi

    # Check libvirt network
    if command -v virsh &> /dev/null; then
        if virsh net-list --all 2>/dev/null | grep -q vagrant-libvirt; then
            local net_state=$(virsh net-list 2>/dev/null | grep vagrant-libvirt | awk '{print $2}')
            if [ "$net_state" = "active" ]; then
                log_pass "Libvirt network: active"
            else
                log_warn "Libvirt network: $net_state"
            fi
        else
            log_warn "Libvirt network: not found"
        fi
    fi
}

# Services availability
check_services() {
    header "SERVICE AVAILABILITY"

    local ports=(
        "3000:Grafana"
        "9090:Prometheus"
        "8080:Jenkins"
        "8081:ArgoCD"
    )

    for port_info in "${ports[@]}"; do
        IFS=':' read -r port service <<< "$port_info"
        if timeout 2 bash -c "echo >/dev/tcp/localhost/$port" &> /dev/null; then
            log_pass "$service (port $port): accessible"
        else
            log_warn "$service (port $port): not accessible"
        fi
    done
}

# File permissions
check_permissions() {
    header "FILE PERMISSIONS"

    # Check kubeconfig
    if [ -f ~/.kube/config ]; then
        perms=$(stat -c %a ~/.kube/config 2>/dev/null || stat -f %A ~/.kube/config 2>/dev/null)
        if [ "$perms" = "600" ]; then
            log_pass "kubeconfig permissions: 600"
        else
            log_warn "kubeconfig permissions: $perms (should be 600)"
        fi
    fi

    # Check Vagrantfile
    if [ -f Vagrantfile ]; then
        if [ -r Vagrantfile ]; then
            log_pass "Vagrantfile: readable"
        else
            log_fail "Vagrantfile: not readable"
        fi
    fi
}

# Summary
print_summary() {
    header "VALIDATION SUMMARY"
    
    local total=$((PASSED + FAILED))
    echo "Passed: ${GREEN}${PASSED}${NC}"
    echo "Failed: ${RED}${FAILED}${NC}"
    echo "Total:  ${BLUE}${total}${NC}"

    if [ "$FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}✓ All checks passed!${NC}\n"
        exit 0
    else
        echo -e "\n${RED}✗ Some checks failed. Review above for details.${NC}\n"
        exit 1
    fi
}

# Main execution
main() {
    echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   DevOps Lab Validation v1.0            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

    check_system_requirements
    check_tools
    check_vagrant
    check_kubernetes
    check_kube_bench
    check_network
    check_services
    check_permissions
    print_summary
}

# Error handling
trap 'log_fail "Script interrupted"' INT TERM

# Run
main "$@"
