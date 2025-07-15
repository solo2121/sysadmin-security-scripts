#!/bin/bash

# Function to update package lists and upgrade installed packages
update_upgrade() {
    echo "Updating package lists..."
    rpk update -y
}

# Function to clean old packages
clean_packages() {
    echo "Cleaning old packages..."
    rpk cleanup -y
}

# Main function
main() {
    update_upgrade
    clean_packages
    echo "Update and cleanup complete."
}

# Run the main function
main