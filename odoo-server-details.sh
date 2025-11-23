#!/bin/bash

# Display server details for a specific Odoo instance
CONFIG_FILE="/etc/odoo-scripts.conf"
ODOO_SCRIPTS_DIR="/opt/odoo-scripts"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Help function
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: odoo-server-details"
    echo "Display details (ports, passwords, paths) for a selected Odoo instance."
    exit 0
fi

# Get Odoo instances from odoo-list.sh (format: ODOO_USER|ODOO_PATH)
INSTANCES_RAW=$($ODOO_SCRIPTS_DIR/odoo-list.sh 2>/dev/null | grep -v "📦 Installed Odoo Instances:")
if [ -z "$INSTANCES_RAW" ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi

# Extract just the version names for selection
INSTANCE_NAMES=$(echo "$INSTANCES_RAW" | cut -d'|' -f1)

gum log -t timeonly -l info "📦 Select Odoo Instance for Server Details:"
SELECTED_INSTANCE=$(echo "$INSTANCE_NAMES" | gum choose)

# Check if server_info.txt exists for the selected version
SERVER_INFO_FILE="/opt/$SELECTED_INSTANCE/server_info.txt"

if [ -f "$SERVER_INFO_FILE" ]; then
    # Format the file content to be displayed in a gum dialog
    gum style --foreground 4 --border-foreground 3 --border double --align left --width 100 --margin "1 2" --padding "2 4" "$(gum format -- "$(cat "$SERVER_INFO_FILE")")"
else
    gum log -t timeonly -l warn "⚠️ Server info file not found for $SELECTED_INSTANCE at $SERVER_INFO_FILE"
fi

