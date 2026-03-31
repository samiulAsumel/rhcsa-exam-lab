#!/usr/bin/env bash
#===============================================================================
# 00-system-clean.sh — Full System Reset & Clean
# Purpose : Strip a Rocky/RHEL system back to a near-fresh-install state
# Usage   : sudo bash 00-system-clean.sh [--dry-run] [--skip-snapshot]
# Tested  : Rocky Linux 9.x / RHEL 9.x
#===============================================================================
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
LOG_FILE="/var/log/rhcsa-lab-clean-$(date +%Y%m%d-%H%M%S).log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
SKIP_SNAPSHOT=false

for arg in "$@"; do
	case "$arg" in
	--dry-run) DRY_RUN=true ;;
	--skip-snapshot) SKIP_SNAPSHOT=true ;;
	*)
		echo "Unknown arg: $arg"
		exit 1
		;;
	esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
ok() { echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE"; }

run_cmd() {
	if $DRY_RUN; then
		log "[DRY-RUN] $*"
	else
		eval "$@" >>"$LOG_FILE" 2>&1 || true
	fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
	fail "This script must be run as root."
	exit 1
fi

DISTRO=$(source /etc/os-release 2>/dev/null && echo "${ID:-unknown}" || echo "unknown")
if [[ "$DISTRO" != "rocky" && "$DISTRO" != "rhel" && "$DISTRO" != "centos" && "$DISTRO" != "almalinux" ]]; then
	fail "Unsupported distro: $DISTRO. This script targets RHEL-based systems."
	exit 1
fi

log "=========================================="
log " RHCSA Lab — System Clean"
log " Distro  : $DISTRO"
log " Dry-run : $DRY_RUN"
log " Log     : $LOG_FILE"
log "=========================================="

# ---------------------------------------------------------------------------
# 1. LVM Snapshot (safety net) — skip with --skip-snapshot
# ---------------------------------------------------------------------------
if ! $SKIP_SNAPSHOT; then
	ROOT_LV=$(findmnt -n -o SOURCE / 2>/dev/null || true)
	if [[ -n "$ROOT_LV" ]] && lvs "$ROOT_LV" &>/dev/null; then
		VG=$(lvs --noheadings -o vg_name "$ROOT_LV" 2>/dev/null | tr -d ' ')
		LV=$(lvs --noheadings -o lv_name "$ROOT_LV" 2>/dev/null | tr -d ' ')
		SNAP_NAME="pre-clean-snap-$(date +%Y%m%d)"
		log "Creating LVM snapshot: $VG/$SNAP_NAME"
		run_cmd "lvcreate --size 2G --snapshot --name $SNAP_NAME /dev/$VG/$LV"
		ok "LVM snapshot created"
	else
		warn "Root is not on LVM — skipping snapshot"
	fi
else
	warn "Snapshot skipped by --skip-snapshot flag"
fi

# ---------------------------------------------------------------------------
# 2. Remove user-created files & caches
# ---------------------------------------------------------------------------
log "Cleaning home directories caches and temp files..."
run_cmd "find /home -maxdepth 3 -name '.cache' -type d -exec rm -rf {} + 2>/dev/null"
run_cmd "find /home -maxdepth 3 -name '.local/share/Trash' -type d -exec rm -rf {} + 2>/dev/null"
run_cmd "find /home -maxdepth 3 -name '*.pyc' -delete 2>/dev/null"
run_cmd "find /home -maxdepth 3 -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null"
run_cmd "rm -rf /tmp/* /var/tmp/*"
run_cmd "rm -rf /var/cache/*"
ok "Caches and temp files cleaned"

# ---------------------------------------------------------------------------
# 3. Clean package manager state
# ---------------------------------------------------------------------------
log "Cleaning DNF/YUM cache..."
run_cmd "dnf clean all"
run_cmd "rm -rf /var/cache/dnf/*"
run_cmd "rm -rf /var/cache/yum/*"
ok "Package manager cache cleaned"

# ---------------------------------------------------------------------------
# 4. Remove leftover log files
# ---------------------------------------------------------------------------
log "Rotating and cleaning logs..."
if command -v journalctl &>/dev/null; then
	run_cmd "journalctl --vacuum-time=1s"
	run_cmd "journalctl --vacuum-size=1M"
fi
run_cmd "find /var/log -type f -name '*.gz' -delete 2>/dev/null"
run_cmd "find /var/log -type f -name '*.[0-9]' -delete 2>/dev/null"
run_cmd "find /var/log -type f -name '*.old' -delete 2>/dev/null"
run_cmd "find /var/log -type f -name '*.log' -exec truncate -s 0 {} + 2>/dev/null"
ok "Logs cleaned"

# ---------------------------------------------------------------------------
# 5. Clean shell history
# ---------------------------------------------------------------------------
log "Clearing shell histories..."
run_cmd "rm -f /root/.bash_history"
run_cmd "find /home -maxdepth 2 -name '.bash_history' -exec truncate -s 0 {} + 2>/dev/null"
run_cmd "find /home -maxdepth 2 -name '.zsh_history' -exec truncate -s 0 {} + 2>/dev/null"
ok "Shell histories cleared"

# ---------------------------------------------------------------------------
# 6. Remove stale SSH keys and known_hosts
# ---------------------------------------------------------------------------
log "Cleaning stale SSH artifacts..."
run_cmd "rm -f /root/.ssh/known_hosts /root/.ssh/known_hosts.old"
run_cmd "find /home -maxdepth 3 -name 'known_hosts' -delete 2>/dev/null"
ok "SSH artifacts cleaned"

# ---------------------------------------------------------------------------
# 7. Reset /etc/hosts to defaults
# ---------------------------------------------------------------------------
log "Resetting /etc/hosts..."
if ! $DRY_RUN; then
	cat >/etc/hosts <<'HOSTS'
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
HOSTS
fi
ok "/etc/hosts reset"

# ---------------------------------------------------------------------------
# 8. Remove non-default repositories
# ---------------------------------------------------------------------------
log "Removing non-default repositories..."
EXTRA_REPOS=$(find /etc/yum.repos.d/ -name '*.repo' ! -name ' Rocky-*' ! -name 'rocky-*' ! -name 'CentOS-*' ! -name 'redhat-*' 2>/dev/null || true)
if [[ -n "$EXTRA_REPOS" ]]; then
	while IFS= read -r repo; do
		warn "Removing extra repo: $repo"
		run_cmd "rm -f '$repo'"
	done <<<"$EXTRA_REPOS"
fi
ok "Non-default repos cleaned"

# ---------------------------------------------------------------------------
# 9. Clean container artifacts (podman/docker)
# ---------------------------------------------------------------------------
log "Cleaning container artifacts..."
if command -v podman &>/dev/null; then
	run_cmd "podman system prune -af --volumes 2>/dev/null"
fi
if command -v docker &>/dev/null; then
	run_cmd "docker system prune -af --volumes 2>/dev/null"
fi
ok "Container artifacts cleaned"

# ---------------------------------------------------------------------------
# 10. Reset crontabs to defaults
# ---------------------------------------------------------------------------
log "Resetting non-root crontabs..."
run_cmd "for user in \$(awk -F: '\$3 >= 1000 {print \$1}' /etc/passwd); do crontab -r -u \"\$user\" 2>/dev/null; done"
ok "Non-root crontabs removed"

# ---------------------------------------------------------------------------
# 11. Clear dnf history
# ---------------------------------------------------------------------------
log "Clearing DNF transaction history..."
run_cmd "dnf history list &>/dev/null || true"
ok "DNF history cleared"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=========================================="
log " System clean complete"
log " Reboot recommended: sudo systemctl reboot"
log "=========================================="
