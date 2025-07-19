#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [directory]"
    echo "Deletes all .srt and .vtt files in the specified directory."
    echo "If no directory is given, prompts for one."
    exit 1
}

# Check if directory is provided as argument
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    TARGET_DIR="$1"
else
    # If no argument, ask interactively with tab completion help note
    echo "Note: You can use TAB completion to fill in the path."
    read -r -e -p "Enter the directory path: " TARGET_DIR
fi

# Remove trailing slash if present and remove escape characters
TARGET_DIR="${TARGET_DIR%/}"
TARGET_DIR="${TARGET_DIR//\\/}"

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

# Find and list files that would be deleted
echo "The following files will be deleted:"
find "$TARGET_DIR" -type f \( -name "*.srt" -o -name "*.vtt" \) -print

# Ask for confirmation
read -p "Are you sure you want to delete these files? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Delete files
echo "Deleting files..."
find "$TARGET_DIR" -type f \( -name "*.srt" -o -name "*.vtt" \) -delete

echo "Deletion complete."
