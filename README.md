# Zeeno Installation Script

Zeeno is an automation tool to help install and configure server services such as NGINX, MySQL, and SSL certificates on a fresh server. This guide will walk you through how to install and use the script.

## Features:
- Install and configure NGINX, MySQL, and MariaDB
- Configure SSL/TLS with Let's Encrypt
- Set up SSH/FTP, Fail2Ban, Firewall, and more.
- Simple site and database management via a GUI control panel.

## Prerequisites:
- A fresh Ubuntu/Debian server
- A domain name (for SSL configuration)

## Installation:
1. Clone or download this repository to your server.
2. Make the script executable:
   ```bash
   chmod +x install_zeeno.sh
