#!/bin/bash

# BIND DNS Server Management Script with Interactive Menu
# Author: Solo
# Date: 08-07-2025
# Description: Install, configure and manage BIND DNS server with menu interface

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Configuration variables
BIND_DIR="/etc/bind"
NAMED_CONF="$BIND_DIR/named.conf"
NAMED_CONF_OPTIONS="$BIND_DIR/named.conf.options"
NAMED_CONF_LOCAL="$BIND_DIR/named.conf.local"
ZONE_DIR="$BIND_DIR/zones"
LOG_DIR="/var/log/bind"
SAMPLE_ZONE="example.com"

# Function to display the main menu
show_menu() {
    clear
    echo "===================================="
    echo " BIND DNS Server Management Menu"
    echo "===================================="
    echo "1. Install BIND DNS Server"
    echo "2. Configure Basic BIND Options"
    echo "3. Create New DNS Zone"
    echo "4. Add Record to Existing Zone"
    echo "5. Check BIND Configuration"
    echo "6. Restart BIND Service"
    echo "7. Show BIND Status"
    echo "8. View Zone Files"
    echo "9. Enable/Disable Query Logging"
    echo "10. Exit"
    echo "===================================="
    echo -n "Enter your choice [1-10]: "
}

# Function to install BIND
install_bind() {
    echo "Installing BIND DNS server..."

    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y bind9 bind9utils dnsutils
    elif command -v yum &> /dev/null; then
        yum install -y bind bind-utils
    elif command -v dnf &> /dev/null; then
        dnf install -y bind bind-utils
    else
        echo "Package manager not found. Please install BIND manually."
        exit 1
    fi

    # Create necessary directories
    mkdir -p "$ZONE_DIR"
    mkdir -p "$LOG_DIR"
    chown -R bind:bind "$LOG_DIR"

    # Configure logging
    if [ ! -f "$BIND_DIR/named.conf.logging" ]; then
        cat > "$BIND_DIR/named.conf.logging" <<EOF
logging {
    channel default_log {
        file "$LOG_DIR/named.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-severity yes;
        print-category yes;
    };
    category default { default_log; };
    category queries { default_log; };
};
EOF
    fi

    # Include logging config in named.conf
    if ! grep -q "named.conf.logging" "$NAMED_CONF"; then
        echo 'include "/etc/bind/named.conf.logging";' >> "$NAMED_CONF"
    fi

    echo "BIND installation completed."
    read -r -p "Press [Enter] to return to menu..."
}

# Function to configure basic options
configure_basic() {
    echo "Configuring basic BIND options..."

    # Backup existing config
    cp "$NAMED_CONF_OPTIONS" "$NAMED_CONF_OPTIONS.bak"

    # Get network information for allow-query
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    NETWORK=$(echo "$IP_ADDRESS" | awk -F. '{print $1"."$2".0.0"}')

    cat > "$NAMED_CONF_OPTIONS" <<EOF
options {
    directory "/var/cache/bind";

    // Forwarders
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    dnssec-validation auto;

    auth-nxdomain no;    # conform to RFC1035
    listen-on-v6 { any; };

    // Query logging (initially disabled)
    // querylog yes;

    // Allow queries from localhost and local network
    allow-query { localhost; $NETWORK/16; 10.0.0.0/8; };

    // Allow recursive queries from trusted clients
    allow-recursion { localhost; $NETWORK/16; 10.0.0.0/8; };

    // Enable statistics
    statistics-file "$LOG_DIR/named.stats";
};
EOF

    echo "Basic configuration updated. Original config backed up as $NAMED_CONF_OPTIONS.bak"
    read -p "Press [Enter] to return to menu..."
}

