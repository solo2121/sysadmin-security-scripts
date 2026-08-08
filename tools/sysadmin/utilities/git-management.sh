#!/usr/bin/env bash
# ============================================================
# Git Management Toolkit
# Author: Miguel A. Carlo
# Description: Interactive Git helper for common repository
#              status, branch, commit, remote, and sync tasks.
# ============================================================

set -Eeuo pipefail
shopt -s nocasematch

handle_error() {
    local exit_code=${1:-$?}
    local line_number=${2:-$LINENO}
    local command_name=${3:-$BASH_COMMAND}
    printf "Error occurred in '%s' at line %d: command '%s' exited with status %d\n" \
        "${0##*/}" "$line_number" "$command_name" "$exit_code" >&2
    exit "$exit_code"
}

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

for completion_file in \
    /usr/share/bash-completion/completions/git \
    /etc/bash_completion.d/git \
    ~/.git-completion.bash
do
    if [[ -f "$completion_file" ]]; then
        # shellcheck disable=SC1090
        source "$completion_file"
        break
    fi
done

bind -x '"\C-l": clear' || true
bind 'set completion-ignore-case on' || true
bind 'set show-all-if-ambiguous on' || true
bind 'TAB:menu-complete' || true

show_menu() {
    clear
    echo "=================================="
    echo "        Git Management Menu"
    echo "=================================="
    echo "1. Check Git Status"
    echo "2. Add Files to Staging"
    echo "3. Commit Changes"
    echo "4. Push to Remote"
    echo "5. Fetch from Remote"
    echo "6. Pull from Remote"
    echo "7. View Git Log"
    echo "8. View Branches"
    echo "9. Exit"
    echo "=================================="
}

check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        printf "Error: Not a git repository!\n" >&2
        exit 1
    fi
}

git_status() {
    echo -e "\nGit Status:\n----------"
    git status
}

add_files() {
    echo -e "\nCurrent status:"
    git status --short
    echo

    read -rp "Add all unstaged files? (y/n): " choice
    case "$choice" in
        [yY]|[yY][eE][sS])
            git add .
            echo "All files added to staging area."
            ;;
        [nN]|[nN][oO])
            read -rp "Enter specific file names to add (space-separated), or press Enter to cancel: " -a files_to_add
            if (( ${#files_to_add[@]} > 0 )); then
                git add "${files_to_add[@]}"
                echo "Added: ${files_to_add[*]}"
            else
                echo "No files added."
            fi
            ;;
        *)
            echo "Invalid choice. No files added."
            ;;
    esac
}

commit_changes() {
    printf "\nStaged files:\n"
    git diff --cached --name-only || true
    printf "\n"
    
    echo "Enter commit details (following CONTRIBUTING.md standards):"
    echo "Common types: feat, fix, docs, style, refactor, test, chore"

    read -rp "Type (e.g., feat): " type
    read -rp "Scope (optional, e.g., git-tool): " scope
    read -rp "Description: " description

    if [[ -z "$type" || -z "$description" ]]; then
        echo "Error: Type and Description are required. Commit canceled." >&2
        return 0 # Return to menu, do not exit script
    fi

    local commit_msg="$type: $description"
    [[ -n "$scope" ]] && commit_msg="$type($scope): $description" || true

    if ! git commit -m "$commit_msg"; then
        printf "Commit failed!\n" >&2
        return 1
    fi
    printf "Changes committed successfully with message: %s\n" "$commit_msg"
}

push_changes() {
    local current_branch branch proceed
    current_branch=$(git branch --show-current)

    if [[ -z "$current_branch" ]]; then
        printf "Error: Could not determine current branch.\n" >&2
        return 0 # Return to menu
    fi

    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        printf "Warning: You are attempting to push directly to the protected branch '%s'.\n" "$current_branch"
        read -rp "This is generally not recommended. Continue? (y/n): " proceed
        [[ "$proceed" =~ ^[yY]$ ]] || { echo "Push canceled."; return 0; }
    fi

    printf "\nPushing changes to remote repository...\n"
    read -rp "Enter branch to push to (default: $current_branch): " branch
    branch=${branch:-$current_branch}

    # Check if there is anything to push
    if ! git diff --quiet --exit-code "origin/$branch" HEAD; then
        echo "Pushing to origin/$branch..."
    else
        echo "No changes to push on branch '$branch'."
        return 0
    fi

    if ! git push origin "$branch" 2>&1; then
        printf "Push to branch '%s' failed! Check for remote changes or authentication issues.\n" "$branch" >&2
        return 1
    fi

    printf "Changes pushed successfully to '%s'!\n" "$branch"
}

fetch_changes() {
    printf "\nFetching changes from remote repository...\n"
    if ! git fetch; then
        echo "Fetch failed!" >&2
        return 1
    fi
    printf "Fetch completed!\n\n"

    printf "Remote changes summary:\n"
    local current_branch remote_log
    current_branch=$(git branch --show-current)

    if ! git show-ref --verify --quiet "refs/remotes/origin/$current_branch"; then
        printf "No upstream branch found for '%s'.\n" "$current_branch"
        return
    fi

    remote_log=$(git log "HEAD..origin/$current_branch" --oneline)
    if [[ -n "$remote_log" ]]; then
        printf "%s\n" "$remote_log"
    else
        printf "No new remote changes on branch '%s'.\n" "$current_branch"
    fi
}

pull_changes() {
    local current_branch
    current_branch=$(git branch --show-current)

    if [[ -z "$current_branch" ]]; then
        printf "Error: Could not determine current branch.\n" >&2
        return 0 # Return to menu
    fi

    printf "\nPulling changes from remote repository...\n"
    if ! git pull origin "$current_branch"; then
        printf "Pull failed!\n" >&2
        return 1
    fi
    printf "Pull completed!\n"
}

view_log() {
    echo -e "\nGit Log (last 10 commits):\n-------------------------"
    git log --oneline -10 || true
    printf "\n"

    read -rp "View detailed log? (y/n): " detail
    if [[ "$detail" =~ ^[yY]$ ]]; then
        git log -5 --pretty=format:"%h - %an, %ar : %s"
        printf "\n"
    fi
}

view_branches() {
    echo -e "\nLocal branches:\n---------------"
    git branch
    echo -e "\nRemote branches:\n----------------"
    git branch -r || true
}

wait_for_input() {
    read -rp "Press Enter to continue..."
}

main() {
    check_git_repo

    while true; do
        show_menu
        read -rp "Please select an option (1-9): " choice

        case "$choice" in
            1) clear; git_status || true; wait_for_input ;;
            2) clear; add_files || true; wait_for_input ;;
            3) clear; commit_changes || true; wait_for_input ;;
            4) clear; push_changes || true; wait_for_input ;;
            5) clear; fetch_changes || true; wait_for_input ;;
            6) clear; pull_changes || true; wait_for_input ;;
            7) clear; view_log || true; wait_for_input ;;
            8) clear; view_branches || true; wait_for_input ;;
            9) printf "Goodbye!\n"; exit 0 ;;
            *)
                printf "Invalid option! Please select 1-9.\n" >&2
                sleep 1
                ;;
        esac
    done
}

main "$@"