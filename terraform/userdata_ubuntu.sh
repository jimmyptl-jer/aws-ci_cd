#!/bin/bash
# User Data script for setting up an Apache Web Server on Ubuntu

# Enable error handling
set -e

# Update system packages
apt update -y
apt upgrade -y

# Install Apache (apache2)
apt install -y apache2

# Install additional dependencies
apt install -y wget unzip

# Start and enable Apache service
systemctl start apache2
systemctl enable apache2

# Change to temp directory and download the template
cd /tmp/
wget -O waso_strategy.zip https://www.tooplate.com/zip-templates/2130_waso_strategy.zip
unzip waso_strategy.zip

# Move files to the Apache root directory
TEMPLATE_DIR=$(unzip -qql waso_strategy.zip | head -n1 | awk '{print $4}')
cp -r "$TEMPLATE_DIR"/* /var/www/html/

# Set proper permissions
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

# Restart Apache to apply changes
systemctl restart apache2

# Enable the firewall and allow HTTP traffic (optional)
if command -v ufw &> /dev/null; then
    ufw allow 'Apache'
    ufw reload
fi

echo "Apache setup complete."
