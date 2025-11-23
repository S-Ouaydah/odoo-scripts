#!/bin/bash

# List all installed Odoo instances by checking directories and their loc.txt files
ODOO_VERSIONS=()
ODOO_PATHS=()
CONFIG_FILE="/etc/odoo-scripts.conf"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ODOO_BASE_DIR="/opt"
fi

# Check for Odoo versions in ODOO_BASE_DIR
for dir in "$ODOO_BASE_DIR"/*/; do
    if [ -d "$dir" ]; then
        # Extract version name from directory path
        VERSION=$(basename "$dir")
        
        # Check if this looks like an Odoo version (contains "odoo" case-insensitive)
        if [[ "$VERSION" =~ [Oo]doo ]]; then
            LOC_FILE="$dir/loc.txt"
            
            # Check if loc.txt exists and read the odoo_path
            if [ -f "$LOC_FILE" ]; then
                ODOO_PATH=$(cat "$LOC_FILE" 2>/dev/null | tr -d '\n')
                
                if [ -n "$ODOO_PATH" ]; then
                    ODOO_VERSIONS+=("$VERSION")
                    ODOO_PATHS+=("$ODOO_PATH")
                fi
            fi
        fi
    fi
done

# Check if any Odoo instances were found
if [ ${#ODOO_VERSIONS[@]} -eq 0 ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi

gum log -t timeonly -l info "📦 Installed Odoo Instances:"

# Output version and path pairs, separated by pipe (|) for easy parsing
for i in "${!ODOO_VERSIONS[@]}"; do
    echo "${ODOO_VERSIONS[$i]}|${ODOO_PATHS[$i]}"
done