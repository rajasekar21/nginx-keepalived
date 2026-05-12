#!/usr/bin/env bash
# Run at boot on every real server before keepalived starts.
# Adds the VIP to loopback and suppresses ARP so only the VRRP MASTER
# answers ARP requests for the VIP on the network.
set -euo pipefail

VIP="CHANGE_ME_VIP"

if ! ip addr show lo | grep -q "${VIP}/32"; then
    ip addr add "${VIP}/32" dev lo
fi

sysctl -w net.ipv4.conf.all.arp_ignore=1
sysctl -w net.ipv4.conf.all.arp_announce=2
