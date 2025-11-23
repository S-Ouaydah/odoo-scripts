#!/bin/bash

# Odoo Installer for Ubuntu Servers with the ability to handle multiple Odoo Intances
# wget https://raw.githubusercontent.com/S-Ouaydah/odoo-scripts/refs/heads/fancy_gum/odoo-install.sh && chmod +x odoo-install.sh && ./odoo-install.sh
set -e  # Exit immediately on error
trap "gum log -t timeonly -l warn '⚠️ Exiting script...'; exit 1" SIGINT

# Define variables
VERBOSE="False"
COPY_SSH="False"
OM_ACCOUNTING="False"
CYBRO_ACCOUNTING="False"
CONFIG_FILE="/etc/odoo-scripts.conf"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ODOO_BASE_DIR="/opt"
fi

usage() {
  echo "Usage: $0 --[verbose]"
  echo "  --verbose            Show more logs"
  echo "  --copy-ssh           Copy SSH Configs from another server"
  echo "  -h, --help           Show this help message"
  exit 1
}
# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE="True"
      shift
      ;;
    --copy-ssh)
      COPY_SSH="True"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done
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
  echo "$prompt:$(gum style --foreground 5 --bold "$result")"
}

print_header() {
    local text="$1"
    echo -e "\n$(gum style --foreground 3 --border-foreground 5 --border double --align center --width 90 --margin "1 2" --padding "2 4" "$text")\n"
}

print_header "########## Installation of Odoo Version $ODOO_VERSION ##########"

