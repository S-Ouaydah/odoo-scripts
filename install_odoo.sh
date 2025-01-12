#!/bin/bash

# Odoo Installer for Ubuntu Servers with the ability to handle multiple Odoo Intances
# wget https://raw.githubusercontent.com/S-Ouaydah/odoo-scripts/refs/heads/fancy_gum/install_odoo.sh && chmod +x install_odoo.sh && ./install_odoo.sh
set -e  # Exit immediately on error
trap "gum log -t timeonly -l warn 'Exiting script...'; exit 1" SIGINT

# Define color variables
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
GREY="\e[38;5;248m"
BOLD="\e[1m"
RESET="\e[0m"

# Check if gum is installed
if ! command -v gum >/dev/null 2>&1; then
  echo -e "${GREEN}Installing Gum...${RESET}"
  # Add Charm repository
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
  sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gum
  
  gum log -t timeonly -l info "Gum has been installed successfully." --message.foreground 2
  
fi
# Check if Zsh is installed
if ! command -v zsh >/dev/null 2>&1; then
    echo -e "${GREEN}Installing Oh-My-Zsh...${RESET}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
    gum log -t timeonly -l info "Oh-My-Zsh has been installed successfully." --message.foreground 2
    gum log -t timeonly -l info "Please run the script again to continue with Odoo installation." --message.foreground 3
    exit 0
fi

# Get values
ask_question() {
  local prompt="$1"
  local default_value="$2"
  local var_name="$3"
  
  # Use gum input for getting values with default
  local result=$(gum input --placeholder="($default_value)" --prompt="$prompt: ")
  # If result is empty, use the placeholder value
  if [ -z "$result" ]; then
    result="$default_value"
  fi
  eval $var_name='$result'
  # echo $result
  echo "    $prompt:$(gum style --foreground 5 --bold "$result")"
}

print_header() {
    local text="$1"
    echo -e "\n$(gum style --foreground 3 --border-foreground 5 --border double --align center --width 90 --margin "1 2" --padding "2 4" "$text")\n"
}

print_header "########## Installation of Odoo Version $ODOO_VERSION ##########"
#Log start time
gum log -t timeonly -l info "Installation Started!"

if gum confirm "Do you want to install Enterprise version?" --default=false; then
  IS_ENTERPRISE="True"
else
  IS_ENTERPRISE="False" 
fi
echo "    Is Enterprise:$(gum style --foreground 5 --bold "$IS_ENTERPRISE")"

ODOO_VERSION=$(gum choose "18.0" "17.0" "16.0" "15.0" --header="Choose Odoo Version:")
echo "    Odoo Version:$(gum style --foreground 5 --bold "$ODOO_VERSION")"

ask_question "    Master Password" "masteradmin" "MASTER_PASS"
ask_question "    Odoo Port" "80${ODOO_VERSION%%.*}" "ODOO_PORT"
ask_question "    Odoo User" "odoo${ODOO_VERSION%%.*}" "ODOO_USER"
ask_question "    Odoo Path" "/opt/$ODOO_USER" "ODOO_PATH"

# Check if user already exists
if id "$ODOO_USER" &>/dev/null; then
    gum log -t timeonly -l error "User $ODOO_USER already exists!"
    exit 1
fi

# Check if port is already in use
if sudo lsof -i :$ODOO_PORT > /dev/null 2>&1; then
    gum log -t timeonly -l error "Port $ODOO_PORT is already in use!"
    exit 1
fi

print_header "########## Creating Odoo User ##########"
gum spin --spinner dot --show-output --title "Creating user..." -- bash -c "
sudo useradd -m -U -r -d '$ODOO_PATH' -s /bin/bash '$ODOO_USER'
gum log -t timeonly -l info 'User $ODOO_USER created at $ODOO_PATH'
echo '$ODOO_USER:$MASTER_PASS' | sudo chpasswd
sudo usermod -aG sudo '$ODOO_USER'
gum log --level info ' user $ODOO_USER added to sudo group with password $MASTER_PASS '
"

