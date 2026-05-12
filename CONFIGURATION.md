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
| `CHANGE_ME_VM1_IP` | Real (non-VIP) IP address of VM1 | `10.10.10.11` |
| `CHANGE_ME_VM2_IP` | Real (non-VIP) IP address of VM2 | `10.10.10.12` |
| `CHANGE_ME_VM3_IP` | Real (non-VIP) IP address of VM3 | `10.10.10.13` |
| `CHANGE_ME_VM4_IP` | Real (non-VIP) IP address of VM4 | `10.10.10.14` |

Replace these placeholders in `nginx/conf.d/default.conf`:

| Placeholder | Meaning |
| --- | --- |
| `CHANGE_ME_BACKEND_1` | First backend application server IP or DNS name |
| `CHANGE_ME_BACKEND_2` | Second backend application server IP or DNS name |

Replace `CHANGE_ME_VIP` in `scripts/setup_lvs_loopback.sh` with the same VIP value used in the Keepalived files.

## LVS-DR: How It Works

Each Keepalived config now includes a `virtual_server` block alongside the existing `vrrp_instance`. This enables **LVS Direct Routing** — a kernel-level load balancer built into Linux:

- The VRRP MASTER holds the VIP on its network interface and runs the IPVS rules.
- Incoming connections to the VIP are distributed across all 4 real servers (VM1–VM4) using least-connections scheduling.
- Each real server responds **directly to the client** — responses do not return through the MASTER, eliminating it as a bottleneck.
- Keepalived health-checks each real server at `/nginx-health` every 5 seconds and removes any unhealthy node from the pool automatically.
- On VRRP failover, the new MASTER inherits the VIP and activates the same IPVS rules — no manual intervention needed.

### Loopback VIP Requirement

In LVS-DR mode, IPVS rewrites only the MAC address of the forwarded frame; the destination IP remains the VIP. Each real server must therefore have the VIP bound on its loopback interface so its network stack accepts the packet. ARP must be suppressed on that address so only the VRRP MASTER answers ARP requests on the network.

`scripts/setup_lvs_loopback.sh` handles both. It must run at boot on every VM **before** NGINX and Keepalived start.

## Deploy On Each VM

Copy the matching Keepalived file for that VM:

```bash
sudo install -d -m 0755 /etc/keepalived/scripts
sudo cp keepalived/dc1-vm1-keepalived.conf /etc/keepalived/keepalived.conf
sudo cp scripts/check_nginx.sh scripts/notify.sh \
        scripts/setup_lvs_loopback.sh /etc/keepalived/scripts/
sudo chmod +x /etc/keepalived/scripts/check_nginx.sh \
              /etc/keepalived/scripts/notify.sh \
              /etc/keepalived/scripts/setup_lvs_loopback.sh
```

Install the loopback service so it runs at boot:

```bash
sudo cp scripts/lvs-loopback.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now lvs-loopback
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

Check VIP ownership and IPVS rules:

```bash
ip addr show CHANGE_ME_INTERFACE | grep CHANGE_ME_VIP
sudo journalctl -u keepalived -f
sudo ipvsadm -Ln
```
