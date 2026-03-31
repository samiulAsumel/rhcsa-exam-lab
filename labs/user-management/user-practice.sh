#!/usr/bin/env bash
#===============================================================================
# user-practice.sh — RHCSA User & Group Management Practice Lab
# Covers: users, groups, passwd, shadow, chage, sudoers, ACLs
# Usage : sudo bash user-practice.sh
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
echo "║       RHCSA Practice Lab — Users & Groups           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Task 1: Create users with specific UIDs and home dirs
# ---------------------------------------------------------------------------
task "1 — Create Users with Specific Parameters"

declare -A USER_CREATES=(
	["rhcsa_user1"]="1500"
	["rhcsa_user2"]="1501"
	["rhcsa_user3"]="1502"
	["service_acct"]="1600"
)

for user in "${!USER_CREATES[@]}"; do
	uid="${USER_CREATES[$user]}"
	if ! id "$user" &>/dev/null; then
		useradd -u "$uid" -m -s /bin/bash -c "RHCSA Practice User" "$user"
		echo "${user}:RedHat@123" | chpasswd
		chage -d 0 "$user"
		ok "Created $user (UID=$uid)"
	else
		log "User $user already exists"
	fi
done

# Create a system/service account (no login, no home)
if ! id service_acct &>/dev/null; then
	useradd -r -s /sbin/nologin -M -c "Service Account" service_acct
	ok "Created system account: service_acct"
fi

# ---------------------------------------------------------------------------
# Task 2: Create and manage groups
# ---------------------------------------------------------------------------
task "2 — Group Management"

declare -a GROUPS=("project_team" "sysadmin" "readonly" "audit")
for grp in "${GROUPS[@]}"; do
	if ! getent group "$grp" &>/dev/null; then
		groupadd "$grp"
		ok "Created group: $grp"
	fi
done

# Create a group with specific GID
if ! getent group shared_grp &>/dev/null; then
	groupadd -g 3000 shared_grp
	ok "Created group shared_grp (GID=3000)"
fi

# ---------------------------------------------------------------------------
# Task 3: Modify users — add to groups
# ---------------------------------------------------------------------------
task "3 — Add Users to Groups"

usermod -aG project_team,sysadmin rhcsa_user1
usermod -aG project_team,readonly rhcsa_user2
usermod -aG project_team,rhcsa_user3 rhcsa_user3 2>/dev/null || true
usermod -aG audit rhcsa_user3
ok "Group memberships updated"

log "Verify:"
groups rhcsa_user1
groups rhcsa_user2
groups rhcsa_user3

# ---------------------------------------------------------------------------
# Task 4: Password policies with chage
# ---------------------------------------------------------------------------
task "4 — Password Aging Policies"

chage -M 90 -m 7 -W 14 -I 30 rhcsa_user1
chage -M 60 -m 1 -W 7 -I 15 rhcsa_user2
chage -l rhcsa_user1 | head -8
ok "Password policies configured"

# ---------------------------------------------------------------------------
# Task 5: sudoers configuration
# ---------------------------------------------------------------------------
task "5 — Sudoers Configuration"

SUDOERS_FILE="/etc/sudoers.d/rhcsa-practice"
cat >"$SUDOERS_FILE" <<'SUDOERS'
# RHCSA Practice Sudoers
# Operator1: full sudo with password
rhcsa_user1  ALL=(ALL) ALL

# Operator2: only systemctl and dnf without password
rhcsa_user2  ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/dnf

# Project team: run specific commands
%project_team  ALL=(root) /usr/bin/journalctl, /usr/bin/dmesg

# Sysadmin group: full sudo
%sysadmin  ALL=(ALL) ALL
SUDOERS

chmod 440 "$SUDOERS_FILE"
visudo -cf /etc/sudoers && ok "Sudoers validated" || warn "Sudoers syntax error!"

# ---------------------------------------------------------------------------
# Task 6: File permissions (chmod, chown, chgrp)
# ---------------------------------------------------------------------------
task "6 — File Permissions Practice"

mkdir -p /data/permission-practice
cd /data/permission-practice

# Create practice files
cat >report.txt <<'EOF'
Quarterly Sales Report
======================
Q1: $1.2M
Q2: $1.5M
Q3: $1.8M
Q4: $2.1M
EOF

cat >script.sh <<'SCRIPT'
#!/bin/bash
echo "Maintenance script - authorized personnel only"
SCRIPT

# Set various permissions
chown rhcsa_user1:project_team report.txt
chmod 640 report.txt
ok "report.txt: owner=rhcsa_user1, group=project_team, mode=640"

chown rhcsa_user1:sysadmin script.sh
chmod 750 script.sh
ok "script.sh: owner=rhcsa_user1, group=sysadmin, mode=750"

# SGID on directory
chown root:project_team /data/permission-practice
chmod 2770 /data/permission-practice
ok "Directory set with SGID"

# Sticky bit
chmod +t /data/projects 2>/dev/null && ok "Sticky bit on /data/projects"

# umask demonstration
log "Default umask: $(umask)"

# ---------------------------------------------------------------------------
# Task 7: Access Control Lists (ACLs)
# ---------------------------------------------------------------------------
task "7 — Access Control Lists"

# Ensure the partition supports ACLs (most modern xfs/ext4 do)
touch /data/permission-practice/confidential.txt
chown root:root /data/permission-practice/confidential.txt
chmod 600 /data/permission-practice/confidential.txt

# Give rhcsa_user2 read access via ACL
setfacl -m u:rhcsa_user2:r-- /data/permission-practice/confidential.txt
ok "ACL: rhcsa_user2 can read confidential.txt"

# Give project_team read access
setfacl -m g:project_team:r-- /data/permission-practice/confidential.txt
ok "ACL: project_team can read confidential.txt"

# Set default ACL on directory
setfacl -d -m g:project_team:rwX /data/permission-practice
ok "Default ACL set on directory"

log "ACL verification:"
getfacl /data/permission-practice/confidential.txt

# ---------------------------------------------------------------------------
# Task 8: Lock/Unlock/Delete user
# ---------------------------------------------------------------------------
task "8 — User Account Management"

# Create temp user for practice
if ! id temp_practice &>/dev/null; then
	useradd temp_practice -m -s /bin/bash
	echo "temp_practice:RedHat@123" | chpasswd
	ok "Created temp_practice"
fi

passwd -l temp_practice && ok "Locked temp_practice"
passwd -u temp_practice && ok "Unlocked temp_practice"
userdel -r temp_practice && ok "Deleted temp_practice"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  User Management Practice Complete                  ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Created: users, groups, sudoers, ACLs, perms       ║${NC}"
echo -e "${BOLD}${GREEN}║  Users: rhcsa_user1/2/3 (pass: RedHat@123)          ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Verification commands:${NC}"
echo "  id rhcsa_user1"
echo "  groups rhcsa_user2"
echo "  chage -l rhcsa_user1"
echo "  sudo -l -U rhcsa_user1"
echo "  getfacl /data/permission-practice/confidential.txt"
echo "  ls -la /data/permission-practice/"
