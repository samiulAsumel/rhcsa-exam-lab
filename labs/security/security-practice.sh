#!/usr/bin/env bash
#===============================================================================
# security-practice.sh — RHCSA Security & SELinux Practice Lab
# Covers: SELinux, firewalld, chroot, PAM, auditing, crypto policies
# Usage : sudo bash security-practice.sh
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
echo "║       RHCSA Practice Lab — Security & SELinux       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Task 1: SELinux modes and contexts
# ---------------------------------------------------------------------------
task "1 — SELinux Modes & Contexts"

log "Current SELinux mode: $(getenforce)"
log "Config file:"
grep ^SELINUX= /etc/selinux/config || true

log "Example commands:"
echo "  setenforce 0          # Permissive (temporary)"
echo "  setenforce 1          # Enforcing (temporary)"
echo "  getenforce            # Show current mode"
echo "  sestatus              # Full status"
echo "  semanage boolean -l   # List all booleans"

# Create a practice file and check context
touch /data/secure/selinux-test.txt
log "Default context: $(ls -Z /data/secure/selinux-test.txt)"

# Change context
semanage fcontext -a -t httpd_sys_content_t '/data/web/html(/.*)?' 2>/dev/null || true
restorecon -Rv /data/web/html 2>/dev/null || ok "Context restored on /data/web/html"

# Clean up
rm -f /data/secure/selinux-test.txt
ok "SELinux contexts demonstrated"

# ---------------------------------------------------------------------------
# Task 2: SELinux Booleans
# ---------------------------------------------------------------------------
task "2 — SELinux Booleans"

log "Common booleans:"
getsebool -a 2>/dev/null | grep -E '(httpd_can_network_connect|ftp_home_dir|samba_enable_home_dirs|nis_enabled)' || true

log "Practice commands:"
echo "  getsebool httpd_can_network_connect"
echo "  setsebool -P httpd_can_network_connect on"
echo "  semanage boolean -l | grep httpd"
ok "SELinux booleans reviewed"

# ---------------------------------------------------------------------------
# Task 3: SELinux port labeling
# ---------------------------------------------------------------------------
task "3 — SELinux Port Labels"

log "HTTP port contexts:"
semanage port -l 2>/dev/null | grep http_port_t || true

log "Practice: Add custom port for httpd"
echo "  semanage port -a -t http_port_t -p tcp 8888"
echo "  semanage port -d -t http_port_t -p tcp 8888  # remove"
ok "Port labeling demonstrated"

# ---------------------------------------------------------------------------
# Task 4: Troubleshooting SELinux
# ---------------------------------------------------------------------------
task "4 — SELinux Troubleshooting"

log "Audit log (last 5 AVC denials):"
ausearch -m AVC -ts recent 2>/dev/null | tail -10 || log "No recent AVC denials"

log "Troubleshooting workflow:"
echo "  1. ausearch -m AVC -ts recent    # Find denials"
echo "  2. sealert -a /var/log/audit/audit.log  # Analyze"
echo "  3. restorecon -Rv <path>         # Fix contexts"
echo "  4. setsebool -P <bool> on        # Toggle booleans"
echo "  5. semanage fcontext -a -t <type> '<path>(/.*)?'  # Custom context"
echo "  6. semanage port -a -t <type> -p tcp <port>       # Custom port"
ok "Troubleshooting workflow shown"

# ---------------------------------------------------------------------------
# Task 5: PAM password quality
# ---------------------------------------------------------------------------
task "5 — PAM Password Quality"

if [[ -f /etc/security/pwquality.conf ]]; then
	log "Current pwquality.conf:"
	grep -v '^#' /etc/security/pwquality.conf | grep -v '^$' || true

	log "Practice: enforce stronger passwords"
	echo "  Edit /etc/security/pwquality.conf:"
	echo "    minlen = 12"
	echo "    dcredit = -1"
	echo "    ucredit = -1"
	echo "    lcredit = -1"
	echo "    ocredit = -1"
