#!/usr/bin/env bash
#===============================================================================
# rhcsa-lab-setup.sh — Master RHCSA Exam Lab Environment Builder
# Purpose : Configure a complete RHCSA EX200 practice lab
# Usage   : sudo bash rhcsa-lab-setup.sh [--skip-clean] [--skip-update] [--lab-only]
# Tested  : Rocky Linux 9.x / RHEL 9.x
#===============================================================================
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/rhcsa-lab-setup-$(date +%Y%m%d-%H%M%S).log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SKIP_CLEAN=false
SKIP_UPDATE=false
LAB_ONLY=false

for arg in "$@"; do
	case "$arg" in
	--skip-clean) SKIP_CLEAN=true ;;
	--skip-update) SKIP_UPDATE=true ;;
	--lab-only) LAB_ONLY=true ;;
	--help | -h)
		echo "Usage: sudo bash rhcsa-lab-setup.sh [OPTIONS]"
		echo "  --skip-clean   Skip system cleanup"
		echo "  --skip-update  Skip system update"
		echo "  --lab-only     Only set up lab environment"
		exit 0
		;;
	*)
		echo "Unknown: $arg"
		exit 1
		;;
	esac
done

log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
ok() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; }
title() {
	echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
	echo -e "${BOLD}${CYAN}  $*${NC}" | tee -a "$LOG_FILE"
	echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
	fail "Run as root: sudo bash rhcsa-lab-setup.sh"
	exit 1
fi

title "RHCSA EX200 Lab Environment Setup"
log "Log file: $LOG_FILE"

# ==========================================================================
# Phase 1: System Clean
# ==========================================================================
if ! $SKIP_CLEAN && ! $LAB_ONLY; then
	title "Phase 1/4 — System Clean"
	bash "${SCRIPT_DIR}/00-system-clean.sh"
	ok "System cleaned"
else
	log "Skipping system clean"
fi

# ==========================================================================
# Phase 2: System Update
# ==========================================================================
if ! $SKIP_UPDATE && ! $LAB_ONLY; then
	title "Phase 2/4 — System Update"
	bash "${SCRIPT_DIR}/01-system-update.sh"
	ok "System updated"
else
	log "Skipping system update"
fi

# ==========================================================================
# Phase 3: Lab Environment Setup
# ==========================================================================
title "Phase 3/4 — Lab Environment Configuration"

# --- 3.1 Create lab user accounts ---
log "Creating lab user accounts..."
LAB_USERS=(operator1 operator2 operator3 devops adminuser webadmin dbadmin)
for user in "${LAB_USERS[@]}"; do
	if ! id "$user" &>/dev/null; then
		useradd "$user" -m -s /bin/bash -c "RHCSA Lab User"
		echo "${user}:Password@123" | chpasswd
		# Force password change on first login
		chage -d 0 "$user" 2>/dev/null || true
		log "  Created user: $user"
	else
		log "  User exists: $user"
	fi
done
ok "Lab user accounts created"

# --- 3.2 Create supplementary groups ---
log "Creating supplementary groups..."
GROUPS_TO_CREATE=(developers devops-team dba-team webteam project-alpha project-beta)
for grp in "${GROUPS_TO_CREATE[@]}"; do
	if ! getent group "$grp" &>/dev/null; then
		groupadd "$grp"
		log "  Created group: $grp"
	fi
done
ok "Supplementary groups created"

# --- 3.3 Configure group memberships ---
log "Configuring group memberships..."
usermod -aG developers,project-alpha operator1
usermod -aG developers,project-alpha operator2
usermod -aG devops-team,project-beta operator3
usermod -aG developers,devops-team devops
usermod -aG webteam adminuser
usermod -aG webteam,developers webadmin
usermod -aG dba-team dbadmin
ok "Group memberships configured"

# --- 3.4 Create directory structures ---
log "Creating lab directory structure..."
DIRS=(
	/data
	/data/projects
	/data/shared
	/data/secure
	/data/web
	/data/web/html
	/data/web/logs
	/data/db
	/data/backups
	/data/scripts
	/practice
	/practice/lvm
	/practice/nfs
	/practice/samba
	/practice/timed
	/practice/containers
	/practice/networking
	/practice/security
)
for dir in "${DIRS[@]}"; do
	mkdir -p "$dir"
done
ok "Directory structure created"

# --- 3.5 Set up shared directory with SGID ---
log "Configuring shared directories..."
chown root:developers /data/shared
chmod 2770 /data/shared
chown root:webteam /data/web/html
chmod 2775 /data/web
chown root:dba-team /data/db
chmod 2770 /data/db
chown root:root /data/backups
chmod 750 /data/backups
ok "Shared directories configured with proper permissions"

# --- 3.6 Set up sticky bit example ---
chmod 1777 /data/projects
ok "Sticky bit set on /data/projects"

# --- 3.7 Create loopback files for LVM practice ---
log "Creating loopback files for LVM practice..."
for i in 1 2 3 4; do
	if [[ ! -f /practice/lvm/disk${i}.img ]]; then
		dd if=/dev/zero of=/practice/lvm/disk${i}.img bs=1M count=256 status=none
		ok "Created /practice/lvm/disk${i}.img (256M)"
	fi
done

# Set up loop devices
for i in 1 2 3 4; do
	if ! losetup -a | grep -q "disk${i}.img"; then
		losetup -fP /practice/lvm/disk${i}.img 2>/dev/null || true
	fi
done
ok "Loop devices configured for LVM practice"

# --- 3.8 Configure chronyd (NTP) ---
log "Configuring time synchronization..."
systemctl enable --now chronyd >>"$LOG_FILE" 2>&1
chronyc makestep >>"$LOG_FILE" 2>&1 || true
ok "Time synchronization configured"

# --- 3.9 Configure SSH hardening ---
log "Configuring SSH..."
if [[ -f /etc/ssh/sshd_config ]]; then
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)
	# Allow password auth for lab (exam environment)
	sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
	sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
	systemctl restart sshd >>"$LOG_FILE" 2>&1
