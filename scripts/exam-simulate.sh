#!/usr/bin/env bash
#===============================================================================
# exam-simulate.sh — RHCSA EX200 Exam Simulation
# Purpose : Timed practice exam with auto-scoring
# Usage   : sudo bash exam-simulate.sh [--reset] [--score]
# Duration: 2.5 hours (150 minutes) — matching real RHCSA exam
#===============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCORE_FILE="/var/log/rhcsa-exam-scores.log"
QUESTIONS=()

log() { echo -e "${CYAN}[EXAM]${NC} $*"; }
ok() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
task() { echo -e "\n${BOLD}${YELLOW}━━━ Question $1 ━━━${NC}"; }

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}Run as root${NC}"
	exit 1
fi

echo -e "${BOLD}${CYAN}"
cat <<'BANNER'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║    RHCSA EX200 — Practice Exam Simulation                ║
║                                                          ║
║    Duration: 150 minutes                                 ║
║    Passing : 210/300 (70%)                               ║
║    Questions: 20+ tasks                                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Mode selection
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--score" ]]; then
	log "Scoring mode — checking all tasks"

	SCORE=0
	MAX_SCORE=0

	# Q1: Root password changed
	((MAX_SCORE += 15))

	# Q2: Network config
	((MAX_SCORE += 15))
	if nmcli con show 2>/dev/null | grep -q 'connected'; then
		((SCORE += 15)) && ok "Q2: Network configured (+15)"
	else
		fail "Q2: No network connection found"
	fi

	# Q3: YUM/DNF repo
	((MAX_SCORE += 15))
	if dnf repolist enabled 2>/dev/null | grep -q 'appstream\|baseos'; then
		((SCORE += 15)) && ok "Q3: Repos configured (+15)"
	else
		fail "Q3: Repos not configured"
	fi

	# Q4: SELinux
	((MAX_SCORE += 15))
	if [[ "$(getenforce 2>/dev/null)" == "Enforcing" ]]; then
		((SCORE += 15)) && ok "Q4: SELinux enforcing (+15)"
	else
		fail "Q4: SELinux not enforcing"
	fi

	# Q5: Users & groups
	((MAX_SCORE += 15))
	if id rhcsa_user1 &>/dev/null && groups rhcsa_user1 2>/dev/null | grep -q 'project_team'; then
		((SCORE += 15)) && ok "Q5: Users & groups (+15)"
	else
		fail "Q5: Users/groups missing"
	fi

	# Q6: LVM
	((MAX_SCORE += 15))
	if lvs rhcsa_vg01 &>/dev/null; then
		((SCORE += 15)) && ok "Q6: LVM configured (+15)"
	else
		fail "Q6: LVM not found"
	fi

	# Q7: Swap
	((MAX_SCORE += 15))
	if swapon --show 2>/dev/null | grep -q rhcsa; then
		((SCORE += 15)) && ok "Q7: Swap configured (+15)"
	else
		fail "Q7: Swap not configured"
	fi

	# Q8: fstab
	((MAX_SCORE += 15))
	if grep -q 'rhcsa_lv' /etc/fstab 2>/dev/null; then
		((SCORE += 15)) && ok "Q8: fstab entries (+15)"
	else
		fail "Q8: fstab entries missing"
	fi

	# Q9: Cron/timers
	((MAX_SCORE += 15))
	if systemctl is-active rhcsa-backup.timer &>/dev/null; then
		((SCORE += 15)) && ok "Q9: Timer configured (+15)"
	else
		fail "Q9: Timer not active"
	fi

	# Q10: Containers
	((MAX_SCORE += 15))
	if podman images 2>/dev/null | grep -q 'alpine\|httpd\|nginx\|ubi'; then
		((SCORE += 15)) && ok "Q10: Containers configured (+15)"
	else
		fail "Q10: No containers/images found"
	fi

	# Q11: Firewall
	((MAX_SCORE += 15))
	if firewall-cmd --list-services 2>/dev/null | grep -q 'ssh'; then
		((SCORE += 15)) && ok "Q11: Firewall configured (+15)"
	else
		fail "Q11: Firewall not configured"
	fi

	# Q12: Sudoers
	((MAX_SCORE += 15))
	if [[ -f /etc/sudoers.d/rhcsa-practice ]]; then
		((SCORE += 15)) && ok "Q12: Sudoers configured (+15)"
	else
		fail "Q12: Sudoers not configured"
	fi

	# Q13: ACLs
	((MAX_SCORE += 15))
	if getfacl /data/permission-practice/confidential.txt 2>/dev/null | grep -q 'rhcsa_user2'; then
		((SCORE += 15)) && ok "Q13: ACLs configured (+15)"
	else
		fail "Q13: ACLs not configured"
	fi

	# Q14: File permissions
	((MAX_SCORE += 15))
	if [[ -f /data/permission-practice/report.txt ]] &&
		stat -c '%U:%G' /data/permission-practice/report.txt 2>/dev/null | grep -q 'rhcsa_user1:project_team'; then
		((SCORE += 15)) && ok "Q14: File permissions (+15)"
	else
		fail "Q14: File permissions incorrect"
	fi

	# Q15: Shared directory with SGID
	((MAX_SCORE += 15))
	if stat -c '%a' /data/shared 2>/dev/null | grep -q '2770'; then
		((SCORE += 15)) && ok "Q15: SGID directory (+15)"
	else
		fail "Q15: SGID not set"
	fi

	PERCENTAGE=$((SCORE * 100 / MAX_SCORE))
	echo ""
	echo -e "${BOLD}══════════════════════════════════════════${NC}"
	echo -e "${BOLD} Score: ${SCORE}/${MAX_SCORE} (${PERCENTAGE}%)${NC}"
	if [[ $PERCENTAGE -ge 70 ]]; then
		echo -e "${BOLD}${GREEN} Result: PASS${NC}"
	else
		echo -e "${BOLD}${RED} Result: FAIL (need 70%)${NC}"
	fi
	echo -e "${BOLD}══════════════════════════════════════════${NC}"
	echo "$(date '+%Y-%m-%d %H:%M') | Score: ${SCORE}/${MAX_SCORE} (${PERCENTAGE}%)" >>"$SCORE_FILE"
	exit 0
