#!/usr/bin/env bash
#===============================================================================
# exam-simulate.sh — RHCSA EX200 Exam Simulation (RHEL 9 Standard)
# Purpose : Randomized timed practice exam with auto-scoring
# Usage   : sudo bash exam-simulate.sh [OPTIONS]
# Options : --score     Score completed exam
#           --reset     Reset exam artifacts
#           --list      List all available questions
#           --count N   Number of questions (default 15)
# Duration: 2.5 hours (150 minutes) — matching real RHCSA exam
#===============================================================================
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCORE_FILE="/var/log/rhcsa-exam-scores.log"
EXAM_FILE="/var/log/rhcsa-exam-current.log"
QUESTION_COUNT=15

log() { echo -e "${CYAN}[EXAM]${NC} $*"; }
ok() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Parse arguments
ACTION="start"
while [[ $# -gt 0 ]]; do
	case "$1" in
	--score)
		ACTION="score"
		shift
		;;
	--reset)
		ACTION="reset"
		shift
		;;
	--list)
		ACTION="list"
		shift
		;;
	--count)
		QUESTION_COUNT="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}Run as root${NC}"
	exit 1
fi

# ==========================================================================
# QUESTION POOL — Format: ID|CATEGORY|QUESTION|SCORE_CMD|POINTS
# Real RHCSA EX200 scenarios based on RHEL 9
# ==========================================================================
declare -a QUESTION_POOL=(

	# ── NETWORKING ──────────────────────────────────────────────────────────────
	"net|Networking|Configure network with static parameters using nmcli:
  IP Address : 172.25.250.10/24
  Gateway    : 172.25.250.254
  DNS        : 172.24.254.254
  Hostname   : servera.lab.example.com
  Connection should persist across reboot.|check_network_static|20"

	"net2|Networking|Configure your system with the following network settings using nmcli:
  Interface  : ens192 (or primary interface)
  IP Address : 192.168.1.100/24
  Gateway    : 192.168.1.1
  DNS        : 8.8.8.8
  Method     : manual (static)|check_network_custom|20"

	"hostname|Networking|Set the system hostname to rhcsa-server.lab.example.com
Verify with hostnamectl.|check_hostname|10"

	"ntp|NTP/Time|Configure your system as an NTP client of classroom.example.com
Use chronyd service. Ensure it is running and enabled.|check_ntp|15"

	# ── PACKAGE MANAGEMENT ──────────────────────────────────────────────────────
	"repo|Packages|Configure your system to use these repositories:
  http://content.example.com/rhel9.0/x86_64/rhcsa-practice/rht
  http://content.example.com/rhel9.0/x86_64/rhcsa-practice/errata
  Both repos should be enabled and usable.|check_repo|15"

	"repo2|Packages|Configure a local yum/dnf repository pointing to:
  file:///var/repo/baseos
  file:///var/repo/appstream
  Ensure repos are enabled.|check_repo_local|15"

	# ── USER & GROUP MANAGEMENT ─────────────────────────────────────────────────
	"users|Users & Groups|Create the following users, groups and memberships:
  Group : sharegrp
  User  : harry  — secondary group sharegrp, password: redhat
  User  : natasha — secondary group sharegrp, password: redhat
  User  : copper — no interactive shell, not in sharegrp, password: redhat
  All users should be forced to change password on first login.|check_users_harry|20"

	"users2|Users & Groups|Create the following:
  User : fred with UID 3945, password: iamredhatman
  User : natasha with UID 4000, password: redhat
  User : daffy — no login shell, not a member of any extra groups|check_users_fred|15"

	"umask|Users & Groups|Configure the system so user daffy gets the following
default permissions on new files and directories:
  Files      : rw------- (600)
  Directories: rwx------ (700)
Set this via the user's shell profile or /etc/login.defs.|check_umask|15"

	"passwd_expire|Users & Groups|Configure password expiration policy:
  All NEW user passwords should expire after 30 days.
  Modify /etc/login.defs accordingly.|check_passwd_expire|15"

	"sudo|Users & Groups|Configure sudo so members of the admin group can execute
ALL commands via sudo WITHOUT a password prompt.
Use /etc/sudoers.d/ for the configuration.|check_sudo_admin|15"

	# ── FILE PERMISSIONS & OWNERSHIP ─────────────────────────────────────────────
	"collab_dir|File Permissions|Create a collaborative directory /var/shares:
  Group ownership : sharegrp
  Permissions     : rwx for group, no access for others (2770)
  Files created in /var/shares should automatically get sharegrp ownership (SGID)|check_collab_dir|20"

	"file_perms|File Permissions|Set the following on /var/shares/report.txt:
  Owner : natasha
  Group : sharegrp
  Mode  : rw-r----- (640)|check_file_perms|15"

	# ── FIND & GREP ─────────────────────────────────────────────────────────────
	"grep_find|Find & Grep|Find all lines containing 'ich' in
/usr/share/mime/packages/freedesktop.org.xml
Save matching lines (original order, no empty lines) to /root/lines|check_grep_lines|15"

	"find_owner|Find & Grep|Find ALL files on the system owned by user natasha.
Redirect the output (full paths) to /tmp/output|check_find_natasha|15"

	"grep_passwd|Find & Grep|Search for the string 'nologin' in /etc/passwd.
Save the output to /root/strings|check_grep_passwd|10"

	# ── CRON & SCHEDULING ───────────────────────────────────────────────────────
	"cron|Scheduling|Configure a cron job for user natasha:
  Runs daily at 14:23
  Command: /bin/echo hello
  Must be set via natasha's crontab, not system crontab.|check_cron_natasha|15"

	"cron2|Scheduling|Create a systemd timer for root:
  Runs hourly
  Executes /usr/local/bin/hourly-task.sh (create a simple script)
  Timer must be persistent (survive reboot)|check_systemd_timer|15"

	# ── ARCHIVING ───────────────────────────────────────────────────────────────
	"archive|Archiving|Create a compressed backup of /usr/local:
  File: /root/backup.tar.bz2
  Use bzip2 compression
  The archive should contain all contents of /usr/local|check_archive|15"

	"archive2|Archiving|Create /root/etc-backup.tar.gz containing /etc
Use gzip compression. Verify the archive was created successfully.|check_archive_etc|10"

	# ── SELINUX ─────────────────────────────────────────────────────────────────
	"selinux_mode|SELinux|Ensure SELinux is in enforcing mode.
  Both runtime AND persistent configuration must be enforcing.
  Verify with getenforce and /etc/selinux/config|check_selinux_enforcing|15"

	"selinux_port|SELinux|Your web content is configured on port 82 at /var/www/html.
Do NOT alter or remove any files in that directory.
Make the content accessible by:
  1. Allowing httpd to serve on port 82 (semanage port)
  2. Ensuring correct file context|check_selinux_httpd82|25"

	"selinux_bool|SELinux|Configure SELinux to allow httpd to connect to network:
  Set the httpd_can_network_connect boolean to on (persistent)|check_selinux_bool|10"

	# ── STORAGE & LVM ───────────────────────────────────────────────────────────
	"swap_add|Storage|Add an additional swap partition of 512 MiB:
  Must automatically mount at boot (/etc/fstab)
  Do not remove or alter any existing swap|check_swap_add|20"

	"lvm_create|Storage|Create a logical volume named 'database':
  Volume group : datastore
  Extent size  : 16 MiB
  Size         : 50 extents (800M)
  Format       : vfat (FAT32)
  Mount point  : /mnt/database (auto-mount at boot)|check_lvm_database|25"

	"lvm_resize|Storage|Resize the logical volume named 'database' to 850MB:
  Final size should be between 830MB and 865MB
  The filesystem must be usable after resize|check_lvm_resize|20"

	"lvm_xfs|Storage|Create an xfs-formatted logical volume:
  VG name  : rhcsa_vg (use 2 loopback files or partitions)
  LV name  : data_lv
  Size     : 200M
  Mount to : /data/xfs (persist in fstab)|check_lvm_xfs|20"

	# ── AUTOFS & NFS ────────────────────────────────────────────────────────────
	"autofs|Autofs/NFS|Configure autofs to automount remote home directories:
  NFS server : utility.lab.example.com (172.24.10.10)
  Export     : /netdir
  User       : remoteuser15
  Mount point: /netdir/remoteuser15
  Must auto-mount on access and unmount after timeout
  Use indirect map in /etc/auto.master.d/|check_autofs|25"

	# ── BOOT PROCESS ────────────────────────────────────────────────────────────
	"tuning|Performance|Change the tuning profile to 'default':
  Use tuned-adm to set the default profile
  Verify with tuned-adm active|check_tuning|10"

	"grub_kernel|Boot|Add the kernel parameter 'systemd.unit=multi-user.target'
to the default kernel using grubby.
The change should persist across reboots.|check_grubby|15"

	# ── SHELL SCRIPTING ─────────────────────────────────────────────────────────
	"script_find|Shell Script|Create /root/find.sh that:
  Finds all files in /etc with size between 30KB and 60KB
  Copies them to /root/data/
  Script must be executable and work when run as: bash /root/find.sh|check_script_find|20"

	"script_backup|Shell Script|Create /root/backup.sh that:
  Backs up /etc to /root/etc-<date>.tar.gz (today's date in filename)
  Must be executable
  Runs without errors|check_script_backup|15"

	# ── CONTAINERS ──────────────────────────────────────────────────────────────
	"container_root|Containers|Run a rootful container:
  Image   : registry.redhat.io/rhel9/rsyslog (or any available image)
  Name    : rsyslog
  Detached mode
  Map host /opt/files to container /opt/incoming
  Map host /opt/processed to container /opt/outgoing
  Container should be running|check_container_root|20"

	"container_rootless|Containers|Configure a rootless container:
  Create user 'devops' if not exists
  Pull and run a container as devops (not root)
  Container must be running when checked|check_container_rootless|20"

	"container_systemd|Containers|Create a systemd service for a container:
  Service name : container-demo1
  Run as user  : devops (rootless, user service)
  Container must auto-start on boot without manual intervention
  Place unit file in devops user's systemd config|check_container_systemd|25"
)

# ==========================================================================
# FISHER-YATES SHUFFLE & RANDOM SELECTION
# ==========================================================================
shuffle_and_select() {
	local count=$1
	local total=${#QUESTION_POOL[@]}
	local -a indices=()

	# Build index list
	for ((i = 0; i < total; i++)); do
		indices+=("$i")
	done

	# Fisher-Yates shuffle
	for ((i = total - 1; i > 0; i--)); do
		local j=$((RANDOM % (i + 1)))
		local tmp=${indices[$i]}
		indices[$i]=${indices[$j]}
		indices[$j]=$tmp
	done

	# Pick first N
	if [[ $count -gt $total ]]; then
		count=$total
	fi
	SELECTED=()
	for ((i = 0; i < count; i++)); do
		SELECTED+=("${QUESTION_POOL[${indices[$i]}]}")
	done
}

# ==========================================================================
# LIST ALL QUESTIONS
# ==========================================================================
if [[ "$ACTION" == "list" ]]; then
	echo -e "${BOLD}${CYAN}Available Question Pool (${#QUESTION_POOL[@]} questions):${NC}\n"
	echo -e "${BOLD}ID           Category          Pts  Question${NC}"
	echo "───────────────────────────────────────────────────────────────────────"
	for q in "${QUESTION_POOL[@]}"; do
		IFS='|' read -r id cat question _ pts <<<"$q"
		printf "%-13s %-18s %-4s %s\n" "$id" "$cat" "$pts" "$(echo "$question" | head -1)"
	done
	exit 0
fi

# ==========================================================================
# RESET MODE
# ==========================================================================
if [[ "$ACTION" == "reset" ]]; then
	log "Resetting exam artifacts..."
	# Remove exam-specific files
	rm -f /root/lines /root/strings /tmp/output
	rm -f /root/backup.tar.bz2 /root/backup.tar.gz
	rm -f /root/etc-backup.tar.gz
	rm -f /root/find.sh /root/backup.sh
	rm -rf /root/data
	rm -rf /mnt/database /data/xfs
	umount /var/shares 2>/dev/null || true
	rm -rf /var/shares
	# Clean users
	for u in harry natasha copper fred daffy devops; do
		userdel -r "$u" 2>/dev/null || true
	done
	for g in sharegrp admin datastore; do
		groupdel "$g" 2>/dev/null || true
	done
	# Clean LVM
	lvremove -f /dev/datastore/database 2>/dev/null || true
	lvremove -f /dev/rhcsa_vg/data_lv 2>/dev/null || true
	vgremove -f datastore 2>/dev/null || true
	vgremove -f rhcsa_vg 2>/dev/null || true
	rm -f /var/log/exam-rhcsa-*.img
	# Clean containers
	podman rm -f rsyslog 2>/dev/null || true
	systemctl --user disable container-demo1.service 2>/dev/null || true
	# Clean cron
	crontab -r -u natasha 2>/dev/null || true
	# Restore fstab
	if [[ -f /etc/fstab.lab-original ]]; then
		cp /etc/fstab.lab-original /etc/fstab
	fi
	rm -f "$EXAM_FILE"
	ok "Exam artifacts reset"
	exit 0
fi

# ==========================================================================
# SCORING MODE
# ==========================================================================
if [[ "$ACTION" == "score" ]]; then
	# Load exam questions
	if [[ ! -f "$EXAM_FILE" ]]; then
		echo -e "${RED}No active exam found. Run without --score first.${NC}"
		exit 1
	fi

	log "Scoring exam..."
	echo ""

	SCORE=0
	MAX_SCORE=0
	Q_NUM=0

	while IFS= read -r line; do
		IFS='|' read -r id cat question _ pts <<<"$line"
		((Q_NUM++))
		((MAX_SCORE += pts))
		earned=0

		case "$id" in
		# ── NETWORKING ─────────────────────────────────────────────────
		net)
			if nmcli -t -f ipv4.method con show "$(nmcli -t -f NAME con show --active | head -1)" 2>/dev/null | grep -q 'manual'; then
				((earned = pts))
			elif ip addr show 2>/dev/null | grep -q '172.25.250.10'; then
				((earned = pts))
			fi
			if [[ -n "$(hostnamectl --static 2>/dev/null)" ]] && hostnamectl --static | grep -q 'servera'; then
				((earned += 0))
			fi
			;;
		net2)
			if nmcli con show 2>/dev/null | grep -q 'connected'; then
				((earned = pts))
			fi
			;;
		hostname)
			if hostnamectl --static 2>/dev/null | grep -q 'rhcsa-server\|lab.example.com'; then
				((earned = pts))
			fi
			;;
		ntp)
			if systemctl is-active chronyd &>/dev/null; then
				((earned = pts / 2))
			fi
			if grep -q 'classroom.example.com\|server ' /etc/chrony.conf 2>/dev/null; then
				((earned += pts / 2))
			fi
			;;

		# ── PACKAGES ───────────────────────────────────────────────────
		repo | repo2)
			if dnf repolist enabled 2>/dev/null | grep -qi 'content\|rhcsa\|baseos\|appstream\|local'; then
				((earned = pts))
			fi
			;;

		# ── USERS & GROUPS ─────────────────────────────────────────────
		users)
			if id harry &>/dev/null && id natasha &>/dev/null && id copper &>/dev/null; then
				((earned = pts / 4))
			fi
			if getent group sharegrp &>/dev/null; then
				((earned += pts / 4))
			fi
			if groups harry 2>/dev/null | grep -q 'sharegrp' && groups natasha 2>/dev/null | grep -q 'sharegrp'; then
				((earned += pts / 4))
			fi
			if grep '^copper:' /etc/passwd | grep -q 'nologin\|false'; then
				((earned += pts / 4))
			fi
			;;
		users2)
			if id fred &>/dev/null && [[ "$(id -u fred 2>/dev/null)" == "3945" ]]; then
				((earned = pts / 2))
			fi
			if id daffy &>/dev/null; then
				((earned += pts / 2))
			fi
			;;
		umask)
			if id daffy &>/dev/null; then
				local_umask=$(su - daffy -c 'umask' 2>/dev/null || echo "0022")
				if [[ "$local_umask" == "0077" ]]; then
					((earned = pts))
				fi
			fi
			;;
		passwd_expire)
			if grep '^PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}' | grep -q '30'; then
				((earned = pts))
			fi
			;;
		sudo)
			if [[ -f /etc/sudoers.d/admin ]] || [[ -f /etc/sudoers.d/01-admin ]]; then
				((earned = pts))
			elif grep -r 'admin' /etc/sudoers.d/ 2>/dev/null | grep -q 'NOPASSWD'; then
				((earned = pts))
			fi
			;;

		# ── FILE PERMISSIONS ───────────────────────────────────────────
		collab_dir)
			if [[ -d /var/shares ]]; then
				((earned = pts / 3))
				perms=$(stat -c '%a' /var/shares 2>/dev/null || echo "000")
				if [[ "$perms" == "2770" ]]; then
					((earned += pts / 3))
				fi
				grp=$(stat -c '%G' /var/shares 2>/dev/null || echo "")
				if [[ "$grp" == "sharegrp" ]]; then
					((earned += pts / 3))
				fi
			fi
			;;
		file_perms)
			if [[ -f /var/shares/report.txt ]]; then
				owner=$(stat -c '%U' /var/shares/report.txt 2>/dev/null || echo "")
				group=$(stat -c '%G' /var/shares/report.txt 2>/dev/null || echo "")
				mode=$(stat -c '%a' /var/shares/report.txt 2>/dev/null || echo "")
				[[ "$owner" == "natasha" ]] && ((earned += pts / 3))
				[[ "$group" == "sharegrp" ]] && ((earned += pts / 3))
				[[ "$mode" == "640" ]] && ((earned += pts / 3))
			fi
			;;

		# ── FIND & GREP ───────────────────────────────────────────────
		grep_find)
			if [[ -f /root/lines ]] && [[ -s /root/lines ]]; then
				((earned = pts))
			fi
			;;
		find_owner)
			if [[ -f /tmp/output ]] && [[ -s /tmp/output ]]; then
				((earned = pts))
			fi
			;;
		grep_passwd)
			if [[ -f /root/strings ]] && [[ -s /root/strings ]]; then
				((earned = pts))
			fi
			;;

		# ── CRON & SCHEDULING ─────────────────────────────────────────
		cron)
			if crontab -u natasha -l 2>/dev/null | grep -q '14:23\|23 14'; then
				((earned = pts))
			fi
			;;
		cron2)
			if systemctl is-active hourly-task.timer &>/dev/null ||
				systemctl list-timers 2>/dev/null | grep -q 'hourly'; then
				((earned = pts))
			fi
			;;

		# ── ARCHIVING ─────────────────────────────────────────────────
		archive)
			if [[ -f /root/backup.tar.bz2 ]] && file /root/backup.tar.bz2 2>/dev/null | grep -qi 'bzip2'; then
				((earned = pts))
			fi
			;;
		archive2)
			if [[ -f /root/etc-backup.tar.gz ]] && file /root/etc-backup.tar.gz 2>/dev/null | grep -qi 'gzip'; then
				((earned = pts))
			fi
			;;

		# ── SELINUX ───────────────────────────────────────────────────
		selinux_mode)
			if [[ "$(getenforce 2>/dev/null)" == "Enforcing" ]]; then
				((earned = pts / 2))
			fi
			if grep -q '^SELINUX=enforcing' /etc/selinux/config 2>/dev/null; then
				((earned += pts / 2))
			fi
			;;
		selinux_port)
			if semanage port -l 2>/dev/null | grep 'http_port_t' | grep -q '82'; then
				((earned = pts))
			fi
			;;
		selinux_bool)
			if getsebool httpd_can_network_connect 2>/dev/null | grep -q 'on'; then
				((earned = pts))
			fi
			;;

		# ── STORAGE & LVM ─────────────────────────────────────────────
		swap_add)
			if swapon --show 2>/dev/null | grep -q 'partition'; then
				swap_count=$(swapon --show --noheadings 2>/dev/null | wc -l)
				if [[ $swap_count -ge 2 ]]; then
					((earned = pts))
				fi
			fi
			;;
		lvm_create)
			if lvs datastore/database &>/dev/null; then
				((earned = pts / 2))
			fi
			if [[ -d /mnt/database ]] && mountpoint -q /mnt/database; then
				((earned += pts / 2))
			fi
			;;
		lvm_resize)
			if lvs datastore/database &>/dev/null; then
				lv_size=$(lvs --noheadings --nosuffix -o lv_size datastore/database 2>/dev/null | tr -d ' .')
				if [[ $lv_size -ge 830 ]] && [[ $lv_size -le 865 ]]; then
					((earned = pts))
				fi
			fi
			;;
		lvm_xfs)
			if lvs rhcsa_vg/data_lv &>/dev/null; then
				((earned = pts / 2))
			fi
			if mountpoint -q /data/xfs 2>/dev/null; then
				((earned += pts / 2))
			fi
			;;

		# ── AUTOFS ────────────────────────────────────────────────────
		autofs)
			if systemctl is-active autofs &>/dev/null; then
				((earned = pts / 2))
			fi
			if [[ -f /etc/auto.master.d/autofs.autofs ]] || grep -r 'netdir' /etc/auto.master* 2>/dev/null | grep -q 'remoteuser15'; then
				((earned += pts / 2))
			fi
			;;

		# ── BOOT & PERFORMANCE ────────────────────────────────────────
		tuning)
			if tuned-adm active 2>/dev/null | grep -qi 'default'; then
				((earned = pts))
			fi
			;;
		grub_kernel)
			if grubby --info=DEFAULT 2>/dev/null | grep -q 'systemd.unit'; then
				((earned = pts))
			fi
			;;

		# ── SHELL SCRIPTING ───────────────────────────────────────────
		script_find)
			if [[ -f /root/find.sh ]] && [[ -x /root/find.sh ]]; then
				((earned = pts / 2))
			fi
			if [[ -d /root/data ]] && [[ "$(ls -A /root/data 2>/dev/null | wc -l)" -gt 0 ]]; then
				((earned += pts / 2))
			fi
			;;
		script_backup)
			if [[ -f /root/backup.sh ]] && [[ -x /root/backup.sh ]]; then
				((earned = pts))
			fi
			;;

		# ── CONTAINERS ────────────────────────────────────────────────
		container_root)
			if podman ps 2>/dev/null | grep -q 'rsyslog'; then
				((earned = pts / 2))
			fi
			if podman inspect rsyslog 2>/dev/null | grep -q '/opt/incoming\|/opt/outgoing'; then
				((earned += pts / 2))
			fi
			;;
		container_rootless)
			if id devops &>/dev/null; then
				((earned = pts / 2))
				if su - devops -c 'podman ps' 2>/dev/null | grep -q 'Up'; then
					((earned += pts / 2))
				fi
			fi
			;;
		container_systemd)
			if id devops &>/dev/null; then
				svc_file="/home/devops/.config/systemd/user/container-demo1.service"
				svc_file2="/home/devops/.config/systemd/user/container_demo1.service"
				if [[ -f "$svc_file" ]] || [[ -f "$svc_file2" ]]; then
					((earned = pts / 2))
				fi
				if su - devops -c 'systemctl --user is-enabled container-demo1.service' 2>/dev/null | grep -q 'enabled' ||
					su - devops -c 'systemctl --user is-enabled container_demo1.service' 2>/dev/null | grep -q 'enabled'; then
					((earned += pts / 2))
				fi
			fi
			;;

		*)
			warn "Unknown question ID: $id (cannot auto-score)"
			;;
		esac

		if [[ $earned -ge $pts ]]; then
			ok "Q${Q_NUM} [$cat] $(echo "$question" | head -1) (+${earned}/${pts})"
		elif [[ $earned -gt 0 ]]; then
			warn "Q${Q_NUM} [$cat] $(echo "$question" | head -1) (+${earned}/${pts})"
		else
			fail "Q${Q_NUM} [$cat] $(echo "$question" | head -1) (+0/${pts})"
		fi
		((SCORE += earned))

	done <"$EXAM_FILE"

	# Final score
	if [[ $MAX_SCORE -gt 0 ]]; then
		PERCENTAGE=$((SCORE * 100 / MAX_SCORE))
	else
		PERCENTAGE=0
	fi

	echo ""
	echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
	echo -e "${BOLD}  Final Score : ${SCORE} / ${MAX_SCORE} (${PERCENTAGE}%)${NC}"
	echo -e "${BOLD}  Questions   : ${Q_NUM}${NC}"
	if [[ $PERCENTAGE -ge 70 ]]; then
		echo -e "${BOLD}${GREEN}  Result      : PASS${NC}"
	else
		echo -e "${BOLD}${RED}  Result      : FAIL (need 70% to pass)${NC}"
	fi
	echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
	echo "$(date '+%Y-%m-%d %H:%M') | Score: ${SCORE}/${MAX_SCORE} (${PERCENTAGE}%) | Questions: ${Q_NUM}" >>"$SCORE_FILE"
	exit 0
