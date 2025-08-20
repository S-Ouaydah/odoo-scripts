#!/bin/bash

# List all installed Odoo instances by checking systemd services
INSTANCES=$(systemctl list-units --type=service | grep -i odoo | awk '{print $1}')

if [ -z "$INSTANCES" ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi

gum log -t timeonly -l info "📦 Installed Odoo Instances:"
echo "$INSTANCES" | gum format