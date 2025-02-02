#!/bin/bash

# Odoo Installer for Ubuntu Servers with the ability to handle multiple Odoo Intances
# Usage: source install_odoo_slomax.sh -v <Odoo_version> -p <Master_Password> [--enterprise]
# Example: source install_odoo_slomax.sh -v 18.0 -p YourStrongPassword --enterprise
set -e  # Exit immediately on error

# Define color variables
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
GREY="\e[38;5;248m"
BOLD="\e[1m"
RESET="\e[0m"

# Check if Zsh is installed
if ! command -v zsh >/dev/null 2>&1; then
  echo -e "${YELLOW}Zsh is not installed on your system.${RESET}"
  read -p "Do you want to install Zsh? (y/n): " install_zsh
  if [[ "$install_zsh" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Installing Zsh...${RESET}"
    # sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y zsh
    echo -e "\n${CYAN}################# Installing Oh-My-Zsh #################${RESET}\n"
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
    echo -e "${GREEN}Oh-My-Zsh has been installed. Please run the script again to continue with Odoo installation.${RESET}"
    exit 0
  else
    echo -e "${RESET}I WONT ACCEPT NO FOR AN ANSWER!${RED}"
    exit 0
  fi
fi

# Get values
ask_question() {
  local prompt="$1"
  local default_value="$2"
  local var_name="$3"
  
  # Display prompt in color
  echo -n -e "$prompt ${GREY}(${default_value})${RESET} "
  read $var_name
  # If input is empty, set to default value
  eval $var_name=\${$var_name:-$default_value}
  
  # Clear the line where the prompt was and display choice
  tput cuu1
  tput el
  local display_value=${!var_name}
  echo -e "$prompt: ${GREEN}${display_value}${RESET}"  
  tput el
}

echo -e "\n${BOLD}${BLUE}################# Installation of Odoo Version $ODOO_VERSION #################${RESET}\n"

ask_question "Enterprise" "False" IS_ENTERPRISE
ask_question "Master Password:" "masteradmin" MASTER_PASS
ask_question "Odoo Version:" "18.0" ODOO_VERSION
ask_question "Odoo Port:" "80${ODOO_VERSION%%.*}" ODOO_PORT
ask_question "Odoo User:" "odoo${ODOO_VERSION%%.*}" ODOO_USER
ask_question "Odoo Path:" "/opt/$ODOO_USER" ODOO_PATH

# Check if user already exists
if id "$ODOO_USER" &>/dev/null; then
    echo -e "${RED}User $ODOO_USER already exists!${RESET}"
    exit 1
fi
# Check if port is already in use
if sudo lsof -i :$ODOO_PORT > /dev/null 2>&1; then
    echo -e "${RED}Port $ODOO_PORT is already in use!${RESET}"
    exit 1
fi

echo -e "\n${CYAN}################# Creating Odoo User #################${RESET}\n"
sleep 0.5
sudo useradd -m -U -r -d "$ODOO_PATH" -s /bin/bash $ODOO_USER
echo -e "\n${GREY} user $ODOO_USER created at $ODOO_PATH ${RESET}\n"
echo "$ODOO_USER:$MASTER_PASS" | sudo chpasswd
sudo usermod -aG sudo $ODOO_USER
echo -e "\n${GREY} user $ODOO_USER added to sudo group with password $MASTER_PASS ${RESET}\n"

#--------------------------------------------------
# Install APT Dependencies
#--------------------------------------------------
echo -e "\n${CYAN}################# Updating System and Installing Prerequisites #################${RESET}\n"
sleep 0.5

sudo apt-get update && sudo apt-get upgrade -y
# python deps stopped for now
# sudo apt-get install -y python3 python3-cffi python3-dev python3-pip python3-setuptools python3-venv python3-wheel
sudo apt-get install -y curl wget gdebi libxml2-dev libxslt-dev zlib1g-dev libxrender1 libzip-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev xfonts-75dpi xfonts-encodings xfonts-utils xfonts-base fontconfig

#--------------------------------------------------
# Install Node Dependencies
#--------------------------------------------------
echo -e "\n${CYAN}################# Installing Node.js, npm, and Less #################${RESET}\n"
sleep 0.5
# Check if Node.js is already installed
if command -v node >/dev/null 2>&1; then
    echo -e "${GREEN}Node.js is already installed${RESET}"
else
    sudo apt-get install -y npm nodejs node-less
    sudo ln -s /usr/bin/nodejs /usr/bin/node || true
fi
sudo npm install -g less less-plugin-clean-css rtlcss node-gyp
sleep 0.5
#--------------------------------------------------
# Install WKHTMLTOPDF
#--------------------------------------------------
echo -e "\n${CYAN}################# Installing wkhtmltopdf #################${RESET}\n"
sleep 0.5

# Check if wkhtmltopdf is already installed
if command -v wkhtmltopdf >/dev/null 2>&1; then
    echo -e "${GREEN}wkhtmltopdf is already installed${RESET}"
else
    echo -e "${GREY}Installing wkhtmltopdf...${RESET}"
    cd /tmp
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    sudo gdebi -n wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    echo -e "${GREY}Creating Links...${RESET}"
    sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin/ || true
    sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin/ || true
    echo -e "${GREY}Cleaning up...${RESET}"
    rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi
#--------------------------------------------------
# Install PostgresSQL
#--------------------------------------------------
echo -e "\n${CYAN}################# Installing PostgreSQL #################${RESET}\n"
sleep 0.5
# Check if PostgreSQL is already installed
if command -v psql >/dev/null 2>&1; then
    echo -e "${GREEN}PostgreSQL is already installed${RESET}"
else
    sudo apt-get install -y postgresql postgresql-client
    sudo systemctl start postgresql && sudo systemctl enable postgresql
fi
sudo systemctl status postgresql
echo -e "${GREY}Creating PostgreSQL User...${RESET}"
sudo -u postgres createuser -d -R -s $ODOO_USER

# sudo -u postgres createdb $ODOO_USER

#--------------------------------------------------
# Setting Up Odoo
#--------------------------------------------------
  # Cloning source
echo -e "\n${CYAN}################# Cloning Odoo Source Code #################${RESET}\n"
sleep 0.5
cd $ODOO_PATH
sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/odoo --depth 1 --branch $ODOO_VERSION --single-branch
echo -e "${GREY}Odoo Community Cloned...${RESET}"

set +e
if [ $IS_ENTERPRISE = "True" ]; then
    GITHUB_RESPONSE=$(sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/enterprise --depth 1 --branch $ODOO_VERSION --single-branch 2>&1)
    echo $GITHUB_RESPONSE
    if [[ $GITHUB_RESPONSE == *"Authentication"* ]]; then
        echo -e "${RED}Error: Your authentication with Github has failed!${RESET}"
        echo -e "${YELLOW}In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.${RESET}"
        echo -e "${YELLOW}Continuing installation without enterprise...${RESET}"
        IS_ENTERPRISE="False"
    else
      echo -e "${RED}Error: Your authentication with Github has failed!${RESET}"
      echo "Continuing installation without enterprise..."
    fi
else
    echo -e "${YELLOW}This is only the community setup, skipping enterprise.${RESET}"
fi
set -e

  # Running odoo script
echo -e "\n${CYAN}################# Installing Odoo Dependencies #################${RESET}\n"
echo -e "${GREY}Running Odoo's debinstall script...${RESET}"
sudo $ODOO_PATH/odoo/setup/debinstall.sh
  
  # Creating Odoo dirs and files
echo -e "\n${CYAN}################# Setting Up The Odoo Directory #################${RESET}\n"
echo -e "${GREY}Setting up Custom Addons Directory...${RESET}"
echo -e "${GREY}Setting up Log File...${RESET}"
echo -e "${GREY}Setting up Odoo Configuration File...${RESET}"
sudo -u $ODOO_USER bash <<EOL
cd $ODOO_PATH
mkdir -p $ODOO_PATH/custom-addons
touch $ODOO_PATH/$ODOO_USER.log
touch $ODOO_PATH/$ODOO_USER.conf
EOL
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
if [ $IS_ENTERPRISE = "True" ]; then
    sudo -u ${ODOO_USER} bash -c "printf 'addons_path=${ODOO_PATH}/enterprise,${ODOO_PATH}/odoo/addons,${ODOO_PATH}/custom-addons\n' >> $ODOO_PATH/$ODOO_USER.conf"
else
    sudo -u ${ODOO_USER} bash -c "printf 'addons_path=${ODOO_PATH}/odoo/addons,${ODOO_PATH}/custom-addons\n' >> $ODOO_PATH/$ODOO_USER.conf"
fi
  # Creating Odoo Systemd Service
echo -e "\n${CYAN}################# Creating Odoo Systemd Service #################${RESET}\n"
sleep 0.5
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

echo -e "\n${GREY}Created systemd service file at /etc/systemd/system/$ODOO_USER.service:${RESET}"
cat /etc/systemd/system/$ODOO_USER.service


  # Starting and Enabling Odoo Service
echo -e "\n${CYAN}################# Starting and Enabling Odoo Service #################${RESET}\n"
sleep 0.5
sudo systemctl daemon-reload
echo -e "${GREY}Starting Odoo Service...${RESET}"
sudo systemctl start $ODOO_USER
echo -e "${GREY}Enabling Odoo Service...${RESET}"
sudo systemctl enable $ODOO_USER

#--------------------------------------------------
# Dumping Info
#--------------------------------------------------
echo "\n========================================================================="
sudo systemctl status $ODOO_USER
echo "\n========================================================================="
echo -e "\n${CYAN}################# Done! The Odoo server is running on port $ODOO_PORT #################${RESET}\n"
echo "Link: http://$(hostname -I | awk '{print $1}'):$ODOO_PORT"
echo "User (Linux & PostgreSQL): $ODOO_USER"
echo "Service Location: /etc/systemd/system/$ODOO_USER.service"
echo "Odoo location: $ODOO_PATH"
echo "Custom addons folder: $ODOO_PATH/custom-addons"
echo "Superadmin Password: $MASTER_PASS"
echo -e "\n========================================================================="
sleep 1.5

echo -e "\n${GREY}################# To Restart Odoo service #################${RESET}\n"
echo "\nRestart Odoo service: sudo systemctl restart $ODOO_USER \n"
echo -e "\n${GREY}################# To Install ohmyzsh on Odoo user ;) #################${RESET}\n"
echo "sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo -e "\n${GREY}################# To Tail Odoo Log File #################${RESET}\n"
echo -e "\n use: tail -f -n 50 $ODOO_PATH/$ODOO_USER.log\n"