fi
ok "SSH configured"

# --- 3.10 Configure firewalld ---
log "Configuring firewall..."
systemctl enable --now firewalld >>"$LOG_FILE" 2>&1
firewall-cmd --permanent --add-service=ssh >>"$LOG_FILE" 2>&1
firewall-cmd --permanent --add-service=http >>"$LOG_FILE" 2>&1
firewall-cmd --permanent --add-service=https >>"$LOG_FILE" 2>&1
firewall-cmd --permanent --add-service=nfs >>"$LOG_FILE" 2>&1
firewall-cmd --permanent --add-service=samba >>"$LOG_FILE" 2>&1
firewall-cmd --reload >>"$LOG_FILE" 2>&1
ok "Firewall configured"

# --- 3.11 Configure autofs practice directories ---
log "Creating autofs practice directories..."
mkdir -p /practice/autofs/{auto.master.d,exports}
ok "Autofs directories created"

# --- 3.12 Create tuning profiles ---
if command tuned-adm &>/dev/null; then
	log "Configuring tuned profiles..."
	tuned-adm profile virtual-guest >>"$LOG_FILE" 2>&1 || true
fi

# --- 3.13 Set up /etc/fstab backup ---
cp /etc/fstab /etc/fstab.lab-original
ok "Original fstab backed up"

# ==========================================================================
# Phase 4: Verification
# ==========================================================================
title "Phase 4/4 — Verification"

echo -e "${BOLD}System Info:${NC}"
echo "  Distro   : $(
	source /etc/os-release
	echo "$PRETTY_NAME"
)"
echo "  Kernel   : $(uname -r)"
echo "  SELinux  : $(getenforce 2>/dev/null || echo 'unknown')"
echo "  Firewall : $(systemctl is-active firewalld 2>/dev/null || echo 'unknown')"
echo ""
echo -e "${BOLD}Lab Users:${NC}"
for user in "${LAB_USERS[@]}"; do
	if id "$user" &>/dev/null; then
		echo "  ✓ $user"
	else
		echo "  ✗ $user (missing)"
	fi
done
echo ""
echo -e "${BOLD}Practice Directories:${NC}"
for dir in /data /practice; do
	if [[ -d "$dir" ]]; then
		echo "  ✓ $dir"
	else
		echo "  ✗ $dir (missing)"
	fi
done
echo ""
echo -e "${BOLD}Loopback Devices:${NC}"
losetup -a 2>/dev/null | grep disk || echo "  No loop devices"

title "Setup Complete"
log "=========================================="
log " RHCSA Lab Environment Ready!"
log " All lab users have password: Password@123"
log " Force password change enabled on first login"
log " Practice dirs: /data, /practice"
log " Log: $LOG_FILE"
log "=========================================="
log ""
log "Run practice labs:"
log "  bash ${SCRIPT_DIR}/../labs/storage-management/lvm-practice.sh"
log "  bash ${SCRIPT_DIR}/../labs/user-management/user-practice.sh"
log "  bash ${SCRIPT_DIR}/../labs/systemd-services/service-practice.sh"
log "  bash ${SCRIPT_DIR}/../labs/networking/network-practice.sh"
log "  bash ${SCRIPT_DIR}/../labs/security/security-practice.sh"
