#!/bin/bash
# Git Management Script with Menu
# Enable tab completion for git commands
if [ -f /usr/share/bash-completion/completions/git ]; then
    source /usr/share/bash-completion/completions/git
elif [ -f /etc/bash_completion.d/git ]; then
    source /etc/bash_completion.d/git
elif [ -f ~/.git-completion.bash ]; then
    source ~/.git-completion.bash
fi

# Enable tab completion for bash
set -o emacs
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

show_menu()    echo "=================================="
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
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not a git repository!"
        exit 1
    fi
}

git_status() {
    echo "Git Status:"
    echo "----------"
    git status
}

add_files() {
    echo "Current status:"
    git status --short
    echo ""
    read -p "Add all files? (y/n) or specify files: " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        git add .
        echo "All files added to staging area."
    elif [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
        read -p "Enter file names (space separated): " files
        git add $files
        echo "Selected files added to staging area."
    else
        git add $choice
        echo "Files added to staging area."
    fi
}

commit_changes() {
    echo "Staged files:"
    git diff --cached --name-only
    echo ""
    read -p "Enter commit message: " message
    if [ -z "$message" ]; then
        echo "Commit message cannot be empty!"
        return 1
    fi
    git commit -m "$message"
    echo "Changes committed successfully!"
}

push_changes() {
    echo "Pushing changes to remote repository..."
    current_branch=$(git branch --show-current)
    read -p "Push to branch '$current_branch'? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        git push origin $current_branch
        echo "Changes pushed successfully!"
    else
        read -p "Enter branch name: " branch
        git push origin $branch
        echo "Changes pushed to $branch successfully!"
    fi
}

fetch_changes() {
    echo "Fetching changes from remote repository..."
    git fetch
    echo "Fetch completed!"
    echo ""
    echo "Remote changes summary:"
    git log HEAD..origin/$(git branch --show-current) --oneline 2>/dev/null || echo "No new changes to fetch."
}

pull_changes() {
    echo "Pulling changes from remote repository..."
    current_branch=$(git branch --show-current)
    git pull origin $current_branch
    echo "Pull completed!"
}

view_log() {
    echo "Git Log (last 10 commits):"
    echo "-------------------------"
    git log --oneline -10
    echo ""
    read -p "View detailed log? (y/n): " detail
    if [ "$detail" = "y" ] || [ "$detail" = "Y" ]; then
        git log -5 --pretty=format:"%h - %an, %ar : %s"
    fi
}

view_branches() {
    echo "Local branches:"
    echo "---------------"
    git branch
    echo ""
    echo "Remote branches:"
    echo "----------------"
    git branch -r
}

# Main script execution
clear
check_git_repo

while true; do
    show_menu
    read -p "Please select an option (1-9): " choice

    case $choice in
        1)
            clear
            git_status
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        2)
            clear
            add_files
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        3)
            clear
            commit_changes
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        4)
            clear
            push_changes
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        5)
            clear
            fetch_changes
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        6)
            clear
            pull_changes
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        7)
            clear
            view_log
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        8)
            clear
            view_branches
            echo ""
            read -p "Press Enter to continue..."
            clear
            ;;
        9)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option! Please select 1-9."
            sleep 2
            clear
            ;;
    esac
done
