#!/bin/bash

# Configuration Editor for Odoo Scripts
CONFIG_FILE="/etc/odoo-scripts.conf"

# Ensure config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default configuration at $CONFIG_FILE..."
    sudo bash -c "cat > $CONFIG_FILE" <<EOL
# Odoo Scripts Configuration
ODOO_BASE_DIR="/opt"
EOL
fi

# Open config file in editor
if command -v nano >/dev/null 2>&1; then
    sudo nano "$CONFIG_FILE"
elif command -v vim >/dev/null 2>&1; then
    sudo vim "$CONFIG_FILE"
else
    sudo vi "$CONFIG_FILE"
fi
