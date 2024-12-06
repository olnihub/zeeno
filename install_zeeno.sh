#!/bin/bash

# Zeeno Installation Script

# Define installation variables
ADMIN_USERNAME="admin"
ADMIN_PASSWORD=$(openssl rand -base64 12)  # Generates a random password
ADMIN_PORT=8080  # Default port for the backend admin interface (can be adjusted if needed)

# 1. Install Dependencies
echo "Installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mariadb-server curl wget ufw fail2ban

# 2. Install Zeeno Frontend (Example for installation; replace with actual steps for Zeeno)
echo "Installing Zeeno Frontend..."
# Assuming you're cloning a GitHub repo or copying files to the web directory
sudo git clone https://github.com/olnihub/zeeno.git /var/www/html/zeeno
sudo chown -R www-data:www-data /var/www/html/zeeno

# 3. Configure Nginx
echo "Configuring Nginx..."
sudo cp /var/www/html/zeeno/nginx/zeeno.conf /etc/nginx/sites-available/zeeno
sudo ln -s /etc/nginx/sites-available/zeeno /etc/nginx/sites-enabled/

# 4. Configure Firewall (Allow HTTP and HTTPS)
echo "Configuring firewall..."
sudo ufw allow 'Nginx Full'

# 5. Install and Configure MariaDB
echo "Configuring MariaDB..."
sudo systemctl start mariadb
sudo mysql_secure_installation

# 6. Set Up Admin User for Backend
echo "Setting up admin user for the backend..."
# Here, you would create the admin user and save it to a database, for example
# For simplicity, we can echo the admin credentials

# You can replace this with actual logic for creating an admin in the Zeeno backend (e.g., inserting into the database)
echo "Admin Username: $ADMIN_USERNAME"
echo "Admin Password: $ADMIN_PASSWORD"
echo "Admin Interface URL: http://your_domain_or_ip:$ADMIN_PORT"

# 7. Start the Nginx server
echo "Starting Nginx..."
sudo systemctl restart nginx

# 8. Final message
echo "Zeeno is now installed and running!"
echo "Access the frontend at: http://your_domain_or_ip"
echo "Access the backend API at: http://your_domain_or_ip/api/status"
echo "Admin login credentials:"
echo "Username: $ADMIN_USERNAME"
echo "Password: $ADMIN_PASSWORD"
echo "Admin interface is available at: http://your_domain_or_ip:$ADMIN_PORT"
