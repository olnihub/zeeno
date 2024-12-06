#!/bin/bash

# Zeeno Complete Installation Script with GUI
# Compatible with Ubuntu 20.04+, Debian 10+

set -e

# Colors for messages
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"

function print_success() {
    echo -e "${GREEN}[SUCCESS]${ENDCOLOR} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${ENDCOLOR} $1"
}

function print_info() {
    echo -e "${CYAN}[INFO]${ENDCOLOR} $1"
}

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root."
    exit 1
fi

# Interactive prompts
echo "Welcome to the Zeeno installation script!"
echo "Please provide the following information to configure Zeeno:"

read -p "Enter the domain name for Zeeno (e.g., example.com): " DOMAIN
read -p "Enter your email address for SSL setup (e.g., admin@example.com): " EMAIL

# Confirmation prompt
echo -e "\n${CYAN}The installation will proceed with the following settings:${ENDCOLOR}"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
read -p "Is this correct? (y/n): " CONFIRM
if [[ $CONFIRM != "y" ]]; then
    print_error "Installation canceled by user."
    exit 1
fi

# Update System
echo "Updating system packages..."
apt update && apt upgrade -y
print_success "System updated."

# Install Dependencies
echo "Installing dependencies..."
apt install -y nginx mysql-server mariadb-server python3 python3-pip python3-venv \
    certbot python3-certbot-nginx git fail2ban ufw curl unzip
print_success "Dependencies installed."

# Configure UFW
echo "Configuring the firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
print_success "Firewall configured."

# Configure Fail2Ban
echo "Configuring Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban
print_success "Fail2Ban configured."

# Set up Zeeno Directory
APP_DIR="/opt/zeeno"
echo "Setting up Zeeno at $APP_DIR..."
mkdir -p $APP_DIR
cd $APP_DIR

# Clone Zeeno Project (Replace with actual GitHub repository)
echo "Downloading Zeeno files..."
git clone https://github.com/example/zeeno.git .  # Replace with actual repo
pip3 install -r requirements.txt
print_success "Zeeno files downloaded."

# Configure NGINX for Zeeno
echo "Configuring NGINX for Zeeno..."
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

cat > $NGINX_AVAILABLE/zeeno.conf <<EOL
server {
    listen 80;
    server_name $DOMAIN;
    root $APP_DIR;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL

ln -s $NGINX_AVAILABLE/zeeno.conf $NGINX_ENABLED/zeeno.conf
nginx -t && systemctl reload nginx
print_success "NGINX configured for Zeeno."

# Start Zeeno Backend
echo "Starting Zeeno backend..."
python3 -m venv venv
source venv/bin/activate
export FLASK_APP=app.py
nohup flask run --host=0.0.0.0 --port=5000 &>/dev/null &
deactivate
print_success "Zeeno backend started."

# Configure Certbot for SSL
echo "Configuring SSL with Let's Encrypt..."
certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
print_success "SSL configured for $DOMAIN."

# Create Flask Application (Backend API and GUI)
echo "Creating Flask Application..."
cat > $APP_DIR/app.py <<EOL
from flask import Flask, jsonify, request, render_template
import os
import subprocess
import psutil

app = Flask(__name__)

# Example API: System Status
@app.route("/api/status", methods=["GET"])
def system_status():
    return jsonify({
        "cpu_usage": psutil.cpu_percent(),
        "memory_usage": psutil.virtual_memory().percent,
        "disk_usage": psutil.disk_usage('/').percent,
        "load_avg": os.getloadavg()
    })

# Example API: Add Site
@app.route("/api/sites", methods=["POST"])
def add_site():
    data = request.json
    domain = data.get("domain")
    root = data.get("root", f"/var/www/{domain}")
    
    # Create NGINX config
    config = f"""
    server {{
        listen 80;
        server_name {domain};
        root {root};
        
        location / {{
            index index.html;
        }}
    }}
    """
    config_path = f"/etc/nginx/sites-available/{domain}.conf"
    with open(config_path, "w") as f:
        f.write(config)
    
    os.symlink(config_path, f"/etc/nginx/sites-enabled/{domain}.conf")
    subprocess.run(["nginx", "-t"])
    subprocess.run(["systemctl", "reload", "nginx"])

    # Create directory and index file
    os.makedirs(root, exist_ok=True)
    with open(os.path.join(root, "index.html"), "w") as f:
        f.write(f"<h1>Welcome to {domain}!</h1>")

    return jsonify({"status": "success", "message": f"Site {domain} created."})

# Example API: List Sites
@app.route("/api/sites", methods=["GET"])
def list_sites():
    sites = os.listdir("/etc/nginx/sites-available")
    return jsonify({"sites": sites})

# GUI Route
@app.route("/")
def index():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOL

# Create Frontend (HTML)
echo "Creating Frontend (HTML)..."
cat > $APP_DIR/templates/index.html <<EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zeeno Control Panel</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body>
    <div class="container my-4">
        <h1 class="text-center">Zeeno Control Panel</h1>
        <div class="row mt-4">
            <div class="col-md-6">
                <h3>System Status</h3>
                <ul id="status-list" class="list-group">
                    <li class="list-group-item">CPU Usage: <span id="cpu-usage">Loading...</span>%</li>
                    <li class="list-group-item">Memory Usage: <span id="memory-usage">Loading...</span>%</li>
                    <li class="list-group-item">Disk Usage: <span id="disk-usage">Loading...</span>%</li>
                    <li class="list-group-item">Load Average: <span id="load-avg">Loading...</span></li>
                </ul>
            </div>
            <div class="col-md-6">
                <h3>Manage Sites</h3>
                <form id="site-form" class="mb-3">
                    <input type="text" id="domain" class="form-control mb-2" placeholder="Enter domain name" required>
                    <button type="submit" class="btn btn-primary">Add Site</button>
                </form>
                <h4>Available Sites</h4>
                <ul id="site-list" class="list-group"></ul>
            </div>
        </div>
    </div>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script>
        // Fetch System Status
        function fetchStatus() {
            $.getJSON("/api/status", function (data) {
                $("#cpu-usage").text(data.cpu_usage);
                $("#memory-usage").text(data.memory_usage);
                $("#disk-usage").text(data.disk_usage);
                $("#load-avg").text(data.load_avg.join(", "));
            });
        }

        // Fetch Sites
        function fetchSites() {
            $.getJSON("/api/sites", function (data) {
                const siteList = $("#site-list");
                siteList.empty();
                data.sites.forEach(site => {
                    siteList.append(`<li class="list-group-item">${site}</li>`);
                });
            });
        }

        // Add Site
        $("#site-form").submit(function (e) {
            e.preventDefault();
            const domain = $("#domain").val();
            $.ajax({
                url: "/api/sites",
                method: "POST",
                contentType: "application/json",
                data: JSON.stringify({ domain: domain }),
                success: function () {
                    fetchSites();
                    alert(`Site ${domain} added successfully.`);
                }
            });
        });

        // Initial Load
        $(document).ready(function () {
            fetchStatus();
            fetchSites();
            setInterval(fetchStatus, 5000); // Refresh system status every 5 seconds
        });
    </script>
</body>
</html>
EOL

print_success "Frontend created."

# Final Steps: Start Flask App as a service (Optional for production)
cat > /etc/systemd/system/zeeno.service <<EOL
[Unit]
Description=Zeeno Control Panel
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start Zeeno
systemctl daemon-reload
systemctl enable zeeno
systemctl start zeeno
print_success "Zeeno installation complete."

# Open in browser
echo "Zeeno is now installed and running."
echo "Visit http://$DOMAIN or https://$DOMAIN to access the control panel."
