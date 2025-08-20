#!/bin/bash

# Upgrade a specific Odoo module for a given instance
# Get Odoo instances from odoo-list.sh
INSTANCES=$(./odoo-list.sh 2>/dev/null | grep -v "📦 Installed Odoo Instances:" | awk '{print $1}')
if [ -z "$INSTANCES" ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi
gum log -t timeonly -l info "📦 Installed Odoo Instances:"
INSTANCE_NAME=$(echo "$INSTANCES" | gum choose)
ODOO_VERSION=$(echo "$INSTANCE_NAME" | grep -oE '[0-9]+\.[0-9]+')
if [ -z "$ODOO_VERSION" ]; then
    gum log -t timeonly -l error "❌ Error: Could not extract version from instance name!"
    exit 1
fi

ODOO_USER="odoo$ODOO_VERSION"
ODOO_PATH="/opt/$ODOO_USER"

# Prompt for module name
MODULE_NAME=$(gum input --prompt="Enter module name to upgrade: ")

# Execute module upgrade
gum log -t timeonly -l info "🔄 Upgrading module $MODULE_NAME for Odoo $ODOO_VERSION..."
sudo -u "$ODOO_USER" $ODOO_PATH/venv/bin/python $ODOO_PATH/odoo/odoo-bin -c $ODOO_PATH/$ODOO_USER.conf -u "$MODULE_NAME"

gum log -t timeonly -l info "✅ Module $MODULE_NAME upgraded successfully!"