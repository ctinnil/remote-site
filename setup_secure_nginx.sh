#!/bin/bash

# ==============================
# Secure Nginx Reverse Proxy with SSL, Fail2Ban & Local Domain Setup
# ==============================

set -e  # Exit on error

# Default values
DEFAULT_LOCAL_DOMAIN="mylocalserver.test"
DEFAULT_APP_PORT="5000"
USE_PUBLIC_DOMAIN="n"

# Prompt user for domain choice
read -p "Do you want to use a public domain with Certbot? (y/n, default: n): " USE_PUBLIC_DOMAIN
USE_PUBLIC_DOMAIN=${USE_PUBLIC_DOMAIN:-n}

if [[ "$USE_PUBLIC_DOMAIN" == "y" ]]; then
    read -p "Enter your public domain name: " DOMAIN
else
    read -p "Enter your local domain name (default: $DEFAULT_LOCAL_DOMAIN): " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_LOCAL_DOMAIN}

    # Ensure local domain is set in /etc/hosts
    if ! grep -q "$DOMAIN" /etc/hosts; then
        echo "127.0.0.1   $DOMAIN" | sudo tee -a /etc/hosts
        echo "✅ Added $DOMAIN to /etc/hosts"
    else
        echo "✅ $DOMAIN already exists in /etc/hosts"
    fi
fi

# Ask for application port
read -p "Enter your local app port (default: $DEFAULT_APP_PORT): " APP_PORT
APP_PORT=${APP_PORT:-$DEFAULT_APP_PORT}

# Define paths
NGINX_CONF="/etc/nginx/sites-available/reverse-proxy"
SSL_DIR="/etc/nginx/ssl"
SSL_CERT="$SSL_DIR/$DOMAIN.crt"
SSL_KEY="$SSL_DIR/$DOMAIN.key"
LOG_FILE="/var/log/nginx/access.log"

echo "🚀 Updating and installing required packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx fail2ban openssl curl nftables

# SSL Configuration
if [[ "$USE_PUBLIC_DOMAIN" == "y" ]]; then
    echo "🔐 Installing Certbot and generating SSL certificate..."
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d "$DOMAIN"
else
    echo "🔐 Generating a self-signed SSL certificate..."
    sudo mkdir -p $SSL_DIR
    sudo openssl req -x509 -newkey rsa:2048 -keyout $SSL_KEY -out $SSL_CERT -days 365 -nodes -subj "/CN=$DOMAIN"
    sudo chmod 600 $SSL_KEY $SSL_CERT
fi

# Setup Nginx Configuration
echo "🌍 Configuring Nginx as a reverse proxy for app on port $APP_PORT..."
sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Block bad requests before forwarding to app
    location ~* /(cgi-bin|admin|wp-login|wp-admin|config|backup|dump|data|private|secret) {
        deny all;
        return 403;
    }

    error_log /var/log/nginx/bad_requests.log warn;
}

server {
    listen 80;
    server_name $DOMAIN;

    # Block bad requests before redirecting
    location ~* /(cgi-bin|admin|wp-login|wp-admin|config|backup|dump|data|private|secret) {
        deny all;
        return 403;
    }

    # Redirect HTTP to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOL

echo "🔄 Enabling Nginx configuration..."
sudo ln -s $NGINX_CONF /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Fail2Ban Configuration
echo "🚔 Setting up Fail2Ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOL
[nginx-bad-request]
enabled = true
filter = nginx-bad-request
logpath = $LOG_FILE
bantime = 3600
findtime = 600
maxretry = 3

[nginx-login]
enabled = true
filter = nginx-login
logpath = $LOG_FILE
bantime = 3600
findtime = 600
maxretry = 5
EOL

sudo tee /etc/fail2ban/filter.d/nginx-bad-request.conf > /dev/null <<EOL
[Definition]
failregex = <HOST> - - .* "(GET|POST) /(cgi-bin|admin|wp-login|wp-admin|config|backup|dump|data|private|secret) HTTP/.*" 403
EOL

sudo tee /etc/fail2ban/filter.d/nginx-login.conf > /dev/null <<EOL
[Definition]
failregex = <HOST> - - .* "(GET|POST) /login HTTP/.*" 401
EOL

echo "🚀 Restarting Fail2Ban..."
sudo systemctl restart fail2ban

# Firewall Configuration with nftables
echo "🛡 Configuring nftables firewall rules..."
sudo tee /etc/nftables.conf > /dev/null <<EOL
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback interface
        iif lo accept

        # Allow established and related connections
        ct state established,related accept

        # Allow SSH
        tcp dport 22 accept

        # Allow HTTP and HTTPS
        tcp dport 80 accept
        tcp dport 443 accept

        # Block public access to app port ($APP_PORT)
        ip saddr 0.0.0.0/0 tcp dport ${APP_PORT} drop
        ip6 saddr ::/0 tcp dport ${APP_PORT} drop
    }
}
EOL

sudo systemctl enable nftables
sudo systemctl restart nftables

echo "✅ Setup complete!"
echo "🌐 Open https://$DOMAIN in your browser."