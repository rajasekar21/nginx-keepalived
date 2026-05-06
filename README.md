# NGINX + Keepalived — High Availability Across Two Datacenters

A production-ready HA setup using **NGINX** as the load balancer / reverse proxy and **Keepalived** (VRRP) to manage a floating Virtual IP across four nodes spread across two geographically separate datacenters, interconnected via **dark fibre** as a single stretched L2 domain.

---

## Architecture Overview

```
                        CLIENTS / INTERNET
                               │
                               │  Single Virtual IP (VIP)
                               │  (assign your VIP here)
                               │
               ┌───────────────▼───────────────┐
               │       LAYER 3 ROUTER           │
               └───────────────┬───────────────┘
                               │
               ┌───────────────▼───────────────┐
               │     LAYER 2 SWITCH FABRIC      │
               │  (Same Broadcast Domain/VLAN)  │
               └──────┬────────────────┬────────┘
                      │                │
          ┌───────────▼───┐    ┌───────▼───────────┐
          │  DC1 L2 Switch │    │  DC2 L2 Switch     │
          └──┬─────────┬──┘    └──┬──────────────┬──┘
             │         │          │              │
       ┌─────▼───┐ ┌───▼─────┐ ┌─▼────────┐ ┌──▼───────┐
       │  VM1    │ │  VM2    │ │  VM3     │ │  VM4     │
       │ Pri:200 │ │ Pri:150 │ │ Pri:100  │ │  Pri:50  │
       │ MASTER  │ │ BACKUP1 │ │ BACKUP2  │ │ BACKUP3  │
       │  NGINX  │ │  NGINX  │ │  NGINX   │ │  NGINX   │
       └─────────┘ └─────────┘ └──────────┘ └──────────┘
             ▲           ▲            ▲              ▲
             └───────────────VRRP─────────────────────┘
                     Keepalived Heartbeat / Multicast
                    (travels freely over dark fibre)

       ════════════════════════════════════════════════
              DARK FIBRE  —  Private Dedicated Link
              Stretched L2  │  Same Subnet  │  <1ms
       ════════════════════════════════════════════════
```

---

## Key Design Principles

| Attribute            | Detail                                              |
|----------------------|-----------------------------------------------------|
| **Network type**     | Stretched L2 — single subnet spans both DCs         |
| **Interconnect**     | Dark fibre — private, dedicated, sub-millisecond    |
| **Virtual IP**       | One floating VIP — no GSLB or DNS tricks needed     |
| **VRRP scope**       | Single group across all 4 nodes                     |
| **Failover order**   | VM1 → VM2 → VM3 → VM4 (descending priority)         |
| **RTO**              | ~1–3 seconds                                        |
| **RPO**              | Near-zero (shared L2 / synchronous replication)     |

---

## Node Roles

| Node | Datacenter | Keepalived Priority | Role     |
|------|------------|---------------------|----------|
| VM1  | DC1        | 200                 | MASTER   |
| VM2  | DC1        | 150                 | BACKUP 1 |
| VM3  | DC2        | 100                 | BACKUP 2 |
| VM4  | DC2        |  50                 | BACKUP 3 |

DC1 nodes carry higher priority — DC2 acts as a warm standby, automatically promoted if DC1 loses both nodes.

---

## Failover Scenarios

```
Scenario 1 — VM1 fails:
  VM2 wins VRRP election → claims VIP        (stays in DC1)  ~1–2s

Scenario 2 — VM1 + VM2 fail:
  VM3 wins VRRP election → claims VIP        (VIP moves to DC2) ~2–3s

Scenario 3 — DC1 entirely dark:
  VM3 = MASTER, VM4 = BACKUP               (DC2 fully self-sufficient)

Scenario 4 — Dark fibre link drops (split-brain):
  Both DCs may elect a MASTER simultaneously.
  Mitigated by:
    • nopreempt on DC2 nodes
    • track_interface / track_script to demote on link loss
    • Priority gap (100 point spread between DC1 and DC2)
```

---

## Repository Structure

