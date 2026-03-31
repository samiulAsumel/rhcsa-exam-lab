#!/usr/bin/env bash
#===============================================================================
# lvm-practice.sh — RHCSA LVM & Storage Practice Lab
# Covers: LVM, PV, VG, LV, xfs, ext4, swap, fstab, quotas
# Usage : sudo bash lvm-practice.sh
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
echo "║       RHCSA Practice Lab — LVM & Storage            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Task 1: Create Physical Volumes
# ---------------------------------------------------------------------------
task "1 — Create Physical Volumes"

DISKS=()
for i in 1 2 3; do
	LOOP=$(losetup -j /practice/lvm/disk${i}.img | cut -d: -f1)
	if [[ -n "$LOOP" ]]; then
		DISKS+=("$LOOP")
		log "Found loop device: $LOOP for disk${i}.img"
	fi
done

if [[ ${#DISKS[@]} -lt 2 ]]; then
	warn "Need at least 2 loop devices. Setting them up..."
	for i in 1 2 3; do
		LOOP=$(losetup -fP --show /practice/lvm/disk${i}.img 2>/dev/null || true)
		[[ -n "$LOOP" ]] && DISKS+=("$LOOP")
	done
fi

if [[ ${#DISKS[@]} -ge 2 ]]; then
	for disk in "${DISKS[@]}"; do
		if ! pvs "$disk" &>/dev/null; then
			pvcreate "$disk" && ok "PV created on $disk"
		else
			log "PV already exists on $disk"
		fi
	done

	echo ""
	log "Current Physical Volumes:"
	pvs 2>/dev/null || pvdisplay -C 2>/dev/null || true
else
	warn "Insufficient disks for LVM practice"
fi

# ---------------------------------------------------------------------------
# Task 2: Create Volume Groups
# ---------------------------------------------------------------------------
task "2 — Create Volume Groups"

if [[ ${#DISKS[@]} -ge 2 ]]; then
	if ! vgs rhcsa_vg01 &>/dev/null; then
		vgcreate rhcsa_vg01 "${DISKS[0]}" "${DISKS[1]}" && ok "VG rhcsa_vg01 created"
	else
		log "VG rhcsa_vg01 already exists"
	fi

	if [[ ${#DISKS[@]} -ge 3 ]]; then
		if ! vgs rhcsa_vg02 &>/dev/null; then
			vgcreate -s 8M rhcsa_vg02 "${DISKS[2]}" && ok "VG rhcsa_vg02 created (8M PE)"
		fi
	fi

	echo ""
	log "Current Volume Groups:"
	vgs 2>/dev/null || vgdisplay -C 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Task 3: Create Logical Volumes
# ---------------------------------------------------------------------------
task "3 — Create Logical Volumes"

if vgs rhcsa_vg01 &>/dev/null; then
	# xfs LV
	if ! lvs rhcsa_vg01/rhcsa_lv_data &>/dev/null; then
		lvcreate -L 200M -n rhcsa_lv_data rhcsa_vg01 && ok "LV rhcsa_lv_data (200M)"
	fi

	# ext4 LV
	if ! lvs rhcsa_vg01/rhcsa_lv_home &>/dev/null; then
		lvcreate -L 150M -n rhcsa_lv_home rhcsa_vg01 && ok "LV rhcsa_lv_home (150M)"
	fi

	# Swap LV
	if ! lvs rhcsa_vg01/rhcsa_lv_swap &>/dev/null; then
		lvcreate -L 64M -n rhcsa_lv_swap rhcsa_vg01 && ok "LV rhcsa_lv_swap (64M)"
	fi

	# 100% FREE LV
	if ! lvs rhcsa_vg01/rhcsa_lv_free &>/dev/null; then
		lvcreate -l 100%FREE -n rhcsa_lv_free rhcsa_vg01 && ok "LV rhcsa_lv_free (100% FREE)"
	fi

	echo ""
	log "Current Logical Volumes:"
	lvs 2>/dev/null || lvdisplay -C 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Task 4: Format Filesystems
# ---------------------------------------------------------------------------
task "4 — Format Filesystems"

if [[ -b /dev/rhcsa_vg01/rhcsa_lv_data ]]; then
	if ! blkid /dev/rhcsa_vg01/rhcsa_lv_data | grep -q xfs; then
		mkfs.xfs /dev/rhcsa_vg01/rhcsa_lv_data && ok "Formatted xfs on rhcsa_lv_data"
	fi
fi

if [[ -b /dev/rhcsa_vg01/rhcsa_lv_home ]]; then
	if ! blkid /dev/rhcsa_vg01/rhcsa_lv_home | grep -q ext4; then
		mkfs.ext4 /dev/rhcsa_vg01/rhcsa_lv_home && ok "Formatted ext4 on rhcsa_lv_home"
	fi
fi

if [[ -b /dev/rhcsa_vg01/rhcsa_lv_swap ]]; then
	if ! blkid /dev/rhcsa_vg01/rhcsa_lv_swap | grep -q swap; then
		mkswap /dev/rhcsa_vg01/rhcsa_lv_swap && ok "Formatted swap on rhcsa_lv_swap"
	fi
fi

# ---------------------------------------------------------------------------
# Task 5: Mount & Persistent Mount via /etc/fstab
# ---------------------------------------------------------------------------
task "5 — Mount & Configure /etc/fstab"

mkdir -p /data/lvm-data /data/lvm-home

if ! mountpoint -q /data/lvm-data; then
	mount /dev/rhcsa_vg01/rhcsa_lv_data /data/lvm-data && ok "Mounted rhcsa_lv_data"
fi

if ! mountpoint -q /data/lvm-home; then
	mount /dev/rhcsa_vg01/rhcsa_lv_home /data/lvm-home && ok "Mounted rhcsa_lv_home"
fi

# Add to fstab if not present
for entry in \
	"/dev/rhcsa_vg01/rhcsa_lv_data /data/lvm-data xfs defaults 0 0" \
	"/dev/rhcsa_vg01/rhcsa_lv_home /data/lvm-home ext4 defaults 0 0" \
	"/dev/rhcsa_vg01/rhcsa_lv_swap none swap defaults 0 0"; do
	if ! grep -qF "$(echo "$entry" | awk '{print $1}')" /etc/fstab; then
		echo "$entry" >>/etc/fstab
		ok "Added to fstab: $(echo "$entry" | awk '{print $2}')"
	fi
done

log "Verifying fstab entries:"
grep -E '(rhcsa_lv|lvm-)' /etc/fstab || true

# ---------------------------------------------------------------------------
# Task 6: Extend a Logical Volume
# ---------------------------------------------------------------------------
task "6 — Extend Logical Volume"

if [[ -b /dev/rhcsa_vg01/rhcsa_lv_data ]]; then
	CURRENT_SIZE=$(lvs --noheadings --nosuffix -o lv_size /dev/rhcsa_vg01/rhcsa_lv_data 2>/dev/null | tr -d ' ')
	log "Current size of rhcsa_lv_data: ${CURRENT_SIZE}M"

	if lvextend -L +50M /dev/rhcsa_vg01/rhcsa_lv_data 2>/dev/null; then
		xfs_growfs /data/lvm-data 2>/dev/null || resize2fs /dev/rhcsa_vg01/rhcsa_lv_data 2>/dev/null || true
		ok "Extended rhcsa_lv_data by 50M and resized filesystem"
	else
		warn "Could not extend (not enough free space?)"
	fi
fi

# ---------------------------------------------------------------------------
# Task 7: Swap Management
# ---------------------------------------------------------------------------
task "7 — Swap Management"

if [[ -b /dev/rhcsa_vg01/rhcsa_lv_swap ]]; then
	if ! swapon --show | grep -q rhcsa_lv_swap; then
		swapon /dev/rhcsa_vg01/rhcsa_lv_swap && ok "Swap activated on rhcsa_lv_swap"
	fi
fi

echo ""
log "Current swap status:"
swapon --show || free -h

# ---------------------------------------------------------------------------
# Task 8: Disk Quotas (bonus)
# ---------------------------------------------------------------------------
task "8 — Disk Quotas (bonus)"

if mountpoint -q /data/lvm-home; then
	if ! mount | grep '/data/lvm-home' | grep -q 'usrquota'; then
		mount -o remount,usrquota,grpquota /data/lvm-home 2>/dev/null || true
		# Update fstab with quota options
		sed -i "\|/data/lvm-home|s|defaults|defaults,usrquota,grpquota|" /etc/fstab
		ok "Quota mount options set on /data/lvm-home"
	fi

	if command -v quotacheck &>/dev/null; then
		quotacheck -cug /data/lvm-home 2>/dev/null || warn "quotacheck failed"
		quotaon /data/lvm-home 2>/dev/null || warn "quotaon failed"
		ok "Disk quotas initialized"
	fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  LVM Practice Lab Complete                          ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Created: PVs, VGs, LVs, xfs, ext4, swap           ║${NC}"
echo -e "${BOLD}${GREEN}║  Practiced: mount, fstab, extend, quotas            ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Verification commands:${NC}"
echo "  pvs / vgs / lvs"
echo "  df -hT /data/lvm-data /data/lvm-home"
echo "  swapon --show"
echo "  grep lvm /etc/fstab"