# Function to create a new zone
create_zone_interactive() {
    clear
    echo "=============================="
    echo " Create New DNS Zone"
    echo "=============================="

    read -r -p "Enter zone name (e.g., example.com): " ZONE_NAME
    if [ -z "$ZONE_NAME" ]; then
        echo "Zone name cannot be empty!"
        read -r -p "Press [Enter] to try again..."
        return
    fi

    ZONE_FILE="$ZONE_DIR/db.$ZONE_NAME"

    if [ -f "$ZONE_FILE" ]; then
        echo "Zone $ZONE_NAME already exists!"
        read -r -p "Press [Enter] to return to menu..."
        return
    fi

    read -r -p "Enter primary nameserver (e.g., ns1.$ZONE_NAME): " PRIMARY_NS
    read -r -p "Enter admin email (e.g., admin.$ZONE_NAME): " ADMIN_EMAIL
    read -r -p "Enter default IP address for records: " DEFAULT_IP

    # Create zone file
    cat > "$ZONE_FILE" <<EOF
\$TTL    86400
@       IN      SOA     $PRIMARY_NS. $ADMIN_EMAIL. (
                      $(date +%Y%m%d)01 ; Serial
                          3600       ; Refresh
                          1800       ; Retry
                        604800       ; Expire
                         86400 )     ; Minimum TTL
;
@       IN      NS      $PRIMARY_NS.
@       IN      A       $DEFAULT_IP
$(echo "$PRIMARY_NS" | cut -d'.' -f1)     IN      A       $DEFAULT_IP
www     IN      A       $DEFAULT_IP
EOF

    # Add zone to named.conf.local
    cat >> "$NAMED_CONF_LOCAL" <<EOF
zone "$ZONE_NAME" {
    type master;
    file "$ZONE_DIR/db.$ZONE_NAME";
    allow-update { none; };
};
EOF

    echo "Zone $ZONE_NAME created successfully."
    echo "Zone file: $ZONE_FILE"
    echo "Don't forget to update the serial number when making changes!"
    read -r -p "Press [Enter] to return to menu..."
}

# Function to add a record to a zone
add_record_interactive() {
    clear
    echo "=============================="
    echo " Add Record to DNS Zone"
    echo "=============================="

    # List available zones
    echo "Available zones:"
    grep "zone " "$NAMED_CONF_LOCAL" | awk '{print $2}' | tr -d '"' | nl
    echo "0. Return to menu"

    read -r -p "Select zone number: " ZONE_NUM
    if [ "$ZONE_NUM" -eq 0 ]; then
        return
    fi

    ZONE_NAME=$(grep "zone " "$NAMED_CONF_LOCAL" | awk '{print $2}' | tr -d '"' | sed -n "${ZONE_NUM}p")
    if [ -z "$ZONE_NAME" ]; then
        echo "Invalid zone number!"
        read -r -p "Press [Enter] to try again..."
        return
    fi

    ZONE_FILE="$ZONE_DIR/db.$ZONE_NAME"

    if [ ! -f "$ZONE_FILE" ]; then
        echo "Zone file for $ZONE_NAME not found!"
        read -r -p "Press [Enter] to return to menu..."
        return
    fi

    echo "Current records in $ZONE_NAME:"
    grep -vE '^\$|^;' "$ZONE_FILE" | awk '{print $1, $2, $3, $4}'

    read -r -p "Enter record name (e.g., www, mail, @): " RECORD_NAME
    read -r -p "Enter record type (A, CNAME, MX, etc.): " RECORD_TYPE
    read -r -p "Enter record value: " RECORD_VALUE

    # Increment serial number
    CURRENT_SERIAL=$(grep -Po '\d+' "$ZONE_FILE" | head -1)
    NEW_SERIAL=$((CURRENT_SERIAL + 1))
    sed -i "s/$CURRENT_SERIAL/$NEW_SERIAL/" "$ZONE_FILE"

    # Add new record
    echo "$RECORD_NAME    IN      $RECORD_TYPE      $RECORD_VALUE" >> "$ZONE_FILE"

    echo "Record added successfully to zone $ZONE_NAME."
    echo "New serial number: $NEW_SERIAL"
    read -r -p "Press [Enter] to return to menu..."
}

