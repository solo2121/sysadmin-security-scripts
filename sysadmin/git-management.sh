#!/usr/bin/env bash
# Modern Git Management Script with Menu

# Enable strict mode
set -o errexit      # Exit on error
set -o nounset      # Exit on unset variables
set -o pipefail     # Catch pipe failures
shopt -s nocasematch # Case-insensitive matching

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command_name=${2:-"unknown"}
    echo "Error occurred at line $line_number: command '$command_name' exited with status $exit_code" >&2
    exit "$exit_code"
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Enable git completion if available
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

# Enhanced readline settings
bind -x '"\C-l": clear' # Bind Ctrl+L to clear
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

show_menu() {
    clear
    printf "%s\n" "==================================" \
                  "        Git Management Menu" \
                  "==================================" \
                  "1. Check Git Status" \
                  "2. Add Files to Staging" \
                  "3. Commit Changes" \
                  "4. Push to Remote" \
                  "5. Fetch from Remote" \
                  "6. Pull from Remote" \
                  "7. View Git Log" \
                  "8. View Branches" \
                  "9. Exit" \
                  "=================================="
}

check_git_repo() {
    if ! git rev-parse --git-dir &>/dev/null; then
        printf "Error: Not a git repository!\\n" >&2
        exit 1
    fi
}

git_status() {
    printf "\\nGit Status:\\n"
    printf "%s\\n" "----------"
    git status
}

add_files() {
    printf "\\nCurrent status:\\n"
    git status --short
    printf "\\n"
    
    read -rp "Add all files? (y/n) or specify files: " choice
    
    case "$choice" in
        [yY]|[yY][eE][sS])
            git add .
            printf "All files added to staging area.\\n"
            ;;
        [nN]|[nN][oO])
            read -rp "Enter file names (space separated): " -a files_array
            if (( ${#files_array[@]} == 0 )); then
                printf "No files specified.\\n" >&2
                return 1
            fi
            git add "${files_array[@]}"
            printf "Selected files added to staging area.\\n"
            ;;
        *)
            if [[ -n "$choice" ]]; then
                git add "$choice"
                printf "Files added to staging area.\\n"
            else
                printf "No input provided.\\n" >&2
                return 1
            fi
            ;;
    esac
}

commit_changes() {
    printf "\\nStaged files:\\n"
    git diff --cached --name-only
    printf "\\n"
    
    while true; do
        read -rp "Enter commit message: " message
        if [[ -n "$message" ]]; then
            if ! git commit -m "$message"; then
                printf "Commit failed!\\n" >&2
                return 1
            fi
            printf "Changes committed successfully!\\n"
            break
        else
            printf "Commit message cannot be empty! Try again.\\n" >&2
        fi
    done
}

push_changes() {
    local current_branch
    current_branch=$(git branch --show-current)
    
    printf "\\nPushing changes to remote repository...\\n"
    read -rp "Push to branch '%s'? (y/n): " "current_branch" confirm
    
    if [[ "$confirm" =~ ^[yY] ]]; then
        if ! git push origin "$current_branch"; then
            printf "Push failed!\\n" >&2
            return 1
        fi
    else
        read -rp "Enter branch name: " branch
        if ! git push origin "$branch"; then
            printf "Push failed!\\n" >&2
            return 1
        fi
    fi
    
    printf "Changes pushed successfully!\\n"
}

fetch_changes() {
    printf "\\nFetching changes from remote repository...\\n"
    if ! git fetch; then
        printf "Fetch failed!\\n" >&2
        return 1
    fi
    printf "Fetch completed!\\n\\n"
    
    printf "Remote changes summary:\\n"
    if ! git log HEAD..origin/"$(git branch --show-current)" --oneline 2>/dev/null; then
        printf "No new changes to fetch.\\n"
    fi
}

pull_changes() {
    local current_branch
    current_branch=$(git branch --show-current)
    
    printf "\\nPulling changes from remote repository...\\n"
    if ! git pull origin "$current_branch"; then
        printf "Pull failed!\\n" >&2
        return 1
    fi
    printf "Pull completed!\\n"
}

view_log() {
    printf "\\nGit Log (last 10 commits):\\n"
    printf "%s\\n" "-------------------------"
    git log --oneline -10
    printf "\\n"
    
    read -rp "View detailed log? (y/n): " detail
    if [[ "$detail" =~ ^[yY] ]]; then
        git log -5 --pretty=format:"%h - %an, %ar : %s"
    fi
}

view_branches() {
    printf "\\nLocal branches:\\n"
    printf "%s\\n" "---------------"
    git branch
    printf "\\nRemote branches:\\n"
    printf "%s\\n" "----------------"
    git branch -r
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
            1) clear; git_status; wait_for_input ;;
            2) clear; add_files; wait_for_input ;;
            3) clear; commit_changes; wait_for_input ;;
            4) clear; push_changes; wait_for_input ;;
            5) clear; fetch_changes; wait_for_input ;;
            6) clear; pull_changes; wait_for_input ;;
            7) clear; view_log; wait_for_input ;;
            8) clear; view_branches; wait_for_input ;;
            9) printf "Goodbye!\\n"; exit 0 ;;
            *) 
                printf "Invalid option! Please select 1-9.\\n" >&2
                sleep 1
                ;;
        esac
    done
}

main "$@"