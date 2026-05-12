# NGINX + Keepalived — High Availability Across Two Datacenters

A production-ready HA setup using **NGINX** as the reverse proxy on all four nodes and **Keepalived** to manage both a floating Virtual IP (VRRP) and kernel-level load balancing (LVS Direct Routing / IPVS) across two geographically separate datacenters interconnected via **dark fibre** as a single stretched L2 domain. All four NGINX instances serve live traffic simultaneously — no idle standby nodes.

---

## Architecture Overview

> 🔗 **[View Interactive Architecture Diagram](https://htmlpreview.github.io/?https://github.com/rajasekar21/nginx-keepalived/blob/main/architecture.html)**

<div align="center" style="font-family:sans-serif;background:#0d1117;padding:28px;border-radius:14px;color:#e6edf3;">

<!-- INTERNET -->
<div style="display:inline-block;background:#1c2128;border:1.5px solid #30363d;border-radius:10px;padding:10px 36px;color:#79c0ff;font-weight:700;letter-spacing:1px;font-size:0.9rem;">
🌐 &nbsp;CLIENTS / INTERNET
</div>

<div style="color:#8b949e;font-size:1.4rem;line-height:1;">↓</div>

<!-- VIP -->
<div style="display:inline-block;background:#14532d;border:1.5px solid #16a34a;border-radius:20px;padding:6px 24px;color:#4ade80;font-weight:700;font-size:0.82rem;letter-spacing:0.8px;">
⚡ Virtual IP — Single Entry Point
</div>

<div style="color:#8b949e;font-size:1.4rem;line-height:1;">↓</div>

<!-- ROUTER -->
<div style="display:inline-block;background:#1f2937;border:1.5px solid #4b5563;border-radius:10px;padding:8px 28px;color:#f9a825;font-weight:600;font-size:0.82rem;">
🔀 Layer 3 Router / Firewall
</div>

<div style="color:#8b949e;font-size:1.4rem;line-height:1;">↓</div>

<!-- L2 SWITCH -->
<div style="display:inline-block;background:#1a2035;border:1.5px solid #3b82f6;border-radius:10px;padding:8px 28px;color:#93c5fd;font-weight:600;font-size:0.82rem;">
🔗 Layer 2 Switch Fabric — Same Broadcast Domain / VLAN
</div>

<div style="color:#8b949e;font-size:1.4rem;line-height:1;">↓</div>

<!-- IPVS DIRECTOR -->
<div style="display:inline-block;background:#1e1040;border:1.5px solid #a78bfa;border-radius:10px;padding:8px 28px;color:#c4b5fd;font-weight:700;font-size:0.82rem;">
⚙ VRRP MASTER · IPVS Director — LVS Direct Routing
</div>
<div style="color:#8b949e;font-size:0.75rem;margin:2px 0 4px;">distributes connections to all 4 real servers via MAC rewrite — no NAT</div>

<div style="color:#8b949e;font-size:1.4rem;line-height:1;">↓</div>

<!-- DATACENTERS -->
<table style="border-collapse:separate;border-spacing:16px;margin:0 auto;">
<tr>

<!-- DC1 -->
<td style="background:#0d1f3c;border:2px solid #1d4ed8;border-radius:14px;padding:18px 16px;vertical-align:top;min-width:240px;">
<div style="text-align:center;color:#60a5fa;font-weight:800;font-size:0.75rem;letter-spacing:2px;background:rgba(29,78,216,0.2);border:1px solid rgba(29,78,216,0.4);border-radius:6px;padding:5px;margin-bottom:14px;">
🏢 &nbsp;DATACENTER 1
</div>
<div style="color:#6b7280;font-size:0.7rem;text-align:center;margin-bottom:10px;">DC1 L2 Switch</div>
<table style="border-collapse:separate;border-spacing:8px;margin:0 auto;">
<tr>
<td style="background:#052e16;border:2px solid #16a34a;border-radius:10px;padding:12px 10px;text-align:center;min-width:100px;">
<div style="color:#4ade80;font-weight:800;font-size:0.95rem;">VM 1</div>
<div style="background:#16a34a;color:#fff;border-radius:10px;font-size:0.62rem;font-weight:700;padding:2px 8px;margin:2px 0;display:inline-block;letter-spacing:1px;">MASTER</div><br>
<div style="background:#92400e;color:#fcd34d;border-radius:10px;font-size:0.62rem;font-weight:700;padding:2px 8px;margin:2px 0;display:inline-block;letter-spacing:1px;">IPVS DIR</div>
<div style="color:#fbbf24;font-size:0.7rem;">Pri: 200</div>
<div style="color:#a3a3a3;font-size:0.68rem;margin-top:4px;">● NGINX<br>● IPVS Director<br>● Keepalived<br>● lo: VIP</div>
</td>
<td style="background:#0c1e2e;border:1.5px solid #0ea5e9;border-radius:10px;padding:12px 10px;text-align:center;min-width:100px;">
<div style="color:#38bdf8;font-weight:800;font-size:0.95rem;">VM 2</div>
<div style="background:#1d4ed8;color:#fff;border-radius:10px;font-size:0.62rem;font-weight:700;padding:2px 8px;margin:4px 0;display:inline-block;letter-spacing:1px;">BACKUP 1</div>
<div style="color:#fbbf24;font-size:0.7rem;">Pri: 150</div>
<div style="color:#a3a3a3;font-size:0.68rem;margin-top:4px;">● NGINX<br>● Keepalived<br>● lo: VIP</div>
</td>
</tr>
</table>
<div style="text-align:center;color:#f59e0b;font-size:0.68rem;margin-top:10px;font-weight:600;">⚡ VRRP Heartbeat</div>
</td>

<!-- DC2 -->
<td style="background:#1a0d3c;border:2px solid #7c3aed;border-radius:14px;padding:18px 16px;vertical-align:top;min-width:240px;">
<div style="text-align:center;color:#c084fc;font-weight:800;font-size:0.75rem;letter-spacing:2px;background:rgba(124,58,237,0.2);border:1px solid rgba(124,58,237,0.4);border-radius:6px;padding:5px;margin-bottom:14px;">
🏢 &nbsp;DATACENTER 2
</div>
<div style="color:#6b7280;font-size:0.7rem;text-align:center;margin-bottom:10px;">DC2 L2 Switch</div>
<table style="border-collapse:separate;border-spacing:8px;margin:0 auto;">
<tr>
<td style="background:#0c1e2e;border:1.5px solid #0ea5e9;border-radius:10px;padding:12px 10px;text-align:center;min-width:100px;">
<div style="color:#38bdf8;font-weight:800;font-size:0.95rem;">VM 3</div>
<div style="background:#7c3aed;color:#fff;border-radius:10px;font-size:0.62rem;font-weight:700;padding:2px 8px;margin:4px 0;display:inline-block;letter-spacing:1px;">BACKUP 2</div>
<div style="color:#fbbf24;font-size:0.7rem;">Pri: 100</div>
<div style="color:#a3a3a3;font-size:0.68rem;margin-top:4px;">● NGINX<br>● Keepalived<br>● lo: VIP</div>
</td>
<td style="background:#0c1e2e;border:1.5px solid #0ea5e9;border-radius:10px;padding:12px 10px;text-align:center;min-width:100px;">
<div style="color:#38bdf8;font-weight:800;font-size:0.95rem;">VM 4</div>
<div style="background:#9f1239;color:#fff;border-radius:10px;font-size:0.62rem;font-weight:700;padding:2px 8px;margin:4px 0;display:inline-block;letter-spacing:1px;">BACKUP 3</div>
<div style="color:#fbbf24;font-size:0.7rem;">Pri: 50</div>
<div style="color:#a3a3a3;font-size:0.68rem;margin-top:4px;">● NGINX<br>● Keepalived<br>● lo: VIP</div>
</td>
</tr>
</table>
<div style="text-align:center;color:#f59e0b;font-size:0.68rem;margin-top:10px;font-weight:600;">⚡ VRRP Heartbeat</div>
</td>

</tr>
</table>

<div style="color:#4ade80;font-size:0.75rem;margin-top:6px;font-weight:600;">↑ Direct return — real servers respond directly to clients, bypassing the IPVS Director</div>

<!-- DARK FIBRE -->
<div style="display:inline-block;background:#1a0a00;border:2px solid #f97316;border-radius:14px;padding:12px 32px;margin-top:8px;">
<div style="color:#fb923c;font-weight:800;font-size:0.8rem;letter-spacing:2px;text-transform:uppercase;margin-bottom:6px;">🔆 Dark Fibre Interconnect</div>
<div style="display:flex;gap:8px;justify-content:center;flex-wrap:wrap;">
<span style="background:rgba(249,115,22,0.15);border:1px solid rgba(249,115,22,0.35);border-radius:8px;padding:3px 10px;font-size:0.68rem;color:#fdba74;font-weight:600;">Private Dedicated Link</span>
<span style="background:rgba(249,115,22,0.15);border:1px solid rgba(249,115,22,0.35);border-radius:8px;padding:3px 10px;font-size:0.68rem;color:#fdba74;font-weight:600;">Stretched L2 / Same Subnet</span>
<span style="background:rgba(249,115,22,0.15);border:1px solid rgba(249,115,22,0.35);border-radius:8px;padding:3px 10px;font-size:0.68rem;color:#fdba74;font-weight:600;">Sub-millisecond Latency</span>
<span style="background:rgba(249,115,22,0.15);border:1px solid rgba(249,115,22,0.35);border-radius:8px;padding:3px 10px;font-size:0.68rem;color:#fdba74;font-weight:600;">VRRP Multicast Traverses Freely</span>
<span style="background:rgba(249,115,22,0.15);border:1px solid rgba(249,115,22,0.35);border-radius:8px;padding:3px 10px;font-size:0.68rem;color:#fdba74;font-weight:600;">IPVS Direct Return Path</span>
<span style="background:rgba(249,115,22,0.15);border:1px solid rgba(249,115,22,0.35);border-radius:8px;padding:3px 10px;font-size:0.68rem;color:#fdba74;font-weight:600;">No GSLB Required</span>
</div>
</div>

</div>

---

## Key Design Principles

| Attribute            | Detail                                              |
|----------------------|-----------------------------------------------------|
| **Network type**     | Stretched L2 — single subnet spans both DCs             |
| **Interconnect**     | Dark fibre — private, dedicated, sub-millisecond        |
| **Virtual IP**       | One floating VIP — no GSLB or DNS tricks needed         |
| **VRRP scope**       | Single group across all 4 nodes                         |
| **Load balancing**   | LVS Direct Routing (IPVS) — kernel-level, least-conn    |
| **Active NGINX**     | All 4 nodes receive live traffic simultaneously         |
| **Response path**    | Direct return — real servers reply to clients, not via director |
| **Failover order**   | VM1 → VM2 → VM3 → VM4 (VRRP Director role shifts)      |
| **RTO**              | ~1–3 seconds                                            |
| **RPO**              | Near-zero (shared L2 / synchronous replication)         |

---

## Node Roles

| Node | Datacenter | Keepalived Priority | Role     |
|------|------------|---------------------|----------|
| VM1  | DC1        | 200                 | MASTER   |
| VM2  | DC1        | 150                 | BACKUP 1 |
| VM3  | DC2        | 100                 | BACKUP 2 |
| VM4  | DC2        |  50                 | BACKUP 3 |

DC1 nodes carry higher priority for the VRRP Director role — DC2 is automatically promoted if DC1 loses both nodes. All four nodes act as active NGINX real servers under normal operation regardless of their VRRP role.

---

## Failover Scenarios

```
Scenario 1 — VM1 fails:
  VM2 wins VRRP election → claims VIP + IPVS Director role  (stays in DC1)  ~1–2s
  VM1 removed from IPVS pool by health check.  VM2, VM3, VM4 serve traffic.

Scenario 2 — VM1 + VM2 fail:
  VM3 wins VRRP election → claims VIP + Director           (moves to DC2)   ~2–3s
  Only VM3 and VM4 serve traffic.

Scenario 3 — DC1 entirely dark:
  VM3 = IPVS Director + MASTER, VM4 = active real server + BACKUP
  DC2 fully self-sufficient.

Scenario 4 — Single node NGINX unhealthy (any node):
  Keepalived HTTP_GET health check fails → node weight set to 0 in IPVS pool.
  Remaining nodes absorb traffic.  No VIP failover needed.

Scenario 5 — Dark fibre link drops (split-brain):
  Both DCs may elect a MASTER simultaneously.
  Mitigated by:
    • nopreempt on DC2 nodes
    • track_script to demote on NGINX failure
    • Priority gap (100 point spread between DC1 and DC2)
```

---

## Repository Structure

```
nginx-keepalived/
├── README.md
├── CONFIGURATION.md
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
    ├── check_nginx.sh               # Keepalived VRRP health check script
    ├── notify.sh                    # Failover notification handler
    ├── setup_lvs_loopback.sh        # Binds VIP on loopback, suppresses ARP
    └── lvs-loopback.service         # Systemd unit — runs loopback setup at boot
```

---

## Keepalived Configuration — DC1 VM1 (MASTER)

Use `keepalived/dc1-vm1-keepalived.conf`.

This node is the preferred MASTER with priority `200`.

---

## Keepalived Configuration — DC1 VM2 (BACKUP 1)

Use `keepalived/dc1-vm2-keepalived.conf`.

This node is the first local DC1 failover target with priority `150`.

---

## Keepalived Configuration — DC2 VM3 (BACKUP 2)

Use `keepalived/dc2-vm3-keepalived.conf`.

This node is the first DC2 standby with priority `100`.

---

## Keepalived Configuration — DC2 VM4 (BACKUP 3)

Use `keepalived/dc2-vm4-keepalived.conf`.

This node is the final standby with priority `50`.

---

## NGINX Health Check Script

Use `scripts/check_nginx.sh`.

Keepalived calls this script every two seconds. If NGINX is not healthy, the node priority is reduced so another VM can take ownership of the VIP.

---

## NGINX Base Configuration

Use `nginx/nginx.conf` and `nginx/conf.d/default.conf`.

The default virtual host includes:

- `/nginx-health` for local health checks
- `backend_app` upstream placeholders for backend application servers
- standard reverse proxy headers and upstream retry behavior

See `CONFIGURATION.md` for the placeholder list and deployment commands.

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

# 3. Copy Keepalived helper scripts
sudo install -d -m 0755 /etc/keepalived/scripts
sudo cp scripts/check_nginx.sh scripts/notify.sh \
        scripts/setup_lvs_loopback.sh /etc/keepalived/scripts/
sudo chmod +x /etc/keepalived/scripts/check_nginx.sh \
              /etc/keepalived/scripts/notify.sh \
              /etc/keepalived/scripts/setup_lvs_loopback.sh

# 4. Install loopback VIP service (run on every node before nginx/keepalived)
sudo cp scripts/lvs-loopback.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now lvs-loopback

# 5. Copy NGINX config
sudo cp nginx/nginx.conf /etc/nginx/
sudo cp nginx/conf.d/default.conf /etc/nginx/conf.d/

# 6. Validate configs
sudo nginx -t
sudo keepalived -t -f /etc/keepalived/keepalived.conf

# 7. Enable and start services
sudo systemctl enable --now nginx
sudo systemctl enable --now keepalived

# 8. Verify VIP assignment and IPVS pool on the MASTER node
ip addr show CHANGE_ME_INTERFACE | grep CHANGE_ME_VIP
sudo ipvsadm -Ln
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

# On the MASTER — view IPVS pool and connection counts
sudo ipvsadm -Ln

# Watch IPVS real-server weights update as nodes go up/down
watch -n2 "sudo ipvsadm -Ln"
```

---

## Security Notes

- Change `auth_pass` to a strong unique secret across all nodes
- Use firewall rules to restrict VRRP multicast (224.0.0.18) to trusted interfaces only
- Run `check_nginx.sh` as a non-root user where possible (`enable_script_security` enforces this)

---

## License

MIT
