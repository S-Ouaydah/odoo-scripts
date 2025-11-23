#!/bin/bash

# View logs for a specific Odoo instance
CONFIG_FILE="/etc/odoo-scripts.conf"
ODOO_SCRIPTS_DIR="/opt/odoo-scripts"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ODOO_BASE_DIR="/opt"
fi

# Help function
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: odoo-logs"
    echo "Interactively select an Odoo instance and tail its log file."
    exit 0
fi

# Get Odoo instances from odoo-list.sh
INSTANCES_RAW=$($ODOO_SCRIPTS_DIR/odoo-list.sh 2>/dev/null | grep -v "📦 Installed Odoo Instances:")
if [ -z "$INSTANCES_RAW" ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi

# Extract just the user names for selection
INSTANCE_NAMES=$(echo "$INSTANCES_RAW" | cut -d'|' -f1)
gum log -t timeonly -l info "📦 Select Odoo Instance to view logs:"
SELECTED_INSTANCE=$(echo "$INSTANCE_NAMES" | gum choose)

# Find the corresponding path for the selected instance
SELECTED_LINE=$(echo "$INSTANCES_RAW" | grep "^$SELECTED_INSTANCE|")
ODOO_USER=$(echo "$SELECTED_LINE" | cut -d'|' -f1)
ODOO_PATH=$(echo "$SELECTED_LINE" | cut -d'|' -f2)

LOG_FILE="$ODOO_PATH/$ODOO_USER.log"

if [ ! -f "$LOG_FILE" ]; then
    gum log -t timeonly -l error "❌ Log file not found at $LOG_FILE"
    exit 1
fi

gum log -t timeonly -l info "📄 Tailing log file: $LOG_FILE (Press Ctrl+C to exit)"
tail -f -n 50 "$LOG_FILE" | gum format
