#!/bin/bash

# Setup SSL for Odoo instance using Nginx and Certbot
CONFIG_FILE="/etc/odoo-scripts.conf"
ODOO_SCRIPTS_DIR="/opt/odoo-scripts"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ODOO_BASE_DIR="/opt"
fi

# Check for root
if [ "$EUID" -ne 0 ]; then 
  gum log -t timeonly -l error "❌ Please run as root"
  exit 1
fi

# Get Odoo instances
INSTANCES_RAW=$($ODOO_SCRIPTS_DIR/odoo-list.sh 2>/dev/null | grep -v "📦 Installed Odoo Instances:")
if [ -z "$INSTANCES_RAW" ]; then
    gum log -t timeonly -l warn "⚠️ No Odoo instances found!"
    exit 1
fi

# Select Instance
INSTANCE_NAMES=$(echo "$INSTANCES_RAW" | cut -d'|' -f1)
gum log -t timeonly -l info "📦 Select Odoo Instance for SSL setup:"
SELECTED_INSTANCE=$(echo "$INSTANCE_NAMES" | gum choose)

SELECTED_LINE=$(echo "$INSTANCES_RAW" | grep "^$SELECTED_INSTANCE|")
ODOO_USER=$(echo "$SELECTED_LINE" | cut -d'|' -f1)
ODOO_PATH=$(echo "$SELECTED_LINE" | cut -d'|' -f2)

# Get Domain Name
DOMAIN=$(gum input --prompt="Enter Domain Name (e.g., odoo.example.com): ")
if [ -z "$DOMAIN" ]; then
    gum log -t timeonly -l error "❌ Domain name is required!"
    exit 1
fi

# Install Nginx and Certbot
if ! command -v nginx >/dev/null 2>&1; then
    gum log -t timeonly -l info "📥 Installing Nginx..."
    apt-get install -y nginx
fi

if ! command -v certbot >/dev/null 2>&1; then
    gum log -t timeonly -l info "📥 Installing Certbot..."
    apt-get install -y certbot python3-certbot-nginx
fi

# Get Odoo Port (read from config or default)
CONF_FILE="$ODOO_PATH/$ODOO_USER.conf"
ODOO_PORT=$(grep "http_port" "$CONF_FILE" | cut -d'=' -f2 | tr -d ' ')
if [ -z "$ODOO_PORT" ]; then
    ODOO_PORT="8069" # Fallback
fi

# Create Nginx Config
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
gum log -t timeonly -l info "⚙️ Creating Nginx configuration..."

cat > "$NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;

    location / {
        proxy_pass http://127.0.0.1:$ODOO_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:8072;
    }
    
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
    gzip on;
}
EOL

# Enable Site
ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/"
rm -f /etc/nginx/sites-enabled/default
systemctl reload nginx

# Run Certbot
gum log -t timeonly -l info "🔒 Obtaining SSL Certificate..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN --redirect

gum log -t timeonly -l info "✅ SSL Setup Complete! Access your Odoo at https://$DOMAIN"