fi

# ---------------------------------------------------------------------------
# Exam questions
# ---------------------------------------------------------------------------
echo -e "${BOLD}You have 150 minutes. Good luck!${NC}"
echo -e "Start time: $(date)"
START_TIME=$(date +%s)

cat <<'QUESTIONS'

Questions:
══════════
 1. Reset root password to 'RedHat2024!'
 2. Configure networking with nmcli (IP: 192.168.122.100/24, GW: 192.168.122.1)
 3. Configure yum/dnf repositories
 4. Ensure SELinux is in enforcing mode
 5. Create users rhcsa_user1/2/3, group project_team, add users to group
 6. Create LVM: VG=rhcsa_vg01 with 2 PVs, LV=rhcsa_lv_data (200M, xfs)
 7. Create swap LV (64M) in rhcsa_vg01, activate it
 8. Add LVM mounts to /etc/fstab persistently
 9. Create a systemd timer running hourly
10. Run a container with podman (httpd/nginx), expose port 8080
11. Configure firewalld to allow ssh, http
12. Configure sudoers: rhcsa_user1 full sudo, project_team limited
13. Set ACL: rhcsa_user2 can read confidential.txt
14. Set file ownership: report.txt owned by rhcsa_user1:project_team, mode 640
15. Create /data/shared with SGID (2770) for developers group

Type 'bash /practice/scripts/exam-simulate.sh --score' to check answers.

QUESTIONS

echo -e "${BOLD}Press Enter to begin...${NC}"
read -r

echo -e "\n${GREEN}Exam started. Work through the questions above.${NC}"
echo -e "When finished, run: ${BOLD}sudo bash $(readlink -f "$0") --score${NC}\n"
