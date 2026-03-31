#!/usr/bin/env bash
#===============================================================================
# network-practice.sh — RHCSA Networking Practice Lab
# Covers: nmcli, ip, firewall, DNS, SSH, hostname, routing
# Usage : sudo bash network-practice.sh
#===============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${CYAN}[LAB]${NC} $*"; }
ok() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
task() { echo -e "\n${BOLD}━━━ Task: $* ━━━${NC}"; }

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}Run as root${NC}"
	exit 1
fi

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║       RHCSA Practice Lab — Networking               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Task 1: Network connection overview
# ---------------------------------------------------------------------------
task "1 — Network Connection Overview"

log "NetworkManager connections:"
nmcli connection show 2>/dev/null || ip addr show

log "IP addresses:"
ip -4 addr show | grep inet || true

log "Routing table:"
ip route show

log "DNS configuration:"
cat /etc/resolv.conf || true

# ---------------------------------------------------------------------------
# Task 2: Configure hostname
# ---------------------------------------------------------------------------
task "2 — Hostname Management"

CURRENT_HOST=$(hostnamectl --static 2>/dev/null || hostname)
log "Current hostname: $CURRENT_HOST"

# Set a practice hostname (don't change actual hostname)
log "Example: hostnamectl set-hostname rhcsa-lab.example.com"
ok "Hostname management demonstrated"

# ---------------------------------------------------------------------------
# Task 3: Firewall management
# ---------------------------------------------------------------------------
task "3 — Firewalld Management"

log "Firewall status:"
firewall-cmd --state 2>/dev/null || systemctl is-active firewalld

log "Default zone:"
firewall-cmd --get-default-zone 2>/dev/null || true

log "Active zones:"
firewall-cmd --get-active-zones 2>/dev/null || true

log "Current rules:"
firewall-cmd --list-all 2>/dev/null || true

# Add/remove a practice service
firewall-cmd --permanent --add-service=https 2>/dev/null && ok "HTTPS added"
firewall-cmd --permanent --add-port=8443/tcp 2>/dev/null && ok "Port 8443/tcp added"
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept' 2>/dev/null && ok "Rich rule added"

firewall-cmd --reload 2>/dev/null && ok "Firewall reloaded"

# Clean up practice rules
firewall-cmd --permanent --remove-service=https 2>/dev/null || true
firewall-cmd --permanent --remove-port=8443/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept' 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true
ok "Practice firewall rules cleaned"

# ---------------------------------------------------------------------------
# Task 4: SELinux for networking
# ---------------------------------------------------------------------------
task "4 — SELinux Network Booleans"

log "Common network-related SELinux booleans:"
getsebool -a 2>/dev/null | grep -E '(httpd|ssh|ftp|samba|nfs)' | head -15 || warn "SELinux booleans unavailable"

log "Example: setsebool -P httpd_can_network_connect on"
ok "SELinux booleans reviewed"

# ---------------------------------------------------------------------------
# Task 5: SSH key-based authentication
# ---------------------------------------------------------------------------
task "5 — SSH Key Management"

log "Generating SSH key pair for rhcsa_user1..."
if [[ ! -f /home/rhcsa_user1/.ssh/id_rsa ]]; then
	su - rhcsa_user1 -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null || true
	su - rhcsa_user1 -c "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N '' -q" 2>/dev/null || true
	su - rhcsa_user1 -c "cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null || true
	ok "SSH key pair generated for rhcsa_user1"
else
	log "SSH key already exists for rhcsa_user1"
fi

log "Authorized keys:"
cat /home/rhcsa_user1/.ssh/authorized_keys 2>/dev/null | head -1 || true

# ---------------------------------------------------------------------------
# Task 6: DNS and /etc/hosts
# ---------------------------------------------------------------------------
task "6 — DNS Configuration"

log "Current /etc/hosts:"
cat /etc/hosts

# Add practice entries (non-disruptive)
if ! grep -q "rhcsa-server" /etc/hosts; then
	echo "192.168.122.10  rhcsa-server.lab.example.com  rhcsa-server" >>/etc/hosts
	echo "192.168.122.11  rhcsa-client.lab.example.com  rhcsa-client" >>/etc/hosts
	ok "Practice DNS entries added"
fi

log "DNS resolution test:"
getent hosts rhcsa-server 2>/dev/null || true

# ---------------------------------------------------------------------------
# Task 7: Network diagnostics
# ---------------------------------------------------------------------------
task "7 — Network Diagnostics Tools"

log "Listening ports:"
ss -tulnp 2>/dev/null | head -15 || netstat -tulnp 2>/dev/null | head -15 || true

log "ARP table:"
ip neigh show 2>/dev/null || arp -n 2>/dev/null || true

log "Network connections:"
ss -tnp 2>/dev/null | head -10 || true

# ---------------------------------------------------------------------------
# Task 8: nmcli advanced (connection profiles)
# ---------------------------------------------------------------------------
task "8 — nmcli Practice"

log "Available nmcli commands to practice:"
echo "  nmcli connection show"
echo "  nmcli device status"
echo "  nmcli device show <interface>"
echo "  nmcli connection add type ethernet con-name <name> ifname <iface>"
echo "  nmcli connection modify <name> ipv4.addresses 192.168.1.100/24"
echo "  nmcli connection modify <name> ipv4.gateway 192.168.1.1"
echo "  nmcli connection modify <name> ipv4.dns 8.8.8.8"
echo "  nmcli connection up <name>"
ok "nmcli reference displayed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Networking Practice Complete                        ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Covered: nmcli, firewalld, SSH keys, DNS           ║${NC}"
echo -e "${BOLD}${GREEN}║  Practiced: diagnostics, SELinux booleans            ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Verification commands:${NC}"
echo "  nmcli con show"
echo "  ip addr show"
echo "  firewall-cmd --list-all"
echo "  ss -tulnp"
echo "  cat /etc/hosts"
