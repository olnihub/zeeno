#!/bin/bash

# Update and install necessary packages
echo "Updating system and installing dependencies..."
sudo apt update -y
sudo apt install -y nginx nodejs npm mariadb-server git curl

# Install PM2 to keep the backend running
echo "Installing PM2..."
sudo npm install pm2 -g

# Set up Zeeno directories
echo "Setting up directories..."
mkdir -p /opt/zeeno/frontend
mkdir -p /opt/zeeno/backend

# Frontend: Simple HTML page
echo "Creating frontend (index.html)..."
cat << EOF > /opt/zeeno/frontend/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Zeeno - Simple Web Panel</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    h1 { color: #333; }
  </style>
</head>
<body>

  <h1>Welcome to Zeeno!</h1>
  <p>This is a very simple interface.</p>

  <h2>Server Status</h2>
  <p id="server-status">Loading...</p>

  <script>
    // Simple script to fetch data from the backend
    fetch('/api/status')
      .then(response => response.json())
      .then(data => {
        document.getElementById('server-status').innerText = 'Server is running: ' + data.status;
      })
      .catch(error => {
        document.getElementById('server-status').innerText = 'Failed to fetch server status.';
      });
  </script>

</body>
</html>
EOF

# Backend: Simple Node.js server
echo "Creating backend (server.js)..."
cat << EOF > /opt/zeeno/backend/server.js
const express = require('express');
const app = express();
const port = 3001;

// Middleware to serve static files (frontend)
app.use(express.static('/opt/zeeno/frontend'));

// Basic API to fetch server status
app.get('/api/status', (req, res) => {
  res.json({ status: 'Server is up and running!' });
});

// Start the server
app.listen(port, () => {
  console.log('Zeeno backend is running at http://localhost:' + port);
});
EOF

# Install backend dependencies (Express.js)
echo "Installing backend dependencies (Express.js)..."
cd /opt/zeeno/backend
npm init -y
npm install express

# Start the backend with PM2
echo "Starting backend server with PM2..."
pm2 start /opt/zeeno/backend/server.js --name zeeno-backend

# Set up Nginx for static frontend and API proxy
echo "Configuring Nginx..."
cat << EOF > /etc/nginx/sites-available/zeeno
server {
    listen 80;
    server_name your_domain_or_ip;

    root /opt/zeeno/frontend;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site and restart Nginx
echo "Enabling Nginx site configuration..."
sudo ln -s /etc/nginx/sites-available/zeeno /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# Check if Nginx is running
echo "Checking Nginx status..."
sudo systemctl status nginx

# Test MariaDB installation (optional step if using database)
echo "Testing MariaDB installation..."
mysql --version

# Finished
echo "Zeeno is now installed and running!"
echo "Access the frontend at http://your_domain_or_ip"
echo "Backend API is available at http://your_domain_or_ip/api/status"
