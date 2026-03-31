#!/usr/bin/env bash
#===============================================================================
# boot-practice.sh — RHCSA Boot Process & Kernel Practice
# Covers: GRUB, systemd targets, rescue mode, kernel params, fstab, dracut
# Usage : sudo bash boot-practice.sh
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
echo "║       RHCSA Practice Lab — Boot Process             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Task 1: Boot process overview
# ---------------------------------------------------------------------------
task "1 — Boot Process Analysis"

log "Kernel version: $(uname -r)"
log "Boot time analysis:"
systemd-analyze 2>/dev/null || true

log "Boot chain:"
systemd-analyze blame 2>/dev/null | head -15 || true

log "Critical chain:"
systemd-analyze critical-chain 2>/dev/null | head -15 || true

# ---------------------------------------------------------------------------
# Task 2: GRUB2 configuration
# ---------------------------------------------------------------------------
task "2 — GRUB2 Configuration"

if [[ -f /etc/default/grub ]]; then
	log "Current GRUB defaults:"
	grep -v '^#' /etc/default/grub | grep -v '^$' || true
fi

log "GRUB2 practice commands:"
echo "  # Add kernel parameter:"
echo "  grubby --update-kernel=ALL --args='rd.break'"
echo ""
echo "  # Remove kernel parameter:"
echo "  grubby --update-kernel=ALL --remove-args='rd.break'"
echo ""
echo "  # Set default kernel:"
echo "  grubby --set-default /boot/vmlinuz-<version>"
echo ""
echo "  # List kernels:"
echo "  grubby --info=ALL"
echo ""
echo "  # After changes, rebuild:"
echo "  grub2-mkconfig -o /boot/grub2/grub.cfg"
echo "     or on EFI:"
echo "  grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg"

ok "GRUB2 reference displayed"

# ---------------------------------------------------------------------------
# Task 3: System targets
# ---------------------------------------------------------------------------
task "3 — Systemd Targets"

log "Current target: $(systemctl get-default)"
log "Current runlevel equivalent: $(runlevel 2>/dev/null || echo 'N/A')"

log "Available targets:"
systemctl list-units --type=target --no-pager

log "Target practice:"
echo "  systemctl get-default              # Show default target"
echo "  systemctl set-default multi-user.target  # CLI only"
echo "  systemctl set-default graphical.target   # GUI"
echo "  systemctl isolate rescue.target     # Single-user mode"
echo "  systemctl isolate emergency.target  # Emergency shell"

ok "Targets reviewed"

# ---------------------------------------------------------------------------
# Task 4: /etc/fstab management
# ---------------------------------------------------------------------------
task "4 — /etc/fstab Management"

log "Current fstab:"
cat /etc/fstab
echo ""

log "fstab format: <device> <mount> <type> <options> <dump> <fsck>"
echo ""

log "Practice fstab entries:"
echo "  UUID=xxx  /data  xfs  defaults  0 0"
echo "  /dev/vg/lv  /home  ext4  defaults,usrquota  0 0"
echo "  //server/share  /mnt  cifs  credentials=/root/.smbcreds  0 0"
echo "  server:/export  /mnt  nfs  defaults,_netdev  0 0"
echo ""

log "Verification:"
echo "  mount -a          # Mount all from fstab"
echo "  findmnt           # Show mounted filesystems"
echo "  blkid             # Show block device UUIDs"

ok "fstab reviewed"

# ---------------------------------------------------------------------------
# Task 5: Reset root password (simulated)
# ---------------------------------------------------------------------------
task "5 — Root Password Reset Procedure"

log "Exam procedure (memorize this!):"
echo ""
echo "  1. Reboot, interrupt GRUB, press 'e' to edit"
echo "  2. Find 'linux' line, append: rd.break"
echo "  3. Ctrl+X to boot"
echo "  4. Mount sysroot read-write:"
echo "     mount -o remount,rw /sysroot"
echo "     chroot /sysroot"
echo "  5. Reset password:"
echo "     passwd root"
echo "  6. Relabel SELinux:"
echo "     touch /.autorelabel"
echo "  7. Exit and reboot:"
echo "     exit"
echo "     exit"
ok "Root password reset procedure reviewed"

# ---------------------------------------------------------------------------
# Task 6: Kernel module management
# ---------------------------------------------------------------------------
task "6 — Kernel Module Management"

log "Loaded modules count: $(lsmod | wc -l)"
log "Top loaded modules:"
lsmod | head -10

log "Module practice commands:"
echo "  lsmod                           # List loaded modules"
echo "  modprobe <module>               # Load module"
echo "  modprobe -r <module>            # Remove module"
echo "  modinfo <module>                # Module info"
echo "  echo '<module>' >> /etc/modules-load.d/<name>.conf  # Persist"
ok "Module management reviewed"

# ---------------------------------------------------------------------------
# Task 7: Dracut & initramfs
# ---------------------------------------------------------------------------
task "7 — Dracut & Initramfs"

if [[ -d /boot ]]; then
	log "Initramfs files:"
	ls -lh /boot/initramfs-* 2>/dev/null || ls -lh /boot/initrd-* 2>/dev/null || true
fi

log "Dracut practice:"
echo "  dracut --force /boot/initramfs-\$(uname -r).img \$(uname -r)"
echo "  dracut --add-drivers '<driver>' --force /boot/initramfs-custom.img \$(uname -r)"
ok "Dracut reviewed"

# ---------------------------------------------------------------------------
# Task 8: System rescue/emergency mode
# ---------------------------------------------------------------------------
task "8 — Rescue & Emergency Mode"

log "Entering rescue mode:"
echo "  systemctl isolate rescue.target"
echo "  # Or from GRUB: add 'systemd.unit=rescue.target'"

log "Entering emergency mode:"
echo "  systemctl isolate emergency.target"
echo "  # Or from GRUB: add 'systemd.unit=emergency.target'"

log "Alternative: reboot into rescue"
echo "  systemctl reboot --boot-loader-entry='rescue'"
ok "Rescue/emergency modes reviewed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Boot Process Practice Complete                     ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Covered: GRUB, targets, fstab, kernel, dracut      ║${NC}"
echo -e "${BOLD}${GREEN}║  Practiced: password reset, rescue mode, modules    ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
