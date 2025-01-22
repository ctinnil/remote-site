#!/bin/bash

# Variables
OPENVPN_DIR="/etc/openvpn"
KEY_DIR="${OPENVPN_DIR}/keys"

# Automatically fetch the server's public IP
SERVER_IP=$(curl -s ifconfig.io)

# Fetch the public IP
PUBLIC_IP=$(curl -s ifconfig.io)

# Automatically detect the public-facing network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')

# Update system, install OpenVPN and dependencies 
sudo apt update && sudo apt upgrade -y && sudo apt install openvpn iptables-persistent -y

# Genrate static key 
openvpn --genkey secret ~/static.key
sudo mv ~/static.key ${OPENVPN_DIR}/static.key

# Set correct permissions
sudo chown root:root ${OPENVPN_DIR}/static.key
sudo chmod 600 ${OPENVPN_DIR}/static.key

#sudo nano /etc/openvpn/server.conf
# Generate server.conf
cat <<EOF >${OPENVPN_DIR}/server.conf
dev tun
ifconfig 10.8.0.1 10.8.0.2
secret ${OPENVPN_DIR}/static.key
proto udp
port 1194
keepalive 10 120
persist-key
persist-tun
verb 3
cipher AES-256-CBC
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "redirect-gateway def1"
EOF

#sudo nano /etc/openvpn/client.ovpn
# Generate client.conf
cat <<EOF >${OPENVPN_DIR}/client.conf
remote ${PUBLIC_IP} 1194
dev tun
ifconfig 10.8.0.2 10.8.0.1
secret ${OPENVPN_DIR}/static.key
proto udp
port 1194
persist-key
persist-tun
verb 3
EOF

# Apply the iptables NAT rule for the detected interface
iptables -t nat -A POSTROUTING -o ${INTERFACE} -j MASQUERADE
#iptables-save > /etc/iptables/rules.v4
sudo netfilter-persistent save

# Enable IP forwarding
#sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Verifying the Rule
iptables -t nat -L -v

# Start OpenVPN
systemctl enable openvpn@server
systemctl start openvpn@server

echo "OpenVPN setup complete. Client configuration available at: ${OPENVPN_DIR}/client.conf"
