#!/bin/bash

# Upgrade a specific Odoo module for a given instance
# Get Odoo instances from odoo-list.sh (format: ODOO_USER|ODOO_PATH)
CONFIG_FILE="/etc/odoo-scripts.conf"
ODOO_SCRIPTS_DIR="/opt/odoo-scripts"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

INSTANCES_RAW=$($ODOO_SCRIPTS_DIR/odoo-list.sh 2>&1 | grep -v "📦 Installed Odoo Instances:")
if [ -z "$INSTANCES_RAW" ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi

# Extract just the user names for selection
INSTANCE_NAMES=$(echo "$INSTANCES_RAW" | cut -d'|' -f1)
gum log -t timeonly -l info "📦 Installed Odoo Instances:"
SELECTED_INSTANCE=$(echo "$INSTANCE_NAMES" | gum choose)

# Find the corresponding path for the selected instance
SELECTED_LINE=$(echo "$INSTANCES_RAW" | grep "^$SELECTED_INSTANCE|")
ODOO_USER=$(echo "$SELECTED_LINE" | cut -d'|' -f1)
ODOO_PATH=$(echo "$SELECTED_LINE" | cut -d'|' -f2)

if [ -z "$ODOO_USER" ] || [ -z "$ODOO_PATH" ]; then
    gum log -t timeonly -l error "❌ Error: Could not extract user and path information!"
    exit 1
fi

# Prompt for module name
MODULE_NAME=$(gum input --prompt="Enter module name to upgrade: ")

# Execute module upgrade
gum log -t timeonly -l info "🔄 Upgrading module $MODULE_NAME for $ODOO_USER in $ODOO_PATH..."
sudo -u "$ODOO_USER" $ODOO_PATH/venv/bin/python $ODOO_PATH/odoo/odoo-bin -c $ODOO_PATH/$ODOO_USER.conf -u "$MODULE_NAME"

gum log -t timeonly -l info "✅ Module $MODULE_NAME upgraded successfully!"