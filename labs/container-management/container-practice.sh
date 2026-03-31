#!/usr/bin/env bash
#===============================================================================
# container-practice.sh — RHCSA Container Management (Podman) Practice
# Covers: podman, images, containers, volumes, networking, systemd integration
# Usage : sudo bash container-practice.sh
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
echo "║       RHCSA Practice Lab — Containers (Podman)      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# Check podman
# ---------------------------------------------------------------------------
if ! command -v podman &>/dev/null; then
	warn "Podman not installed. Installing..."
	dnf install -y podman buildah skopeo 2>/dev/null || {
		echo -e "${RED}Install podman first: dnf install -y podman${NC}"
		exit 1
	}
fi

# ---------------------------------------------------------------------------
# Task 1: Image management
# ---------------------------------------------------------------------------
task "1 — Image Management"

log "Pulling practice images..."
podman pull registry.access.redhat.com/ubi9/ubi 2>/dev/null ||
	podman pull docker.io/library/alpine 2>/dev/null || true

log "Local images:"
podman images 2>/dev/null || true

# ---------------------------------------------------------------------------
# Task 2: Container lifecycle
# ---------------------------------------------------------------------------
task "2 — Container Lifecycle"

# Remove any existing practice container
podman rm -f rhcsa-web 2>/dev/null || true

log "Running a container:"
podman run -d --name rhcsa-web -p 8080:80 \
	docker.io/library/httpd:latest 2>/dev/null ||
	podman run -d --name rhcsa-web -p 8080:80 \
		docker.io/library/nginx:latest 2>/dev/null || true

log "Running containers:"
podman ps 2>/dev/null || true

log "All containers (including stopped):"
podman ps -a 2>/dev/null || true

# ---------------------------------------------------------------------------
# Task 3: Container operations
# ---------------------------------------------------------------------------
task "3 — Container Operations"

log "Container inspection:"
podman inspect rhcsa-web 2>/dev/null | head -20 || true

log "Container logs:"
podman logs rhcsa-web 2>/dev/null | tail -5 || true

log "Execute command in container:"
podman exec rhcsa-web cat /etc/os-release 2>/dev/null | head -3 || true

log "Container stats:"
podman stats --no-stream 2>/dev/null || true

# ---------------------------------------------------------------------------
# Task 4: Volumes & persistence
# ---------------------------------------------------------------------------
task "4 — Volumes & Data Persistence"

podman volume create rhcsa-data 2>/dev/null || true
log "Volumes:"
podman volume ls 2>/dev/null || true

log "Inspect volume:"
podman volume inspect rhcsa-data 2>/dev/null || true

log "Run with volume mount:"
podman run --rm -v rhcsa-data:/data alpine sh -c "echo 'persistent data' > /data/test.txt && cat /data/test.txt" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Task 5: Container networking
# ---------------------------------------------------------------------------
task "5 — Container Networking"

log "Networks:"
podman network ls 2>/dev/null || true

log "Create custom network:"
podman network create rhcsa-net 2>/dev/null || true

log "Run container on custom network:"
podman run -d --name rhcsa-app --network rhcsa-net alpine sleep 3600 2>/dev/null || true
podman inspect rhcsa-app 2>/dev/null | grep -A5 '"Networks"' || true

# ---------------------------------------------------------------------------
# Task 6: Rootless containers with user
# ---------------------------------------------------------------------------
task "6 — Rootless Containers"

log "As rhcsa_user1 (rootless podman):"
su - rhcsa_user1 -c "podman run --rm alpine echo 'Hello from rootless'" 2>/dev/null || warn "Rootless container failed (may need login)"

log "Rootless info:"
echo "  su - rhcsa_user1"
echo "  podman run --rm alpine echo 'hello'"
echo "  podman images"
echo "  podman ps"

# ---------------------------------------------------------------------------
# Task 7: Systemd integration (quadlet / generate)
# ---------------------------------------------------------------------------
task "7 — Systemd Integration"

log "Generate systemd unit for container:"
podman generate systemd --name rhcsa-web --new --files 2>/dev/null || true

log "Manual systemd approach:"
cat >/etc/systemd/system/rhcsa-container.service <<'UNIT'
[Unit]
Description=RHCSA Practice Web Container
After=network.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/podman rm -f rhcsa-web-systemd
ExecStart=/usr/bin/podman run --name rhcsa-web-systemd \
    -p 8081:80 \
    docker.io/library/httpd:latest
ExecStop=/usr/bin/podman stop rhcsa-web-systemd
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
ok "Systemd container service created (rhcsa-container.service)"

# ---------------------------------------------------------------------------
# Task 8: Container management cleanup
# ---------------------------------------------------------------------------
task "8 — Cleanup"

podman stop rhcsa-web 2>/dev/null || true
podman rm -f rhcsa-web rhcsa-app 2>/dev/null || true
podman volume rm rhcsa-data 2>/dev/null || true
podman network rm rhcsa-net 2>/dev/null || true

echo -n "Remove systemd container service? (y/N): "
read -r CLEANUP
if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
	systemctl stop rhcsa-container.service 2>/dev/null || true
	systemctl disable rhcsa-container.service 2>/dev/null || true
	rm -f /etc/systemd/system/rhcsa-container.service
	systemctl daemon-reload
	ok "Systemd service removed"
fi

ok "Container cleanup complete"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Container Practice Complete                         ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  Covered: images, lifecycle, volumes, networking     ║${NC}"
echo -e "${BOLD}${GREEN}║  Practiced: rootless, systemd integration            ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Key podman commands:${NC}"
echo "  podman pull / images / run / ps / stop / rm"
echo "  podman exec -it <name> /bin/bash"
echo "  podman logs <name>"
echo "  podman volume create / ls / inspect"
echo "  podman network create / ls"
echo "  podman generate systemd --name <name> --new"
