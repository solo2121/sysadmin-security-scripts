#!/usr/bin/env bats
#
# Unit tests for tools/sysadmin/system-hardening/user-audit.sh
#
# Scope:
#   These tests source the real script (guarded against auto-execution
#   by its own `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` check) and exercise
#   its pure, file-driven functions against fixture `passwd(5)` and
#   `sshd_config` files instead of the live host's `/etc/passwd` and
#   `/etc/ssh/sshd_config`. This keeps the suite deterministic across
#   CI runners regardless of what accounts or SSH config actually exist
#   on the machine running the tests.
#
#   show_sudo_capable_users() is deliberately NOT tested here: it shells
#   out to `getent group sudo` against the live system with no fixture
#   hook, so its output is host-dependent and out of scope for a
#   deterministic CI unit test.

SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../tools/sysadmin/system-hardening/user-audit.sh"

setup() {
    # shellcheck disable=SC1090
    source "$SCRIPT_PATH"

    # user-audit.sh sets `set -euo pipefail` for its own execution.
    # That's correct for the real script, but we don't want it leaking
    # into how these test assertions behave, so restore normal test
    # semantics right after sourcing.
    set +euo pipefail

    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "user-audit.sh sources without executing main" {
    declare -f main >/dev/null
    declare -f show_login_capable_accounts >/dev/null
}

@test "show_login_capable_accounts lists shell accounts and excludes nologin/false" {
    cat > "$TEST_TMPDIR/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
alice:x:1000:1000:Alice:/home/alice:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
EOF

    run show_login_capable_accounts "$TEST_TMPDIR/passwd"

    [ "$status" -eq 0 ]
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"alice"* ]]
    [[ "$output" != *"daemon"* ]]
}

@test "show_normal_user_accounts only lists UID >= 1000 accounts" {
    cat > "$TEST_TMPDIR/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
alice:x:1000:1000:Alice:/home/alice:/bin/bash
svc-app:x:999:999:Service:/var/lib/svc-app:/bin/bash
EOF

    run show_normal_user_accounts "$TEST_TMPDIR/passwd"

    [ "$status" -eq 0 ]
    [[ "$output" == *"alice"* ]]
    [[ "$output" != *"svc-app"* ]]
    [[ "$output" != *"root "* ]]
}

@test "check_uid0_accounts reports OK when only root has UID 0" {
    cat > "$TEST_TMPDIR/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
alice:x:1000:1000:Alice:/home/alice:/bin/bash
EOF

    run check_uid0_accounts "$TEST_TMPDIR/passwd"

    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: Only root has UID 0"* ]]
    [[ "$output" != *"WARNING"* ]]
}

@test "check_uid0_accounts warns and lists every account sharing UID 0" {
    cat > "$TEST_TMPDIR/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
backdoor:x:0:0:Backdoor:/home/backdoor:/bin/bash
alice:x:1000:1000:Alice:/home/alice:/bin/bash
EOF

    run check_uid0_accounts "$TEST_TMPDIR/passwd"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: Multiple UID 0 accounts found"* ]]
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"backdoor"* ]]
}

@test "check_suspect_system_accounts flags non-root system UIDs with interactive shells" {
    cat > "$TEST_TMPDIR/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
games:x:60:60:games:/usr/games:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
EOF

    run check_suspect_system_accounts "$TEST_TMPDIR/passwd"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"games"* ]]
    [[ "$output" != *"daemon"* ]]
}

@test "check_suspect_system_accounts reports OK when no system account has an interactive shell" {
    cat > "$TEST_TMPDIR/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
alice:x:1000:1000:Alice:/home/alice:/bin/bash
EOF

    run check_suspect_system_accounts "$TEST_TMPDIR/passwd"

    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: No system accounts"* ]]
    [[ "$output" != *"WARNING"* ]]
}

@test "show_ssh_root_login_config surfaces an explicit PermitRootLogin setting" {
    cat > "$TEST_TMPDIR/sshd_config" <<'EOF'
Port 22
PermitRootLogin no
PasswordAuthentication no
EOF

    run show_ssh_root_login_config "$TEST_TMPDIR/sshd_config"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PermitRootLogin no"* ]]
}

@test "show_ssh_root_login_config notes when PermitRootLogin is not set" {
    cat > "$TEST_TMPDIR/sshd_config" <<'EOF'
Port 22
PasswordAuthentication no
EOF

    run show_ssh_root_login_config "$TEST_TMPDIR/sshd_config"

    [ "$status" -eq 0 ]
    [[ "$output" == *"not explicitly set"* ]]
}

@test "show_ssh_root_login_config reports SSH not installed when the config file is absent" {
    run show_ssh_root_login_config "$TEST_TMPDIR/does-not-exist"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH not installed"* ]]
}
