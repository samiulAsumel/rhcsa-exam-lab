#!/usr/bin/env bash
#===============================================================================
# lab-reset.sh — Reset RHCSA Lab to Clean State
# Purpose : Remove all lab artifacts so practice can be repeated
# Usage   : sudo bash lab-reset.sh
#===============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${CYAN}[RESET]${NC} $*"; }
ok() { echo -e "${GREEN}[✓]${NC} $*"; }

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}Run as root${NC}"
	exit 1
fi

echo -e "${BOLD}${CYAN}Resetting RHCSA Lab Environment...${NC}\n"

# Remove lab users
for user in rhcsa_user1 rhcsa_user2 rhcsa_user3 operator1 operator2 operator3 devops adminuser webadmin dbadmin; do
	if id "$user" &>/dev/null; then
		userdel -r "$user" 2>/dev/null && ok "Removed user: $user"
	fi
done

# Remove lab groups
for grp in project_team sysadmin readonly audit shared_grp developers devops-team dba-team webteam project-alpha project-beta; do
	if getent group "$grp" &>/dev/null; then
		groupdel "$grp" 2>/dev/null && ok "Removed group: $grp"
	fi
done

# Remove LVM artifacts
umount /data/lvm-data 2>/dev/null || true
umount /data/lvm-home 2>/dev/null || true
swapoff /dev/rhcsa_vg01/rhcsa_lv_swap 2>/dev/null || true

lvremove -f /dev/rhcsa_vg01/rhcsa_lv_data 2>/dev/null || true
lvremove -f /dev/rhcsa_vg01/rhcsa_lv_home 2>/dev/null || true
lvremove -f /dev/rhcsa_vg01/rhcsa_lv_swap 2>/dev/null || true
lvremove -f /dev/rhcsa_vg01/rhcsa_lv_free 2>/dev/null || true
vgremove -f rhcsa_vg01 2>/dev/null || true
vgremove -f rhcsa_vg02 2>/dev/null || true

# Detach loop devices
for i in 1 2 3 4; do
	losetup -d "$(losetup -j /practice/lvm/disk${i}.img | cut -d: -f1)" 2>/dev/null || true
done

# Remove loopback files
rm -f /practice/lvm/disk*.img
ok "LVM artifacts cleaned"

# Remove custom directories
rm -rf /data/lvm-data /data/lvm-home /data/permission-practice
rm -rf /practice/chroot-test
ok "Practice directories cleaned"

# Remove sudoers file
rm -f /etc/sudoers.d/rhcsa-practice
ok "Sudoers cleaned"

# Remove custom services
for svc in rhcsa-hello rhcsa-backup rhcsa-limited rhcsa-masked rhcsa-container; do
	systemctl stop "${svc}.service" 2>/dev/null || true
	systemctl stop "${svc}.timer" 2>/dev/null || true
	systemctl disable "${svc}.service" 2>/dev/null || true
	systemctl disable "${svc}.timer" 2>/dev/null || true
	rm -f /etc/systemd/system/${svc}.service /etc/systemd/system/${svc}.timer
done
rm -f /usr/local/bin/rhcsa-hello.sh /usr/local/bin/rhcsa-backup.sh
systemctl daemon-reload
ok "Custom services cleaned"

# Restore fstab
if [[ -f /etc/fstab.lab-original ]]; then
	cp /etc/fstab.lab-original /etc/fstab
	ok "fstab restored"
fi

# Remove practice hosts entries
sed -i '/rhcsa-server/d; /rhcsa-client/d' /etc/hosts 2>/dev/null || true
ok "Hosts cleaned"

# Clean container artifacts
podman rm -f rhcsa-web rhcsa-app 2>/dev/null || true
podman volume rm rhcsa-data 2>/dev/null || true
podman network rm rhcsa-net 2>/dev/null || true
ok "Container artifacts cleaned"

echo ""
echo -e "${BOLD}${GREEN}Lab environment reset complete.${NC}"
echo -e "Run the setup script again to rebuild: sudo bash scripts/rhcsa-lab-setup.sh"