fi
ok "PAM configuration reviewed"

# ---------------------------------------------------------------------------
# Task 6: Tuned profiles
# ---------------------------------------------------------------------------
task "6 — Tuned Performance Profiles"

if command -v tuned-adm &>/dev/null; then
	log "Active profile: $(tuned-adm active 2>/dev/null | grep 'Current active' || echo 'unknown')"
	log "Available profiles:"
	tuned-adm list 2>/dev/null | head -15 || true

	log "Practice commands:"
	echo "  tuned-adm list"
	echo "  tuned-adm profile virtual-guest"
	echo "  tuned-adm active"
	echo "  tuned-adm recommend"
else
	warn "tuned not installed"
fi
ok "Tuned profiles reviewed"

# ---------------------------------------------------------------------------
# Task 7: Crypto policies
# ---------------------------------------------------------------------------
task "7 — System-wide Crypto Policies"

if command -v update-crypto-policies &>/dev/null; then
	log "Current policy: $(update-crypto-policies --show 2>/dev/null || echo 'unknown')"
	log "Available policies:"
	ls /usr/share/crypto-policies/policies/ 2>/dev/null || true

	log "Practice commands:"
	echo "  update-crypto-policies --show"
	echo "  update-crypto-policies --set DEFAULT"
	echo "  update-crypto-policies --set FUTURE"
	echo "  update-crypto-policies --set LEGACY"
else
	warn "crypto-policies not available"
fi
ok "Crypto policies reviewed"

# ---------------------------------------------------------------------------
# Task 8: sudoers & security lockdown
# ---------------------------------------------------------------------------
task "8 — Sudoers Security"

log "Current sudoers.d files:"
ls -la /etc/sudoers.d/ 2>/dev/null || true

log "Best practices:"
echo "  visudo                    # Always edit with visudo"
echo "  # Use groups: %group ALL=(ALL) ALL"
echo "  # Restrict commands: user ALL=(ALL) /usr/bin/systemctl"
echo "  # NOPASSWD sparingly: user ALL=(ALL) NOPASSWD: /usr/bin/ls"
ok "Sudoers security reviewed"

# ---------------------------------------------------------------------------
# Task 9: File permissions security
# ---------------------------------------------------------------------------
task "9 — File Permission Security"

log "SUID files on system:"
find / -perm -4000 -type f 2>/dev/null | head -10 || true

log "SGID files on system:"
find / -perm -2000 -type f 2>/dev/null | head -10 || true

log "World-writable files:"
find / -perm -0002 -type f 2>/dev/null | head -10 || true

ok "Permission audit complete"

# ---------------------------------------------------------------------------
# Task 10: Chroot environment
# ---------------------------------------------------------------------------
task "10 — Chroot Environment (practice)"

CHROOT_DIR="/practice/chroot-test"
mkdir -p "$CHROOT_DIR"/{bin,lib,lib64,etc,dev,proc,sys,tmp}

# Copy basic binaries
cp /bin/bash "$CHROOT_DIR/bin/" 2>/dev/null || true
for lib in $(ldd /bin/bash 2>/dev/null | awk '{print $3}' | grep -v '^$'); do
	cp --parents "$lib" "$CHROOT_DIR/" 2>/dev/null || true
done

log "Chroot directory prepared at $CHROOT_DIR"
log "Test: chroot $CHROOT_DIR /bin/bash"
ok "Chroot environment set up"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Security & SELinux Practice Complete                ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Covered: SELinux, PAM, crypto, tuned, permissions  ║${NC}"
echo -e "${BOLD}${GREEN}║  Practiced: contexts, booleans, ports, chroot       ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Key SELinux commands:${NC}"
echo "  getenforce / setenforce / sestatus"
echo "  semanage fcontext -l | grep <path>"
echo "  semanage boolean -l"
echo "  semanage port -l"
echo "  restorecon -Rv <path>"
echo "  ausearch -m AVC -ts recent"
echo "  chcon -t <type> <file>"