gum log -t timeonly -l info "🚀 Installation Started\!"
# copying is easier than a new ssh for now
if [ $COPY_SSH = "True" ]; then
  gum log -t timeonly -l info "🔗 Copying SSH Configs..."
  scp -r root@$(gum input --prompt="Enter the IP of the server you want to copy from: "):/root/.ssh/* /root/.ssh
  if [ $? -eq 0 ]; then
    gum log -t timeonly -l info "✅ SSH Configs Copied\!"
  else
    gum log -t timeonly -l error "❌ Error: It seems SSH Configs not copied\!"
    exit 1
  fi
fi
if gum confirm "Do you want to install Enterprise version?" --default=false; then
  IS_ENTERPRISE="True"
else
  IS_ENTERPRISE="False"
  if gum confirm "Do you want to install Odoo Mates Accounting?" --default=false; then
    OM_ACCOUNTING="True"
  else
    OM_ACCOUNTING="False"
  fi
  if gum confirm "Do you want to install Cybro Accounting?" --default=false; then
    CYBRO_ACCOUNTING="True"
  else
    CYBRO_ACCOUNTING="False"
  fi
fi

echo "Is Enterprise:$(gum style --foreground 5 --bold "$IS_ENTERPRISE")"

ODOO_VERSION=$(gum choose "19.0" "18.0" "17.0" "16.0" "15.0" --header="Choose Odoo Version:")
echo "Odoo Version:$(gum style --foreground 5 --bold "$ODOO_VERSION")"

ask_question "Master Password" "masteradmin" "MASTER_PASS"
ask_question "Odoo Port" "80${ODOO_VERSION%%.*}" "ODOO_PORT"
ODOO_USER="odoo${ODOO_VERSION%%.*}"
# ask_question "Odoo User" "odoo${ODOO_VERSION%%.*}" "ODOO_USER"
ask_question "Odoo Path" "$ODOO_BASE_DIR/$ODOO_USER" "ODOO_PATH"

# Check if user already exists
if id "$ODOO_USER" &>/dev/null; then
    gum log -t timeonly -l error "❌ User $ODOO_USER already exists\!"
    exit 1
fi

# Check if port is already in use
if sudo lsof -i :$ODOO_PORT > /dev/null 2>&1; then
    gum log -t timeonly -l error "❌ Port $ODOO_PORT is already in use\!"
    exit 1
fi

print_header "########## Creating Odoo User ##########"
sudo useradd -m -U -r -d "$ODOO_PATH" -s /bin/zsh "$ODOO_USER"
gum log -t timeonly -l info "👤 User $ODOO_USER created at $ODOO_PATH"
echo "$ODOO_USER:$MASTER_PASS" | sudo chpasswd
sudo usermod -aG sudo "$ODOO_USER"
gum log -t timeonly -l info "🔑 User $ODOO_USER added to sudo group with password $MASTER_PASS"

#--------------------------------------------------
# Install APT Dependencies
#--------------------------------------------------
print_header "########## Updating System and Installing Prerequisites ##########"
gum spin --spinner dot --title "Updating system..." "$([[ "$VERBOSE" == "true" ]] && echo --show-output || echo --show-error)" -- bash -c "
gum log -t timeonly -l info '🔄 Running apt-upgrade...'
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
# python deps stopped for now
sudo apt-get install -y 
gum log -t timeonly -l info '📦 apt install packages...'
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3  python3-pip python3-setuptools python3-venv python3-wheel\
      curl wget gdebi libxml2-dev libxslt-dev zlib1g-dev libxrender1 libzip-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev\
      xfonts-75dpi xfonts-encodings xfonts-utils xfonts-base fontconfig\
      fonts-dejavu-core fonts-noto-core fonts-inconsolata fonts-font-awesome fonts-roboto-unhinted\
      npm nodejs node-less\
      postgresql postgresql-client
  "

#--------------------------------------------------
# Install Node Dependencies
#--------------------------------------------------
print_header "########## Installing Node.js, npm, and Less ##########"
# Check if Node.js is already installed
if command -v node >/dev/null 2>&1; then
    gum log -t timeonly -l info '✅ Node.js is already installed' --message.foreground 2
else
    # sudo apt-get install -y npm nodejs node-less
    gum log -t timeonly -l info '🔗 Linking nodejs...'
    sudo ln -s /usr/bin/nodejs /usr/bin/node || true
fi
gum spin --spinner dot --title "Installing Node.js..." "$([[ "$VERBOSE" == "true" ]] && echo --show-output || echo --show-error)" -- bash -c "
gum log -t timeonly -l info '📦 Installing npm packages...'
sudo npm install -g less less-plugin-clean-css rtlcss node-gyp
"

#--------------------------------------------------
# Install WKHTMLTOPDF
#--------------------------------------------------
print_header "########## Installing wkhtmltopdf ##########"
# Check if wkhtmltopdf is already installed
if command -v wkhtmltopdf >/dev/null 2>&1; then
    gum log -t timeonly -l info "✅ wkhtmltopdf is already installed" --message.foreground 2
else
    gum log -t timeonly -l info "📥 Installing wkhtmltopdf..."
    cd /tmp
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    sudo gdebi -n wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    gum log -t timeonly -l info "🔗 Creating Links..."
    sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin/ || true
    sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin/ || true
    gum log -t timeonly -l info "🧹 Cleaning up..."
    rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi

#--------------------------------------------------
# Install PostgresSQL
#--------------------------------------------------
print_header "########## Installing PostgreSQL ##########"
# Check if PostgreSQL is already installed
if command -v psql >/dev/null 2>&1; then
    gum log -t timeonly -l info "✅ PostgreSQL is already installed" --message.foreground 2
else
    # sudo apt-get install -y postgresql postgresql-client
    sudo systemctl start postgresql && sudo systemctl enable postgresql
fi
sudo systemctl status postgresql
gum log -t timeonly -l info "🔧 Creating PostgreSQL User..."
cd /tmp && sudo -u postgres createuser -d -R -s $ODOO_USER
cd ~
# sudo -u postgres createdb $ODOO_USER

#--------------------------------------------------
# Setting Up Odoo
#--------------------------------------------------
  # Cloning source
print_header "########## Cloning Odoo Source Code ##########"
cd $ODOO_PATH
gum spin --spinner dot --title "Cloning Odoo..." "$([[ "$VERBOSE" == "true" ]] && echo --show-output || echo --show-error)" -- bash -c "
sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/odoo --depth 1 --branch $ODOO_VERSION --single-branch
"
gum log -t timeonly -l info "✅ Odoo Community Cloned..." --message.foreground 2
print_header "########## Creating Virtual Environment ##########"
gum log -t timeonly -l info "🔧 Creating virtual environment..."
sudo -u $ODOO_USER python3 -m venv $ODOO_PATH/venv
gum log -t timeonly -l info "📦 Installing Python dependencies..."
sudo -u $ODOO_USER $ODOO_PATH/venv/bin/pip install -r $ODOO_PATH/odoo/requirements.txt
set +e

if [ $IS_ENTERPRISE = "True" ]; then
    GITHUB_RESPONSE=$(sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/enterprise --depth 1 --branch $ODOO_VERSION --single-branch 2>&1)
    echo $GITHUB_RESPONSE
    if [[ $GITHUB_RESPONSE == *"Authentication"* ]]; then
        gum log -t timeonly -l error "❌ Error: Your authentication with Github has failed\!" --message.foreground 1
        gum log -t timeonly -l info "ℹ️ In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise." --message.foreground 3
        gum log -t timeonly -l info "🔄 Continuing installation without enterprise..."
        IS_ENTERPRISE="False"
    else
      gum log -t timeonly -l error "❌ Error: Your authentication with Github has failed\!" --message.foreground 1
      gum log -t timeonly -l info "🔄 Continuing installation without enterprise..."
    fi
else
    gum log -t timeonly -l info "ℹ️ This is only the community setup, skipping enterprise." --message.foreground 3
fi
set -e

  # Running odoo script
print_header "########## Installing Odoo Dependencies ##########"
gum log -t timeonly -l info "🔧 Running Odoo's debinstall script..."
gum spin --spinner dot --title "Installing dependencies..." "$([[ "$VERBOSE" == "true" ]] && echo --show-output || echo --show-error)" -- bash -c "
sudo $ODOO_PATH/odoo/setup/debinstall.sh
"
  
  # Creating Odoo dirs and files
print_header "########## Setting Up The Odoo Directory ##########"
gum log -t timeonly -l info "📁 Setting up Custom Addons Directory..."
sudo -u $ODOO_USER bash <<EOL
cd $ODOO_PATH
mkdir -p $ODOO_PATH/custom-addons
if [ "$OM_ACCOUNTING" = "True" ]; then
    cd $ODOO_PATH/custom-addons
    git clone https://github.com/odoomates/odooapps.git --depth 1 --single-branch --branch $ODOO_VERSION $ODOO_PATH/custom-addons/odoomates_accounting
fi
if [ "$CYBRO_ACCOUNTING" = "True" ]; then
    cd $ODOO_PATH/custom-addons
    git clone https://github.com/supportbntech/full_accounting_kit.git --depth 1 --single-branch --branch $ODOO_VERSION $ODOO_PATH/custom-addons/cybo_accounting_kit
fi
gum log -t timeonly -l info "📝 Setting up Log File..."
touch $ODOO_PATH/$ODOO_USER.log
touch $ODOO_PATH/$ODOO_USER.conf
EOL
gum log -t timeonly -l info '⚙️ Setting up Odoo Configuration File...'
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
if [ "$IS_ENTERPRISE" = "True" ]; then
    sudo -u "$ODOO_USER" bash -c "printf 'addons_path=${ODOO_PATH}/enterprise,${ODOO_PATH}/odoo/addons,${ODOO_PATH}/custom-addons' >> ${ODOO_PATH}/${ODOO_USER}.conf"
else
    sudo -u "$ODOO_USER" bash -c "printf 'addons_path=${ODOO_PATH}/odoo/addons,${ODOO_PATH}/custom-addons' >> ${ODOO_PATH}/${ODOO_USER}.conf"
fi
if [ "$OM_ACCOUNTING" = "True" ]; then
    sudo -u "$ODOO_USER" bash -c "printf ',${ODOO_PATH}/custom-addons/odoomates_accounting' >> ${ODOO_PATH}/${ODOO_USER}.conf"
fi
if [ "$CYBRO_ACCOUNTING" = "True" ]; then
    sudo -u "$ODOO_USER" bash -c "printf ',${ODOO_PATH}/custom-addons/cybo_accounting_kit' >> ${ODOO_PATH}/${ODOO_USER}.conf"
fi
gum log -t timeonly -l info "✅ Odoo Configuration File created at $ODOO_PATH/$ODOO_USER.conf"
cat $ODOO_PATH/$ODOO_USER.conf

# Creating Odoo Systemd Service
print_header "########## Creating Odoo Systemd Service ##########"

gum log -t timeonly -l info "⚙️ Creating systemd service file..."
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
ExecStart=$ODOO_PATH/venv/bin/python $ODOO_PATH/odoo/odoo-bin -c $ODOO_PATH/$ODOO_USER.conf --logfile $ODOO_PATH/$ODOO_USER.log
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOL


gum log -t timeonly -l info "✅ Created systemd service file at /etc/systemd/system/$ODOO_USER.service"
cat /etc/systemd/system/$ODOO_USER.service

# Starting and Enabling Odoo Service
print_header "########## Starting and Enabling Odoo Service ##########"
gum log -t timeonly -l info "🔄 Starting and enabling Odoo service..."
sudo systemctl daemon-reload
gum log -t timeonly -l info "▶️ Starting Odoo Service..."
sudo systemctl start $ODOO_USER
gum log -t timeonly -l info "🔧 Enabling Odoo Service..."
sudo systemctl enable $ODOO_USER

#--------------------------------------------------
# Dumping Info
#--------------------------------------------------
INST_DETAILS="
=========================================================================
########## Installation Complete! ##########

* Link: http://$(hostname -I | awk '{print $1}'):$ODOO_PORT
* User (Linux & PostgreSQL): $ODOO_USER  
* Service Location: /etc/systemd/system/$ODOO_USER.service
* Odoo Location: $ODOO_PATH
* Custom addons folder: $ODOO_PATH/custom-addons
* Odoo Log File: $ODOO_PATH/$ODOO_USER.log
* Odoo Configuration File: $ODOO_PATH/$ODOO_USER.conf
* Superadmin Password: $MASTER_PASS

  To Restart Odoo service
### sudo systemctl restart $ODOO_USER.service

  To Tail Odoo Log File
### tail -f -n 50 $ODOO_PATH/$ODOO_USER.log
=========================================================================
"

gum style --foreground 3 --border-foreground 4 --border double --align left --width 90 --margin "1 2" --padding "2 4" "$(gum format -- "$INST_DETAILS")"

# save the info
touch /opt/$ODOO_USER/server_info.txt
touch /opt/$ODOO_USER/loc.txt
echo "$INST_DETAILS" >>  /opt/$ODOO_USER/server_info.txt
echo "$ODOO_PATH" >>  /opt/$ODOO_USER/loc.txt

gum log -t timeonly -l info "🎉 Installation Completed 🎉" --message.foreground 3
