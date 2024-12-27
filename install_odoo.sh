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
BOLD="\e[1m"
RESET="\e[0m"

# Default values
ODOO_VERSION=""
MASTER_PASS=""
IS_ENTERPRISE="False"
# Function to print usage information
usage() {
  echo "Usage: $0 -v <Odoo_version> -p <Master_Password> [--enterprise]"
  echo "  -v, --version        Odoo version (e.g., 18.0)"
  echo "  -p, --password       Master password for Odoo"
  echo "  --enterprise         If specified, install Odoo Enterprise Edition"
  echo "  -h, --help           Show this help message"
  exit 1
}
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

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -v|--version)
      ODOO_VERSION="$2"
      shift 2
      ;;
    -p|--password)
      MASTER_PASS="$2"
      shift 2
      ;;
    --enterprise)
      IS_ENTERPRISE="True"
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
# Function to prompt for missing values
ask_for_missing_values() {
  if [ -z "$ODOO_VERSION" ]; then
    read -p "Odoo version (e.g., 18.0): " ODOO_VERSION
  fi
  if [ -z "$MASTER_PASS" ]; then
    read -sp "Master password: " MASTER_PASS
    echo  # To move to the next line after the password input
  fi
}
# Check if required arguments are provided, else prompt for them
if [ -z "$ODOO_VERSION" ] || [ -z "$MASTER_PASS" ]; then
  ask_for_missing_values
fi

ODOO_USER="odoo${ODOO_VERSION%%.*}"  # Convert version '18.0' to 'odoo18'
ODOO_PATH="/opt/$ODOO_USER"
echo odoo version: $ODOO_VERSION
echo odoo user: $ODOO_USER
echo odoo path: $ODOO_PATH

echo -e "\n${BOLD}${BLUE}################# Starting Installation of Odoo Version $ODOO_VERSION #################${RESET}\n"

echo -e "\n${CYAN}################# Creating Odoo User #################${RESET}\n"
sleep 0.5
sudo useradd -m -U -r -d "$ODOO_PATH" -s /bin/bash $ODOO_USER
echo "$ODOO_USER:$MASTER_PASS" | sudo chpasswd
sudo usermod -aG sudo $ODOO_USER

#--------------------------------------------------
# Install APT Dependencies
#--------------------------------------------------
echo -e "\n${CYAN}################# Updating System and Installing Prerequisites #################${RESET}\n"
sudo apt-get update && sudo apt-get upgrade -y
# python deps stopped for now
# sudo apt-get install -y python3 python3-cffi python3-dev python3-pip python3-setuptools python3-venv python3-wheel
sudo apt-get install -y curl wget gdebi libxml2-dev libxslt-dev zlib1g-dev libxrender1 libzip-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev
sudo apt install -y xfonts-75dpi xfonts-encodings xfonts-utils xfonts-base fontconfig

#--------------------------------------------------
# Install Node Dependencies
#--------------------------------------------------
echo -e "\n${CYAN}################# Installing Node.js, npm, and Less #################${RESET}\n"
sleep 0.5
sudo apt-get install -y npm nodejs
sudo ln -s /usr/bin/nodejs /usr/bin/node || true
sudo npm install -g less less-plugin-clean-css rtlcss node-gyp
sudo apt-get install -y node-less
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
    echo -e "${YELLOW}Installing wkhtmltopdf...${RESET}"
    cd /tmp
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    sudo gdebi -n wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin/ || true
    sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin/ || true
    rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi
#--------------------------------------------------
# Install PostgresSQL
#--------------------------------------------------
echo -e "\n${CYAN}################# Installing PostgreSQL #################${RESET}\n"
sleep 0.5
sudo apt-get install -y postgresql postgresql-client
sudo systemctl start postgresql && sudo systemctl enable postgresql
sudo systemctl status postgresql
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

set +e
if [ $IS_ENTERPRISE = "True" ]; then
    GITHUB_RESPONSE=$(sudo -u ${ODOO_USER} git clone https://www.github.com/odoo/enterprise --depth 1 --branch $ODOO_VERSION --single-branch 2>&1)
    echo $GITHUB_RESPONSE
    if [[ $GITHUB_RESPONSE == *"Authentication"* ]]; then
        echo -e "${RED}Error: Your authentication with Github has failed!${RESET}"
        echo -e "${YELLOW}In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.${RESET}"
        echo -e "${YELLOW}Continuing installation without enterprise...${RESET}"
        IS_ENTERPRISE="False"
    fi
else
    echo -e "${RED}Error: Your authentication with Github has failed!${RESET}"
    echo "Skipping Odoo Enterprise setup."
fi
set -e

  # Running odoo script
echo -e "\n${CYAN}################# Installing Odoo Dependencies (running odoo's debinstall script) #################${RESET}\n"
sleep 0.5
sudo $ODOO_PATH/odoo/setup/debinstall.sh
  
  # Creating Odoo dirs and files
echo -e "\n${CYAN}################# Setting Up The Odoo Directory #################${RESET}\n"
sleep 0.5
sudo -u $ODOO_USER bash <<EOF
cd $ODOO_PATH
mkdir -p $ODOO_PATH/custom-addons
touch $ODOO_PATH/$ODOO_USER.log
cat > $ODOO_PATH/$ODOO_USER.conf <<EOL
[options]
admin_passwd = $MASTER_PASS
db_host = False
db_port = False
db_user = $ODOO_USER
db_password = False
http_port = 80${ODOO_VERSION%%.*}
logfile = $ODOO_PATH/$ODOO_USER.log
addons_path =$ODOO_PATH/odoo/addons,$ODOO_PATH/custom-addons
EOL
EOF
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

  # Starting and Enabling Odoo Service
echo -e "\n${CYAN}################# Starting and Enabling Odoo Service #################${RESET}\n"
sleep 0.5
sudo systemctl daemon-reload
sudo systemctl start $ODOO_USER
sudo systemctl enable $ODOO_USER

#--------------------------------------------------
# Dumping Info
#--------------------------------------------------
echo "\n========================================================================="
echo -e "\n${CYAN}################# Done! The Odoo server is up and running. Specifications: #################${RESET}\n"
sudo systemctl status $ODOO_USER
echo "Port: 80${ODOO_VERSION%%.*}"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $ODOO_PATH"
echo "Addons folder: $ODOO_PATH/custom-addons"
echo "Password superadmin (database): $MASTER_PASS"
echo -e "\n========================================================================="

echo -e "\n${GREEN}################# To Restart Odoo service #################${RESET}\n"
echo "\nRestart Odoo service: sudo systemctl restart $OE_USER \n"
echo -e "\n${GREEN}################# To Install Zsh #################${RESET}\n"
echo "sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo -e "\n${GREEN}################# To Tail Odoo Log File #################${RESET}\n"
echo -e "\n use: tail -f -n 50 $ODOO_PATH/$ODOO_USER.log\n"