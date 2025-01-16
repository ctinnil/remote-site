```sh
#cloud-config
runcmd:
  - wget -O /tmp/setup_openvpn.sh https://your-script-url/setup_openvpn.sh
  - chmod +x /tmp/setup_openvpn.sh
  - /tmp/setup_openvpn.sh
```
