#!/bin/bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Updating system..."
apt update && apt upgrade -y

echo "Installing essential packages..."
apt install -y sudo curl wget gnupg lsb-release unzip vim ufw fail2ban git

# Install Nginx, MariaDB, and PHP
echo "Installing Nginx, MariaDB, and PHP..."
apt install -y nginx mariadb-server mariadb-client php-fpm php-mysql php-cli php-xml php-mbstring php-curl php-zip

# Install and configure UFW firewall
echo "Configuring firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# Install Fail2Ban for security
echo "Installing Fail2Ban..."
apt install -y fail2ban
systemctl enable fail2ban

# Install SSL (Let's Encrypt)
echo "Installing Let's Encrypt SSL..."
apt install -y certbot python3-certbot-nginx

# Start and enable Nginx and MariaDB
systemctl start nginx
systemctl enable nginx
systemctl start mariadb
systemctl enable mariadb

# Securing MariaDB
echo "Securing MariaDB..."
mysql_secure_installation

# Install Node.js and other necessary software (for Zeeno panel)
echo "Installing Node.js and dependencies..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs npm

# Clone Zeeno Web Control Panel repository
echo "Cloning Zeeno control panel repository..."
cd /opt
git clone https://github.com/zeeno/zeeno.git

# Go into the Zeeno directory
cd zeeno

# Install Node.js dependencies for Zeeno panel
echo "Installing Zeeno panel dependencies..."
npm install

# Set up Zeeno web server (start it in background)
echo "Starting Zeeno web control panel..."
nohup npm start &

# Create a sample website for testing
echo "Setting up a sample website..."
DOMAIN="example.com"
ROOT_DIR="/var/www/$DOMAIN"
mkdir -p $ROOT_DIR
echo "Welcome to $DOMAIN" > $ROOT_DIR/index.html

# Nginx config for the new site
cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $ROOT_DIR;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Enable site and reload Nginx
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "Zeeno is now installed and running!"
echo "Access the frontend at http://your_domain_or_ip"
echo "Backend API is available at http://your_domain_or_ip/api/status"