# Function to check BIND configuration
check_config() {
    clear
    echo "=============================="
    echo " Checking BIND Configuration"
    echo "=============================="

    named-checkconf -z "$NAMED_CONF"
    if [ $? -eq 0 ]; then
        echo "BIND configuration appears to be valid."
    else
        echo "BIND configuration has errors!"
    fi

    read -r -p "Press [Enter] to return to menu..."
}

# Function to restart BIND service
restart_bind() {
    clear
    echo "=============================="
    echo " Restarting BIND Service"
    echo "=============================="

    if command -v systemctl &> /dev/null; then
        systemctl restart named || systemctl restart bind9
    else
        service named restart || service bind9 restart
    fi

    # Check status
    if command -v systemctl &> /dev/null; then
        systemctl status named || systemctl status bind9
    else
        service named status || service bind9 status
    fi

    read -r -p "Press [Enter] to return to menu..."
}

# Function to show BIND status
show_status() {
    clear
    echo "=============================="
    echo " BIND DNS Server Status"
    echo "=============================="

    echo -e "\nService Status:"
    if command -v systemctl &> /dev/null; then
        systemctl status named || systemctl status bind9 | head -10
    else
        service named status || service bind9 status | head -10
    fi

    echo -e "\nListening on ports:"
    netstat -tulnp | grep named

    echo -e "\nConfigured Zones:"
    grep "zone " "$NAMED_CONF_LOCAL" | awk '{print $2}' | tr -d '"'

    read -r -p "Press [Enter] to return to menu..."
}

# Function to view zone files
view_zone_files() {
    clear
    echo "=============================="
    echo " View Zone Files"
    echo "=============================="

    # List available zones
    echo "Available zones:"
    grep "zone " "$NAMED_CONF_LOCAL" | awk '{print $2}' | tr -d '"' | nl
    echo "0. Return to menu"

    read -r -p "Select zone number to view: " ZONE_NUM
    if [ "$ZONE_NUM" -eq 0 ]; then
        return
    fi

    ZONE_NAME=$(grep "zone " "$NAMED_CONF_LOCAL" | awk '{print $2}' | tr -d '"' | sed -n "${ZONE_NUM}p")
    if [ -z "$ZONE_NAME" ]; then
        echo "Invalid zone number!"
        read -p "Press [Enter] to try again..."
        return
    fi

    ZONE_FILE="$ZONE_DIR/db.$ZONE_NAME"

    if [ ! -f "$ZONE_FILE" ]; then
        echo "Zone file for $ZONE_NAME not found!"
        read -r -p "Press [Enter] to return to menu..."
        return
    fi

    clear
    echo "Contents of $ZONE_NAME zone file:"
    echo "--------------------------------"
    cat "$ZONE_FILE"

    read -r -p "Press [Enter] to return to menu..."
}

# Function to toggle query logging
toggle_query_logging() {
    clear
    echo "=============================="
    echo " Enable/Disable Query Logging"
    echo "=============================="

    if grep -q "^[[:space:]]*querylog yes" "$NAMED_CONF_OPTIONS"; then
        echo "Query logging is currently ENABLED"
        read -r -p "Do you want to disable query logging? (y/n): " choice
        if [ "$choice" = "y" ]; then
            sed -i 's/querylog yes/\/\/ querylog yes/' "$NAMED_CONF_OPTIONS"
            echo "Query logging disabled"
        fi
    else
        echo "Query logging is currently DISABLED"
        read -r -p "Do you want to enable query logging? (y/n): " choice
        if [ "$choice" = "y" ]; then
            sed -i 's/\/\/ querylog yes/querylog yes/' "$NAMED_CONF_OPTIONS"
            echo "Query logging enabled"
        fi
    fi

    restart_bind
}

# Main menu loop
while true; do
    show_menu
    read -r choice

    case $choice in
        1) install_bind ;;
        2) configure_basic ;;
        3) create_zone_interactive ;;
        4) add_record_interactive ;;
        5) check_config ;;
        6) restart_bind ;;
        7) show_status ;;
        8) view_zone_files ;;
        9) toggle_query_logging ;;
        10) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
