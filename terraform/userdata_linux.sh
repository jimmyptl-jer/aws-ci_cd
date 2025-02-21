#!/bin/bash
# User Data script for setting up an Apache Web Server on Amazon Linux 2

# Enable error handling
set -e

# Update system packages
yum update -y

# Install Apache (httpd)
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Install additional dependencies
yum install -y wget unzip 

# Change to temp directory and download the template
cd /tmp/
wget -O waso_strategy.zip https://www.tooplate.com/zip-templates/2130_waso_strategy.zip
unzip waso_strategy.zip

# Move files to the Apache root directory
TEMPLATE_DIR=$(unzip -qql waso_strategy.zip | head -n1 | awk '{print $4}')
cp -r "$TEMPLATE_DIR"/* /var/www/html/

# Set proper permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Restart Apache to apply changes
systemctl restart httpd

# Enable the firewall and allow HTTP traffic (optional)
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --add-service=http --permanent
    firewall-cmd --reload
fi

echo "Apache setup complete."