#--------------------------------------------------
# Install APT Dependencies
#--------------------------------------------------
print_header "########## Updating System and Installing Prerequisites ##########"
gum spin --spinner dot --show-output --title "Updating system..." -- bash -c "
gum log -t timeonly -l info 'apt-upgrade...'
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
# python deps stopped for now
# sudo apt-get install -y python3 python3-cffi python3-dev python3-pip python3-setuptools python3-venv python3-wheel
gum log -t timeonly -l info 'apt install packages...'
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget gdebi libxml2-dev libxslt-dev zlib1g-dev libxrender1 libzip-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev\
      xfonts-75dpi xfonts-encodings xfonts-utils xfonts-base fontconfig\
      npm nodejs node-less\
      postgresql postgresql-client
  "

#--------------------------------------------------
# Install Node Dependencies
#--------------------------------------------------
print_header "########## Installing Node.js, npm, and Less ##########"
gum spin --spinner dot --show-output --title "Installing Node.js..." -- bash -c "
# Check if Node.js is already installed
if command -v node >/dev/null 2>&1; then
    gum log -t timeonly -l info 'Node.js is already installed' --message.foreground 2
else
    # sudo apt-get install -y npm nodejs node-less
    gum log -t timeonly -l info 'Linking nodejs...'
    sudo ln -s /usr/bin/nodejs /usr/bin/node || true
fi
gum log -t timeonly -l info 'Installing npm packages...'
sudo npm install -g less less-plugin-clean-css rtlcss node-gyp
"

#--------------------------------------------------
# Install WKHTMLTOPDF
#--------------------------------------------------
print_header "########## Installing wkhtmltopdf ##########"
gum spin --spinner dot --show-output --title "Installing wkhtmltopdf..." -- bash -c "
# Check if wkhtmltopdf is already installed
if command -v wkhtmltopdf >/dev/null 2>&1; then
    gum log -t timeonly -l info 'wkhtmltopdf is already installed' --message.foreground 2
else
    gum log -t timeonly -l info 'Installing wkhtmltopdf...'
    cd /tmp
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    sudo gdebi -n wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    gum log -t timeonly -l info 'Creating Links...'
    sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin/ || true
    sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin/ || true
    gum log -t timeonly -l info 'Cleaning up...'
    rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi
"

#--------------------------------------------------
# Install PostgresSQL
#--------------------------------------------------
print_header "########## Installing PostgreSQL ##########"
gum spin --spinner dot --show-output --title "Installing PostgreSQL..." -- bash -c "
# Check if PostgreSQL is already installed
if command -v psql >/dev/null 2>&1; then
    gum log -t timeonly -l info 'PostgreSQL is already installed' --message.foreground 2
else
    # sudo apt-get install -y postgresql postgresql-client
    sudo systemctl start postgresql && sudo systemctl enable postgresql
fi
sudo systemctl status postgresql
gum log -t timeonly -l info 'Creating PostgreSQL User...'
sudo -u postgres createuser -d -R -s $ODOO_USER
"

# sudo -u postgres createdb $ODOO_USER

#--------------------------------------------------
# Setting Up Odoo
#--------------------------------------------------
  # Cloning source
print_header "########## Cloning Odoo Source Code ##########"
gum spin --spinner dot --show-output --title "Cloning Odoo..." -- bash -c "
cd $ODOO_PATH
sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/odoo --depth 1 --branch $ODOO_VERSION --single-branch
gum log -t timeonly -l info 'Odoo Community Cloned...'
"

set +e
if [ $IS_ENTERPRISE = "True" ]; then
    GITHUB_RESPONSE=$(sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/enterprise --depth 1 --branch $ODOO_VERSION --single-branch 2>&1)
    echo $GITHUB_RESPONSE
    if [[ $GITHUB_RESPONSE == *"Authentication"* ]]; then
        gum log -t timeonly -l error "Error: Your authentication with Github has failed!" --message.foreground 1
        gum log -t timeonly -l info "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise." --message.foreground 3
        gum log -t timeonly -l info "Continuing installation without enterprise..."
        IS_ENTERPRISE="False"
    else
      gum log -t timeonly -l error "Error: Your authentication with Github has failed!" --message.foreground 1
      gum log -t timeonly -l info "Continuing installation without enterprise..."
    fi
else
    gum log -t timeonly -l info "This is only the community setup, skipping enterprise."
fi
set -e

  # Running odoo script
