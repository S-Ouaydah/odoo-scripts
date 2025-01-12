#!/bin/bash

# Entry point to install slomax's odoo-scripts
# wget -O- https://raw.githubusercontent.com/S-Ouaydah/odoo-scripts/refs/heads/expansion/server_init.sh | bash
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/S-Ouaydah/odoo-scripts/refs/heads/expansion/server_init.sh)" || true
GREEN="\e[32m"
RESET="\e[0m"

REPO_LOC="/opt/odoo-scripts"
ZENV="/etc/zsh/zshenv"
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

git clone https://github.com/S-Ouaydah/odoo-scripts --branch expansion $REPO_LOC
chmod +x $REPO_LOC/*.sh

# Check if Zsh is installed
if ! command -v zsh >/dev/null 2>&1; then
    echo -e "${GREEN}Installing Oh-My-Zsh...${RESET}"
    sudo apt-get install -y zsh
    gum log -t timeonly -l info "🚀 Use install-odoo to start with the Odoo installation." --message.foreground 3
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
    gum log -t timeonly -l info "✅ Oh-My-Zsh has been installed successfully." --message.foreground 2
    echo "path+=($REPO_LOC)" >> $ZENV
    # Set aliases
    echo "alias install-odoo='$REPO_LOC/install_odoo.sh'" >> $ZENV
    echo "alias server-info='$REPO_LOC/get_server_details.sh'" >> $ZENV
    echo "alias update-odoo-scripts='cd $REPO_LOC && git pull'" >> $ZENV
    echo "alias odoo-restart='systemctl restart'" >> $ZENV

fi

