#!/bin/bash

# Entry point to install slomax's odoo-scripts
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/S-Ouaydah/odoo-scripts/refs/heads/expansion/server_init.sh)"
GREEN="\e[32m"
RESET="\e[0m"

REPO_LOC="/opt/odoo-scripts"
CONFIG_FILE="/etc/odoo-scripts.conf"

# Check if gum is installed
if ! command -v gum >/dev/null 2>&1; then
  echo -e "${GREEN}Installing Gum...${RESET}"
  # Add Charm repository
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
  sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gum
  gum log -t timeonly -l info "✅ Gum has been installed successfully." --message.foreground 2
fi

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    gum log -t timeonly -l info "📝 Creating default configuration at $CONFIG_FILE..."
    sudo bash -c "cat > $CONFIG_FILE" <<EOL
# Odoo Scripts Configuration
ODOO_BASE_DIR="/opt"
EOL
fi

# Clone or update repository
if [ -d "$REPO_LOC" ]; then
    gum log -t timeonly -l info "🔄 Updating existing repository at $REPO_LOC..."
    cd "$REPO_LOC" && git pull
else
    gum log -t timeonly -l info "📥 Cloning repository to $REPO_LOC..."
    sudo git clone https://github.com/S-Ouaydah/odoo-scripts --branch expansion "$REPO_LOC"
    sudo chown -R $USER:$USER "$REPO_LOC"
fi

chmod +x "$REPO_LOC"/*.sh

# Zsh Installation
if ! command -v zsh >/dev/null 2>&1; then
    echo -e "${GREEN}Installing Zsh...${RESET}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
    gum log -t timeonly -l info "✅ Zsh has been installed successfully."

    if gum confirm "Do you want to set Zsh as your default shell?" --default=false; then
        chsh -s "$(which zsh)"
        gum log -t timeonly -l info "✅ Zsh set as default shell. Please log out and back in for changes to take effect."
    else
        gum log -t timeonly -l info "Skipping setting Zsh as default shell."
    fi
fi

# Oh-My-Zsh Installation (if Zsh is installed and Oh-My-Zsh is not)
if command -v zsh >/dev/null 2>&1 && [ ! -d "$HOME/.oh-my-zsh" ]; then
    if gum confirm "Do you want to install Oh-My-Zsh?" --default=false; then
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
        gum log -t timeonly -l info "✅ Oh-My-Zsh has been installed successfully."
    else
        gum log -t timeonly -l info "Skipping Oh-My-Zsh installation."
    fi
fi

# Setup Aliases (Append if not exists)
ALIAS_FILE="$HOME/.bashrc"
if [[ "$SHELL" == */zsh ]]; then
    ALIAS_FILE="$HOME/.zshrc"
fi

gum log -t timeonly -l info "🔗 Adding aliases to $ALIAS_FILE..."

add_alias() {
    local name=$1
    local command=$2
    if ! grep -q "alias $name=" "$ALIAS_FILE"; then
        echo "alias $name='$command'" >> "$ALIAS_FILE"
    fi
}

add_alias "odoo-install" "$REPO_LOC/odoo-install.sh"
add_alias "odoo-server-details" "$REPO_LOC/odoo-server-details.sh"
add_alias "odoo-scripts-update" "cd $REPO_LOC && git pull"
add_alias "odoo-restart" "$REPO_LOC/odoo-restart.sh"
add_alias "odoo-list" "$REPO_LOC/odoo-list.sh"
add_alias "odoo-upgrade" "$REPO_LOC/odoo-upgrade.sh"
add_alias "odoo-config" "$REPO_LOC/odoo-config.sh"
add_alias "odoo-logs" "$REPO_LOC/odoo-logs.sh"
add_alias "odoo-ssl" "$REPO_LOC/odoo-ssl.sh"

gum log -t timeonly -l info "✅ Installation complete! Please restart your shell or run 'source $ALIAS_FILE'."

