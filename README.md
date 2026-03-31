# RHCSA EX200 Exam Lab Environment

> Production-grade, automated lab setup for Red Hat Certified System Administrator (EX200) exam preparation on Rocky Linux 9 / RHEL 9 / AlmaLinux 9.

![Shell](https://img.shields.io/badge/Bash-Production-green)
![Platform](https://img.shields.io/badge/Rocky--Linux-9.x-blue)
![RHEL](https://img.shields.io/badge/RHEL-9.x-red)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## What This Does

This project provides a complete, automated environment to practice every RHCSA EX200 exam objective. It cleans your system to near-fresh state, installs all required packages, and creates a structured practice environment with auto-scoring.

### Exam Objectives Covered

| Objective | Lab Script |
|-----------|-----------|
| Understand & use essential tools | `user-practice.sh`, `rhcsa-cheat.sh` |
| Create simple shell scripts | Built into all scripts |
| Operate running systems | `service-practice.sh`, `boot-practice.sh` |
| Configure local storage | `lvm-practice.sh` |
| Create & configure file systems | `lvm-practice.sh` |
| Deploy, configure & maintain systems | `01-system-update.sh` |
| Manage basic networking | `network-practice.sh` |
| Manage users & groups | `user-practice.sh` |
| Manage security (SELinux, firewalld) | `security-practice.sh` |
| Manage containers | `container-practice.sh` |

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/rhcsa-exam-lab.git
cd rhcsa-exam-lab

# Run the full setup (clean + update + lab environment)
sudo bash scripts/rhcsa-lab-setup.sh

# Or run individual phases
sudo bash scripts/00-system-clean.sh    # Clean system
sudo bash scripts/01-system-update.sh   # Update & install packages
sudo bash scripts/rhcsa-lab-setup.sh --lab-only  # Lab only
```

### Options

```
--skip-clean    Skip system cleanup phase
--skip-update   Skip system update phase
--lab-only      Only set up the lab environment
```

---

## Project Structure

```
rhcsa-exam-lab/
├── scripts/
│   ├── 00-system-clean.sh          # Full system cleanup
│   ├── 01-system-update.sh         # Package update & install
│   ├── rhcsa-lab-setup.sh          # Master lab setup (runs all)
│   ├── lab-reset.sh                # Reset lab to clean state
│   └── exam-simulate.sh            # Timed exam with auto-scoring
├── labs/
│   ├── storage-management/
│   │   └── lvm-practice.sh         # LVM, PV, VG, LV, swap, fstab
│   ├── user-management/
│   │   └── user-practice.sh        # Users, groups, sudoers, ACLs
│   ├── systemd-services/
│   │   └── service-practice.sh     # Systemd, services, timers
│   ├── networking/
│   │   └── network-practice.sh     # nmcli, firewall, SSH, DNS
│   ├── security/
│   │   └── security-practice.sh    # SELinux, PAM, crypto, chroot
│   ├── boot-process/
│   │   └── boot-practice.sh        # GRUB, targets, rescue, dracut
│   └── container-management/
│       └── container-practice.sh   # Podman, images, volumes
├── helpers/
│   └── rhcsa-cheat.sh             # Quick command reference
├── configs/                        # Sample config files
├── docs/                           # Documentation
└── README.md
```

---

## Lab Environment Details

### Users Created

| Username | UID | Groups | Password |
|----------|-----|--------|----------|
| operator1 | 1000+ | developers, project-alpha | Password@123 |
| operator2 | 1000+ | developers, project-alpha | Password@123 |
| operator3 | 1000+ | devops-team, project-beta | Password@123 |
| devops | 1000+ | developers, devops-team | Password@123 |
| adminuser | 1000+ | webteam | Password@123 |
| webadmin | 1000+ | webteam, developers | Password@123 |
| dbadmin | 1000+ | dba-team | Password@123 |
| rhcsa_user1 | 1500 | project_team, sysadmin | RedHat@123 |
| rhcsa_user2 | 1501 | project_team, readonly | RedHat@123 |
| rhcsa_user3 | 1502 | project_team, audit | RedHat@123 |

### Directories Created

| Path | Purpose | Permissions |
|------|---------|-------------|
| `/data/shared` | Shared directory (SGID) | 2770 root:developers |
| `/data/projects` | Sticky bit directory | 1777 |
| `/data/web/html` | Web content | 2775 root:webteam |
| `/data/db` | Database files | 2770 root:dba-team |
| `/data/backups` | Backup storage | 750 root:root |
| `/practice/lvm/` | LVM loopback files | — |
| `/practice/containers/` | Container practice | — |

### Services Enabled

- `sshd` — Remote access
- `chronyd` — Time synchronization
- `firewalld` — Firewall management

---

## Practice Labs

Each lab script is self-contained and can be run independently:

```bash
# LVM & Storage
sudo bash labs/storage-management/lvm-practice.sh

# Users & Groups
sudo bash labs/user-management/user-practice.sh

# Systemd & Services
sudo bash labs/systemd-services/service-practice.sh

# Networking
sudo bash labs/networking/network-practice.sh

# Security & SELinux
sudo bash labs/security/security-practice.sh

# Boot Process
sudo bash labs/boot-process/boot-practice.sh

# Containers (Podman)
sudo bash labs/container-management/container-practice.sh
```

### Exam Simulation

```bash
# Run the exam
sudo bash scripts/exam-simulate.sh

# Score your answers (run after completing tasks)
sudo bash scripts/exam-simulate.sh --score
```

### Quick Reference

```bash
# All topics
bash helpers/rhcsa-cheat.sh

# Specific topic
bash helpers/rhcsa-cheat.sh lvm
bash helpers/rhcsa-cheat.sh selinux
bash helpers/rhcsa-cheat.sh network
```

---

## Reset Lab

To reset the lab environment and start fresh:

```bash
sudo bash scripts/lab-reset.sh
```

This removes all lab users, groups, LVM artifacts, custom services, and practice files.

---

## Requirements

- Rocky Linux 9.x, RHEL 9.x, or AlmaLinux 9.x
- Root/sudo access
- Minimum 10GB free disk space
- Network connectivity (for package installation)

---

## Safety Features

- **LVM Snapshots**: Automatic snapshot before cleanup (skippable with `--skip-snapshot`)
- **Dry-run mode**: Preview changes with `--dry-run` on cleanup
- **fstab backup**: Original `/etc/fstab` preserved as `fstab.lab-original`
- **SSH config backup**: SSH config backed up before modification
- **Logging**: All operations logged to `/var/log/rhcsa-lab-*.log`

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Author

**Samiul** — Linux Systems Administration & RHCSA Candidate

---

> *"The best way to pass the RHCSA exam is to practice until the commands become muscle memory."*
