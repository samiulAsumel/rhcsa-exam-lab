#!/usr/bin/env bash
#===============================================================================
# 01-system-update.sh — Full System Update
# Purpose : Update all packages, enable repositories, install essentials
# Usage   : sudo bash 01-system-update.sh
# Tested  : Rocky Linux 9.x / RHEL 9.x
#===============================================================================
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/rhcsa-lab-update-$(date +%Y%m%d-%H%M%S).log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
ok() { echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE"; }

if [[ $EUID -ne 0 ]]; then
	fail "Run as root"
	exit 1
fi

log "=========================================="
log " RHCSA Lab — System Update"
log "=========================================="

# ---------------------------------------------------------------------------
# 1. Enable required repositories
# ---------------------------------------------------------------------------
log "Enabling required repositories..."

# EPEL
if ! dnf repolist enabled 2>/dev/null | grep -q 'epel'; then
	dnf install -y epel-release >>"$LOG_FILE" 2>&1 || warn "EPEL not available"
fi

# CRB / PowerTools (needed for many dev packages)
if dnf repolist all 2>/dev/null | grep -q 'crb'; then
	dnf config-manager --set-enabled crb >>"$LOG_FILE" 2>&1 || true
elif dnf repolist all 2>/dev/null | grep -q 'powertools'; then
	dnf config-manager --set-enabled powertools >>"$LOG_FILE" 2>&1 || true
fi

ok "Repositories configured"

# ---------------------------------------------------------------------------
# 2. Full system update
# ---------------------------------------------------------------------------
log "Running full system update (this may take a while)..."
dnf upgrade -y --refresh >>"$LOG_FILE" 2>&1
ok "System fully updated"

# ---------------------------------------------------------------------------
# 3. Install essential RHCSA packages
# ---------------------------------------------------------------------------
RHCSA_PACKAGES=(
	# Core system administration
	vim-enhanced nano
	bash-completion
	man-pages
	tmux screen
	wget curl
	tar gzip bzip2 xz unzip
	lsof strace ltrace
	net-tools iproute iputils
	bind-utils traceroute
	rsync
	tree
	htop iotop
	sysstat
	# Storage & filesystem tools
	xfsprogs e2fsprogs
	lvm2
	mdadm
	parted
	# Networking
	NetworkManager-tui
	firewalld
	nmap-ncat
	# Security
	openssh-server openssh-clients
	policycoreutils-python-utils
	setools-console
	# Services
	chrony
	postfix
	httpd
	mod_ssl
	mariadb-server mariadb
	nfs-utils
	samba samba-client
	# SELinux
	selinux-policy-targeted
	# User management
	cracklib-dicts
	# Container basics
	podman buildah skopeo
	# Development (for practice)
	gcc make
	# Kickstart & system
	dracut-live
	# Misc
	expect
	jq
)

log "Installing RHCSA packages (${#RHCSA_PACKAGES[@]} packages)..."
dnf install -y "${RHCSA_PACKAGES[@]}" >>"$LOG_FILE" 2>&1 || warn "Some packages failed to install"
dnf install -y system-config-kickstart >>"$LOG_FILE" 2>&1 || warn "system-config-kickstart not available"
ok "Essential packages installed"

# ---------------------------------------------------------------------------
# 4. Configure system basics
# ---------------------------------------------------------------------------
log "Configuring system defaults..."

# Enable bash completion globally
if [[ -f /etc/profile.d/bash_completion.sh ]]; then
	chmod +x /etc/profile.d/bash_completion.sh 2>/dev/null || true
fi

# Set vim as default editor
if ! grep -q 'EDITOR=vim' /etc/environment 2>/dev/null; then
	echo 'EDITOR=vim' >>/etc/environment
	echo 'VISUAL=vim' >>/etc/environment
fi

# Enable color in bash prompt
if [[ -f /etc/bashrc ]] && ! grep -q 'force_color_prompt' /etc/bashrc; then
	sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /etc/bashrc 2>/dev/null || true
fi

ok "System defaults configured"

# ---------------------------------------------------------------------------
# 5. Enable essential services
# ---------------------------------------------------------------------------
log "Enabling essential services..."
SERVICES=(sshd chronyd firewalld)
for svc in "${SERVICES[@]}"; do
	systemctl enable "$svc" >>"$LOG_FILE" 2>&1 || warn "Could not enable $svc"
done
ok "Essential services enabled"

# ---------------------------------------------------------------------------
# 6. Set SELinux to enforcing (RHCSA exam standard)
# ---------------------------------------------------------------------------
log "Configuring SELinux..."
if command -v setenforce &>/dev/null; then
	setenforce 1 2>/dev/null || warn "Could not set SELinux to enforcing"
	if [[ -f /etc/selinux/config ]]; then
		sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
	fi
	ok "SELinux set to enforcing"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=========================================="
log " System update complete"
log " Packages : Installed"
log " SELinux  : Enforcing"
log " Services : sshd, chronyd, firewalld"
log " Log      : $LOG_FILE"
log "=========================================="