print_header "########## Installing Odoo Dependencies ##########"
gum log -t timeonly -l info "Running Odoo's debinstall script..."
gum spin --spinner dot --show-output --title "Installing dependencies..." -- bash -c "
sudo $ODOO_PATH/odoo/setup/debinstall.sh
"
  
  # Creating Odoo dirs and files
print_header "########## Setting Up The Odoo Directory ##########"
gum spin --spinner dot --show-output --title "Setting up directories..." -- bash -c "
gum log -t timeonly -l info 'Setting up Custom Addons Directory...'
sudo -u $ODOO_USER bash <<EOL
cd $ODOO_PATH
mkdir -p $ODOO_PATH/custom-addons
gum log -t timeonly -l info 'Setting up Log File...'
touch $ODOO_PATH/$ODOO_USER.log
touch $ODOO_PATH/$ODOO_USER.conf
EOL
gum log -t timeonly -l info 'Setting up Odoo Configuration File...'
sudo cat >> $ODOO_PATH/$ODOO_USER.conf <<EOL
[options]
admin_passwd = $MASTER_PASS
db_host = False
db_port = False
db_user = $ODOO_USER
db_password = False
http_port = $ODOO_PORT
logfile = $ODOO_PATH/$ODOO_USER.log
EOL
if [ $IS_ENTERPRISE = 'True' ]; then
    sudo -u ${ODOO_USER} bash -c 'printf ''addons_path=${ODOO_PATH}/enterprise,${ODOO_PATH}/odoo/addons,${ODOO_PATH}/custom-addons\n'' >> $ODOO_PATH/$ODOO_USER.conf'
else
    sudo -u ${ODOO_USER} bash -c 'printf ''addons_path=${ODOO_PATH}/odoo/addons,${ODOO_PATH}/custom-addons\n'' >> $ODOO_PATH/$ODOO_USER.conf'
fi
"
  # Creating Odoo Systemd Service
print_header "########## Creating Odoo Systemd Service ##########"
gum spin --spinner dot --show-output --title "Creating service..." -- bash -c "
gum log -t timeonly -l info 'Creating systemd service file...'
cat > /etc/systemd/system/$ODOO_USER.service <<EOL
[Unit]
Description=Odoo $ODOO_VERSION
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$ODOO_USER
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_PATH/odoo/odoo-bin -c $ODOO_PATH/$ODOO_USER.conf --logfile $ODOO_PATH/$ODOO_USER.log
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOL
"

gum log -t timeonly -l info "Created systemd service file at /etc/systemd/system/$ODOO_USER.service"
cat /etc/systemd/system/$ODOO_USER.service

  # Starting and Enabling Odoo Service
print_header "########## Starting and Enabling Odoo Service ##########"
gum log -t timeonly -l info "Starting and enabling Odoo service..."
gum spin --spinner dot --show-output --title "Starting service..." -- bash -c "
sudo systemctl daemon-reload
gum log -t timeonly -l info 'Starting Odoo Service...'
sudo systemctl start $ODOO_USER
gum log -t timeonly -l info 'Enabling Odoo Service...'
sudo systemctl enable $ODOO_USER
"

#--------------------------------------------------
# Dumping Info
#--------------------------------------------------
gum style --foreground 51 --border-foreground 51 --border double --align center --width 90 --margin "1 2" --padding "2 4" "
=========================================================================
########## Installation Complete!! ##########

Link: http://$(hostname -I | awk '{print $1}'):$ODOO_PORT
User (Linux & PostgreSQL): $ODOO_USER
Service Location: /etc/systemd/system/$ODOO_USER.service
Odoo location: $ODOO_PATH
Custom addons folder: $ODOO_PATH/custom-addons
Superadmin Password: $MASTER_PASS

========================================================================="

print_header "########## To Restart Odoo service ##########"
gum style --foreground 14 "Restart Odoo service: sudo systemctl restart $ODOO_USER"

print_header "########## To Install ohmyzsh on Odoo user ;) ##########"
gum style --foreground 14 "sh -c '\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'"

print_header "########## To Tail Odoo Log File ##########"
gum style --foreground 14 "use: tail -f -n 50 $ODOO_PATH/$ODOO_USER.log"

gum log -t timeonly -l info "Installation Completed!"