fi

# ==========================================================================
# START EXAM
# ==========================================================================
echo -e "${BOLD}${CYAN}"
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   RHCSA EX200 — Practice Exam Simulation (RHEL 9)               ║
║                                                                  ║
║   Duration     : 150 minutes                                     ║
║   Passing Score: 210/300 (70%)                                   ║
║   Questions    : RANDOMIZED from pool                            ║
║                                                                  ║
║   Commands:                                                      ║
║     sudo bash exam-simulate.sh --score    Score your answers     ║
║     sudo bash exam-simulate.sh --reset    Reset lab artifacts    ║
║     sudo bash exam-simulate.sh --list     List all questions     ║
║     sudo bash exam-simulate.sh --count 20 Set question count     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Select random questions (no process substitution — avoids set -e failures)
log "Selecting ${QUESTION_COUNT} random questions from pool of ${#QUESTION_POOL[@]}..."
SELECTED=()
shuffle_and_select "$QUESTION_COUNT"
log "Selected ${#SELECTED[@]} questions"

# Save exam file for scoring
>"$EXAM_FILE"
for q in "${SELECTED[@]}"; do
	echo "$q" >>"$EXAM_FILE"
done

# Display questions
echo ""
Q_NUM=0
for q in "${SELECTED[@]}"; do
	IFS='|' read -r id cat question _ pts <<<"$q"
	((Q_NUM++))
	echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${BOLD} Question ${Q_NUM}  [${cat}]  (${pts} points)${NC}"
	echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo ""
	echo "$question"
	echo ""
done

echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Total Questions: ${Q_NUM}${NC}"
echo -e "${BOLD} Start time: $(date)${NC}"
echo -e "${BOLD} Exam file : ${EXAM_FILE}${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Exam started. Work through the questions above.${NC}"
echo -e "When finished, run: ${BOLD}sudo bash $0 --score${NC}"
echo ""
