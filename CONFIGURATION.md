# Configuration Guide

This repository contains ready-to-copy NGINX and Keepalived configuration files for the four-node architecture:

| Node | Datacenter | Keepalived file | State | Priority |
| --- | --- | --- | --- | --- |
| VM1 | DC1 | `keepalived/dc1-vm1-keepalived.conf` | MASTER | 200 |
| VM2 | DC1 | `keepalived/dc1-vm2-keepalived.conf` | BACKUP | 150 |
| VM3 | DC2 | `keepalived/dc2-vm3-keepalived.conf` | BACKUP | 100 |
| VM4 | DC2 | `keepalived/dc2-vm4-keepalived.conf` | BACKUP | 50 |

Before deploying, replace these placeholders in each Keepalived file:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `CHANGE_ME_INTERFACE` | NIC on the stretched L2 VLAN | `eth0`, `ens192` |
| `CHANGE_ME_VIP` | Floating virtual IP shared by all VMs | `10.10.10.100` |
| `CHANGE_ME_VRRP_SECRET` | Same VRRP auth secret on all four VMs | `strong-shared-secret` |

Replace these placeholders in `nginx/conf.d/default.conf`:

| Placeholder | Meaning |
| --- | --- |
| `CHANGE_ME_BACKEND_1` | First backend application server IP or DNS name |
| `CHANGE_ME_BACKEND_2` | Second backend application server IP or DNS name |

## Deploy On Each VM

Copy the matching Keepalived file for that VM:

```bash
sudo install -d -m 0755 /etc/keepalived/scripts
sudo cp keepalived/dc1-vm1-keepalived.conf /etc/keepalived/keepalived.conf
sudo cp scripts/check_nginx.sh scripts/notify.sh /etc/keepalived/scripts/
sudo chmod +x /etc/keepalived/scripts/check_nginx.sh /etc/keepalived/scripts/notify.sh
```

Copy the shared NGINX configuration:

```bash
sudo cp nginx/nginx.conf /etc/nginx/nginx.conf
sudo cp nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
```

Validate and start:

```bash
sudo nginx -t
sudo keepalived -t -f /etc/keepalived/keepalived.conf
sudo systemctl enable --now nginx keepalived
```

Check VIP ownership:

```bash
ip addr show CHANGE_ME_INTERFACE | grep CHANGE_ME_VIP
sudo journalctl -u keepalived -f
```
