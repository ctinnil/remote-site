# remote-site
remote-site-fast-config

# Fast server setup 

```sh
wget -O /tmp/setup_openvpn.sh https://raw.githubusercontent.com/ctinnil/remote-site/refs/heads/main/setup_openvpn.sh
chmod +x /tmp/setup_openvpn.sh
/tmp/setup_openvpn.sh
cp /etc/openvpn/client.ovpn .
```

# Fast client setup 

```sh
scp -i ".ssh/[your].pem" [user]@[remote]:client.ovpn ~/Downloads
```

# Recommended client 

[Tunnelblick](https://tunnelblick.net)
