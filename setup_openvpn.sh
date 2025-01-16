#!/bin/bash

# Automatically fetch the server's public IP
SERVER_IP=$(curl -s ifconfig.io)

# Variables
VPN_SUBNET="10.8.0.0"
VPN_NETMASK="255.255.255.0"
CLIENT_NAME="client"
OPENVPN_DIR="/etc/openvpn"
KEY_DIR="${OPENVPN_DIR}/keys"
OUTPUT_DIR="${OPENVPN_DIR}/client-configs"

# Install OpenVPN and dependencies
apt update
apt install -y openvpn easy-rsa iptables-persistent

# Set up easy-rsa
make-cadir ~/easy-rsa
cd ~/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
./easyrsa gen-req ${CLIENT_NAME} nopass
./easyrsa sign-req client ${CLIENT_NAME}

# Copy certificates and keys
mkdir -p ${KEY_DIR}
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ${KEY_DIR}
cp pki/issued/${CLIENT_NAME}.crt pki/private/${CLIENT_NAME}.key ${KEY_DIR}

# Generate server.conf
cat <<EOF >${OPENVPN_DIR}/server.conf
port 1194
proto udp
dev tun
ca ${KEY_DIR}/ca.crt
cert ${KEY_DIR}/server.crt
key ${KEY_DIR}/server.key
dh ${KEY_DIR}/dh.pem
server ${VPN_SUBNET} ${VPN_NETMASK}
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
persist-key
persist-tun
cipher AES-256-CBC
user nobody
group nogroup
verb 3
EOF

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Set up NAT
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET}/24 -o ens5 -j MASQUERADE
iptables-save > /etc/iptables/rules.v4

# Start OpenVPN
systemctl enable openvpn@server
systemctl start openvpn@server

# Generate client configuration
mkdir -p ${OUTPUT_DIR}
cat <<EOF >${OUTPUT_DIR}/${CLIENT_NAME}.ovpn
client
dev tun
proto udp
remote ${SERVER_IP} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca [inline]
cert [inline]
key [inline]
cipher AES-256-CBC
verb 3
<ca>
$(cat ${KEY_DIR}/ca.crt)
</ca>
<cert>
$(cat ${KEY_DIR}/${CLIENT_NAME}.crt)
</cert>
<key>
$(cat ${KEY_DIR}/${CLIENT_NAME}.key)
</key>
EOF

echo "OpenVPN setup complete. Client configuration available at: ${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"
