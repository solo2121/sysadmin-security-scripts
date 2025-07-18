#!/bin/bash

# Pure Pacstall Update & Clean Script
# This script will:
# 1. Update all Pacstall packages (pacstall -U)
# 2. Clean Pacstall cache (pacstall -Cc)
# 3. Remove orphaned dependencies (if safe)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Please run this script as root or with sudo."
    exit 1
fi

# Check if Pacstall is installed
if ! command -v pacstall &> /dev/null; then
    echo "❌ Pacstall is not installed. Exiting."
    exit 1
fi

# Update all Pacstall packages (without -p)
echo "🔄 Updating Pacstall packages (pacstall -U)..."
pacstall -U

# Clean Pacstall cache
echo "🧹 Cleaning Pacstall cache..."
pacstall -Cc

# Check for orphaned dependencies (optional)
echo "🔍 Checking for orphaned dependencies..."
orphaned=$(pacstall -L | grep -v 'installed')
if [ -n "$orphaned" ]; then
    echo "⚠️ Found orphaned dependencies:"
    echo "$orphaned"
    read -p "❓ Remove them? (y/N) " choice
    case "$choice" in
        y|Y) 
            echo "🗑️ Removing orphaned dependencies..."
            pacstall -L | grep -v 'installed' | xargs -r sudo apt remove --purge -y
            ;;
        *) 
            echo "⏩ Skipping orphaned removal."
            ;;
    esac
fi

echo "✅ Pacstall update & clean completed!"