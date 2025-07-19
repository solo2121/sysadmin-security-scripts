#!/bin/bash
 # Colors for better user experience
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Prompt user for sudo password
echo "Please enter your sudo password:"
read -r -s password

# Run rkhunter with sudo
echo "$password" | sudo -S rkhunter --update
echo "$password" | sudo -S rkhunter --check

# Run chkrootkit with sudo
echo "$password" | sudo -S chkrootkit

# Clean up - remove temporary files created by rkhunter
echo "$password" | sudo -S rkhunter --propupd

echo "Rootkit scan completed."
