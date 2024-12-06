#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Detect Ubuntu/Debian version
function detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION
    else
        echo "Unsupported OS"
        exit 1
    fi
}

# Run OS detection
detect_os

# Check if the OS is Ubuntu or Debian
if [[ $OS_NAME == "Ubuntu" || $OS_NAME == "Debian" ]]; then
    PACKAGE_MANAGER="apt"
    INSTALL_CMD="apt install -y"
else
    echo "This script only supports Ubuntu and Debian systems."
    exit 1
fi

# Define some basic variables
DOMAIN="yourdomain.com"
ADMIN_EMAIL="admin@yourdomain.com"
ADMIN_USER="admin"
PANEL_PORT="8080"
BACKUP_DIR="/opt/zeeno/backups"

# Update system
echo "Updating system packages..."
$INSTALL_CMD update -y && $INSTALL_CMD upgrade -y

# Install essential packages
echo "Installing essential packages..."
$INSTALL_CMD curl wget gnupg lsb-release unzip vim ufw fail2ban git

# Install Nginx, MariaDB, and PHP
echo "Installing Nginx, MariaDB, and PHP..."
$INSTALL_CMD nginx mariadb-server mariadb-client php-fpm php-mysql php-cli php-xml php-mbstring php-curl php-zip

# Install Certbot for Let's Encrypt SSL
echo "Installing Let's Encrypt SSL..."
$INSTALL_CMD certbot python3-certbot-nginx

# Install firewall (UFW) and configure it
echo "Configuring firewall..."
$INSTALL_CMD ufw
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# Enable Fail2Ban
echo "Installing and enabling Fail2Ban..."
$INSTALL_CMD fail2ban
systemctl enable fail2ban

# Function to set up a custom login URL
echo "Please enter a custom login URL slug (e.g., '/adminlogin')"
read CUSTOM_LOGIN_URL

# Create a basic authentication setup for the login URL
echo "Creating a custom login page at: /var/www/html$CUSTOM_LOGIN_URL"
mkdir -p /var/www/html$CUSTOM_LOGIN_URL
echo "<html><body><h1>Welcome to Zeeno Admin Panel</h1></body></html>" > /var/www/html$CUSTOM_LOGIN_URL/index.html

# Configure Nginx to point to the new login URL
echo "Configuring Nginx for custom login URL..."
cat <<EOL > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        root /var/www/html;
        index index.html;
    }
    
    location $CUSTOM_LOGIN_URL {
        root /var/www/html;
        index index.html;
    }
    
    location /admin {
        proxy_pass http://127.0.0.1:$PANEL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Test Nginx configuration and reload
echo "Testing Nginx configuration..."
nginx -t
systemctl restart nginx

# Start and secure MariaDB
echo "Starting MariaDB and securing installation..."
systemctl start mariadb
mysql_secure_installation

# Set up the Zeeno Admin panel (assumed to be a simple PHP app)
echo "Setting up the Zeeno Admin Panel..."
git clone https://github.com/olnihub/zeeno.git /opt/zeeno
cd /opt/zeeno

# Install any dependencies (e.g., PHP packages)
composer install

# Set up database and user
echo "Creating database and user for Zeeno..."
mysql -e "CREATE DATABASE zeeno_db;"
mysql -e "CREATE USER 'zeeno_user'@'localhost' IDENTIFIED BY 'securepassword';"
mysql -e "GRANT ALL PRIVILEGES ON zeeno_db.* TO 'zeeno_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Set up a cron job for backup every 24 hours
echo "Setting up cron job for backups..."
echo "0 0 * * * root /opt/zeeno/backup.sh" > /etc/cron.d/zeeno-backup

# Set up the 2FA
echo "Setting up 2FA for admin user..."
# Placeholder: assuming the system uses Google Authenticator
$INSTALL_CMD libpam-google-authenticator

# Enable 2FA for the admin
echo "Enable 2FA for the admin user by running 'google-authenticator' command as admin."

# Setup backup management
echo "Setting up backup management script..."
mkdir -p $BACKUP_DIR
cat <<EOL > /opt/zeeno/backup.sh
#!/bin/bash
tar -czf $BACKUP_DIR/zeeno_backup_$(date +%F).tar.gz /opt/zeeno
EOL
chmod +x /opt/zeeno/backup.sh

# Install additional features (such as Panel Replication, Restore, and Cloning)
echo "Installing Panel Replication and Cloning features..."
git clone https://github.com/olnihub/zeeno-features.git /opt/zeeno-features
# Placeholder for panel replication and cloning

# Enable automatic updates for Zeeno
echo "Enabling automatic updates for Zeeno..."
cat <<EOL > /etc/cron.d/zeeno-updates
0 0 * * 0 root git -C /opt/zeeno pull
EOL

# Set up additional features as needed, such as resource limits, Docker reverse proxy, etc.

# Final notes
echo "Zeeno is installed! Access the admin panel at http://$DOMAIN$CUSTOM_LOGIN_URL or http://$DOMAIN:$PANEL_PORT."
echo "Admin username: $ADMIN_USER"
echo "Admin password: [Generated Password]"