```
nginx-keepalived/
├── README.md
├── keepalived/
│   ├── dc1-vm1-keepalived.conf      # MASTER config
│   ├── dc1-vm2-keepalived.conf      # BACKUP 1 config
│   ├── dc2-vm3-keepalived.conf      # BACKUP 2 config
│   └── dc2-vm4-keepalived.conf      # BACKUP 3 config
├── nginx/
│   ├── nginx.conf                   # Base NGINX config
│   └── conf.d/
│       └── default.conf             # Virtual host / upstream config
└── scripts/
    ├── check_nginx.sh               # Keepalived health check script
    └── notify.sh                    # Failover notification handler
```

---

## Keepalived Configuration — DC1 VM1 (MASTER)

```conf
# /etc/keepalived/keepalived.conf — DC1 VM1

global_defs {
    router_id DC1_VM1
    enable_script_security
}

vrrp_script check_nginx {
    script       "/etc/keepalived/scripts/check_nginx.sh"
    interval     2
    weight      -30
    fall         2
    rise         2
}

vrrp_instance VI_1 {
    state            MASTER
    interface        eth0
    virtual_router_id 51
    priority         200
    advert_int       1
    nopreempt

    authentication {
        auth_type PASS
        auth_pass S3cur3P@ss
    }

    virtual_ipaddress {
        <YOUR_VIP>/24 dev eth0
    }

    track_script {
        check_nginx
    }

    notify /etc/keepalived/scripts/notify.sh
}
```

---

## Keepalived Configuration — DC2 VM3 (BACKUP 2)

```conf
# /etc/keepalived/keepalived.conf — DC2 VM3

global_defs {
    router_id DC2_VM3
    enable_script_security
}

vrrp_script check_nginx {
    script       "/etc/keepalived/scripts/check_nginx.sh"
    interval     2
    weight      -30
    fall         2
    rise         2
}

vrrp_instance VI_1 {
    state            BACKUP
    interface        eth0
    virtual_router_id 51
    priority         100
    advert_int       1
    nopreempt

    authentication {
        auth_type PASS
        auth_pass S3cur3P@ss
    }

    virtual_ipaddress {
        <YOUR_VIP>/24 dev eth0
    }

    track_script {
        check_nginx
    }

    notify /etc/keepalived/scripts/notify.sh
}
```

---

## NGINX Health Check Script

```bash
#!/bin/bash
# /etc/keepalived/scripts/check_nginx.sh

if systemctl is-active --quiet nginx; then
    exit 0
else
    exit 1
fi
```

---

## NGINX Base Configuration

```nginx
# /etc/nginx/nginx.conf

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout 65;

    include /etc/nginx/conf.d/*.conf;
}
```

---

## Prerequisites

- 4 Linux VMs (Ubuntu 22.04 / RHEL 9 recommended)
- Dark fibre interconnect with L2 extension (same VLAN/subnet)
- NGINX installed on all nodes
- Keepalived installed on all nodes

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y nginx keepalived

# RHEL / CentOS
sudo dnf install -y nginx keepalived
```

---

## Quick Start

```bash
# 1. Clone this repository on each VM
git clone https://github.com/rajasekar21/nginx-keepalived.git
cd nginx-keepalived

# 2. Copy the matching Keepalived config to the node
#    (adjust the filename to match the node's role)
sudo cp keepalived/dc1-vm1-keepalived.conf /etc/keepalived/keepalived.conf

# 3. Copy health check script
sudo cp scripts/check_nginx.sh /etc/keepalived/scripts/
sudo chmod +x /etc/keepalived/scripts/check_nginx.sh

# 4. Copy NGINX config
sudo cp nginx/nginx.conf /etc/nginx/
sudo cp nginx/conf.d/default.conf /etc/nginx/conf.d/

# 5. Enable and start services
sudo systemctl enable --now nginx
sudo systemctl enable --now keepalived

# 6. Verify VIP assignment on the MASTER node
ip addr show eth0 | grep <YOUR_VIP>
```

---

## Verifying Failover

```bash
# On any node — watch VIP ownership in real time
watch -n1 "ip addr show eth0 | grep -E 'inet '"

# Check Keepalived state
sudo systemctl status keepalived

# View VRRP logs
sudo journalctl -u keepalived -f
```

---

## Security Notes

- Change `auth_pass` to a strong unique secret across all nodes
- Use firewall rules to restrict VRRP multicast (224.0.0.18) to trusted interfaces only
- Run `check_nginx.sh` as a non-root user where possible (`enable_script_security` enforces this)

---

## License

MIT
