#!/usr/bin/env bash
#===============================================================================
# service-practice.sh — RHCSA Systemd & Service Management Practice
# Covers: systemctl, unit files, timers, targets, boot process
# Usage : sudo bash service-practice.sh
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
echo "║       RHCSA Practice Lab — Services & Systemd       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Task 1: Service lifecycle
# ---------------------------------------------------------------------------
task "1 — Service Management (sshd, chronyd, firewalld)"

for svc in sshd chronyd firewalld; do
	systemctl is-enabled "$svc" &>/dev/null && log "$svc: enabled" || warn "$svc: not enabled"
	systemctl is-active "$svc" &>/dev/null && log "$svc: active" || warn "$svc: not active"
done

systemctl status sshd --no-pager -l | head -10
ok "Service status reviewed"

# ---------------------------------------------------------------------------
# Task 2: Create a custom systemd service
# ---------------------------------------------------------------------------
task "2 — Create Custom Systemd Service"

cat >/usr/local/bin/rhcsa-hello.sh <<'HELLO'
#!/bin/bash
while true; do
    echo "[$(date)] RHCSA Lab Service Running" >> /var/log/rhcsa-hello.log
    sleep 60
done
HELLO
chmod +x /usr/local/bin/rhcsa-hello.sh

cat >/etc/systemd/system/rhcsa-hello.service <<'UNIT'
[Unit]
Description=RHCSA Practice Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rhcsa-hello.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now rhcsa-hello.service
ok "Custom service rhcsa-hello.service created and started"

sleep 2
systemctl status rhcsa-hello.service --no-pager | head -12

# ---------------------------------------------------------------------------
# Task 3: Create a systemd timer
# ---------------------------------------------------------------------------
task "3 — Create Systemd Timer"

cat >/usr/local/bin/rhcsa-backup.sh <<'BACKUP'
#!/bin/bash
echo "[$(date)] Backup completed" >> /var/log/rhcsa-backup.log
BACKUP
chmod +x /usr/local/bin/rhcsa-backup.sh

cat >/etc/systemd/system/rhcsa-backup.service <<'SVC'
[Unit]
Description=RHCSA Backup Service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rhcsa-backup.sh
SVC

cat >/etc/systemd/system/rhcsa-backup.timer <<'TIMER'
[Unit]
Description=Run RHCSA backup hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now rhcsa-backup.timer
ok "Timer rhcsa-backup.timer configured (hourly)"

systemctl list-timers --no-pager | grep rhcsa || true

# ---------------------------------------------------------------------------
# Task 4: Systemd targets
# ---------------------------------------------------------------------------
task "4 — System Targets"

log "Current default target: $(systemctl get-default)"

# Show available targets
log "Available targets:"
systemctl list-units --type=target --no-pager | head -10

# ---------------------------------------------------------------------------
# Task 5: Resource control with systemd (cgroups)
# ---------------------------------------------------------------------------
task "5 — Resource Control (slice/unit limits)"

# Create a service with resource limits
cat >/etc/systemd/system/rhcsa-limited.service <<'LIMITED'
[Unit]
Description=Resource Limited Service

[Service]
Type=simple
ExecStart=/usr/bin/sleep 3600
MemoryMax=100M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
LIMITED

systemctl daemon-reload
ok "Resource-limited service created"

# ---------------------------------------------------------------------------
# Task 6: Dependency management
# ---------------------------------------------------------------------------
task "6 — Service Dependencies"

log "sshd dependencies:"
systemctl list-dependencies sshd --no-pager | head -15
ok "Dependencies reviewed"

# ---------------------------------------------------------------------------
# Task 7: Journal (journalctl) practice
# ---------------------------------------------------------------------------
task "7 — Journal Management"

log "Last 10 log entries:"
journalctl -n 10 --no-pager

log "Logs from today:"
journalctl --since today --no-pager | tail -5

log "Kernel messages:"
journalctl -k --no-pager | tail -5

log "Disk usage:"
journalctl --disk-usage

ok "Journal commands demonstrated"

# ---------------------------------------------------------------------------
# Task 8: Masking services
# ---------------------------------------------------------------------------
task "8 — Masking & Unmasking Services"

# Create a service to mask
cat >/etc/systemd/system/rhcsa-masked.service <<'MASKED'
[Unit]
Description=Service to be masked

[Service]
Type=simple
ExecStart=/usr/bin/sleep 3600

[Install]
WantedBy=multi-user.target
MASKED
systemctl daemon-reload

systemctl mask rhcsa-masked.service && ok "Masked rhcsa-masked.service"
systemctl unmask rhcsa-masked.service && ok "Unmasked rhcsa-masked.service"

# ---------------------------------------------------------------------------
# Cleanup practice services (optional)
# ---------------------------------------------------------------------------
task "Cleanup"

echo -n "Remove practice services? (y/N): "
read -r CLEANUP
if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
	systemctl stop rhcsa-hello.service 2>/dev/null || true
	systemctl disable rhcsa-hello.service 2>/dev/null || true
	systemctl disable --now rhcsa-backup.timer 2>/dev/null || true
	rm -f /etc/systemd/system/rhcsa-hello.service
	rm -f /etc/systemd/system/rhcsa-backup.service
	rm -f /etc/systemd/system/rhcsa-backup.timer
	rm -f /etc/systemd/system/rhcsa-limited.service
	rm -f /etc/systemd/system/rhcsa-masked.service
	rm -f /usr/local/bin/rhcsa-hello.sh /usr/local/bin/rhcsa-backup.sh
	systemctl daemon-reload
	ok "Practice services cleaned up"
else
	log "Practice services kept"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Systemd Practice Complete                           ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Created: services, timers, resource limits          ║${NC}"
echo -e "${BOLD}${GREEN}║  Practiced: journalctl, targets, dependencies        ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Verification commands:${NC}"
echo "  systemctl list-units --type=service --state=running"
echo "  systemctl list-timers"
echo "  journalctl -u rhcsa-hello -f"
echo "  systemctl get-default"
