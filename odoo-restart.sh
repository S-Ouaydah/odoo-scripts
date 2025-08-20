#!/bin/bash

# Restart Odoo instance by name
# Get list of instances using odoo-list.sh
INSTANCES_OUTPUT=$(odoo-list.sh 2>&1)

# Extract instance names (skip the first line which is the log message)
INSTANCES=$(echo "$INSTANCES_OUTPUT" | sed '1d' | grep -v '^$')

if [ -z "$INSTANCES" ]; then
    gum log -t timeonly -l error "❌ No Odoo instances found!"
    exit 1
fi

INSTANCE_NAME=$(echo "$INSTANCES" | gum choose --header="Select Odoo instance to restart:")

# Check if instance exists
if ! systemctl list-units --type=service | grep -i "$INSTANCE_NAME" > /dev/null; then
    gum log -t timeonly -l error "❌ Error: Instance $INSTANCE_NAME not found!"
    exit 1
fi

# Restart the instance
gum log -t timeonly -l info "🔄 Restarting Odoo instance $INSTANCE_NAME..."
sudo systemctl restart "$INSTANCE_NAME"

gum log -t timeonly -l info "✅ Odoo instance $INSTANCE_NAME restarted successfully!"