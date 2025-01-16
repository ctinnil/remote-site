```sh
#cloud-config
runcmd:
  - wget -O /tmp/setup_openvpn.sh https://raw.githubusercontent.com/ctinnil/remote-site/refs/heads/main/setup_openvpn.sh
  - chmod +x /tmp/setup_openvpn.sh
  - /tmp/setup_openvpn.sh
```
