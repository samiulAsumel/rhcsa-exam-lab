#!/usr/bin/env bash
#===============================================================================
# rhcsa-cheat.sh — RHCSA EX200 Quick Reference / Cheat Sheet
# Purpose : Quick command reference during practice
# Usage   : bash rhcsa-cheat.sh [topic]
# Topics  : lvm, user, network, selinux, systemd, boot, container, all
#===============================================================================

TOPIC="${1:-all}"

show_lvm() {
	cat <<'EOF'
━━━ LVM & Storage ━━━
pvcreate /dev/sdb                  # Create physical volume
vgcreate vg01 /dev/sdb /dev/sdc    # Create volume group
lvcreate -L 10G -n lv_data vg01    # Create logical volume
lvextend -L +5G /dev/vg01/lv_data  # Extend LV
lvextend -r -l +100%FREE ...       # Extend + resize fs
xfs_growfs /mountpoint             # Grow xfs
resize2fs /dev/vg01/lv_data        # Grow ext4
mkfs.xfs /dev/vg01/lv_data         # Format xfs
mkfs.ext4 /dev/vg01/lv_data        # Format ext4
pvs / vgs / lvs                    # Quick overview
pvdisplay / vgdisplay / lvdisplay  # Detailed info
mkswap /dev/vg01/lv_swap           # Format swap
swapon /dev/vg01/lv_swap           # Activate swap
swapon --show                      # Show active swap
# /etc/fstab entry:
# /dev/vg01/lv_data /data xfs defaults 0 0
EOF
}

show_user() {
	cat <<'EOF'
━━━ Users & Groups ━━━
useradd -u 1500 -m -s /bin/bash user1    # Create user
passwd user1                              # Set password
chpasswd <<< "user1:Password123"          # Set via stdin
usermod -aG group1,group2 user1           # Add to groups
chage -M 90 -m 7 -W 14 user1             # Password aging
chage -l user1                            # Show aging info
id user1                                  # Show UID/GID/groups
groups user1                              # Show groups
groupadd -g 3000 grpname                  # Create group
groupdel grpname                          # Delete group
userdel -r user1                          # Delete user + home
passwd -l user1                           # Lock account
passwd -u user1                           # Unlock account
# /etc/sudoers.d/file:
# user1 ALL=(ALL) NOPASSWD: /usr/bin/systemctl
EOF
}

show_network() {
	cat <<'EOF'
━━━ Networking ━━━
nmcli con show                           # Show connections
nmcli device status                      # Show devices
nmcli con add type ethernet con-name static ifname ens192
nmcli con mod static ipv4.addresses 192.168.1.100/24
nmcli con mod static ipv4.gateway 192.168.1.1
nmcli con mod static ipv4.dns 8.8.8.8
nmcli con mod static ipv4.method manual
nmcli con up static                      # Activate
ip addr show                             # Show IPs
ip route show                            # Show routes
hostnamectl set-hostname server.lab.com  # Set hostname
cat /etc/resolv.conf                     # DNS config
ss -tulnp                                # Listening ports
ss -tnp                                  # Active connections
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --reload
firewall-cmd --list-all
EOF
}

show_selinux() {
	cat <<'EOF'
━━━ SELinux ━━━
getenforce                               # Current mode
setenforce 0|1                           # Set mode (temp)
sestatus                                 # Full status
# Permanent: edit /etc/selinux/config
semanage boolean -l                      # List booleans
setsebool -P httpd_can_network_connect on
semanage fcontext -l | grep /var/www     # List contexts
semanage fcontext -a -t httpd_sys_content_t '/newpath(/.*)?'
restorecon -Rv /newpath                  # Apply context
chcon -t httpd_sys_content_t file.txt    # Temp context
semanage port -l | grep http             # Port contexts
semanage port -a -t http_port_t -p tcp 8888
ausearch -m AVC -ts recent               # Find denials
audit2why < /var/log/audit/audit.log     # Analyze denials
EOF
}

show_systemd() {
	cat <<'EOF'
━━━ Systemd & Services ━━━
systemctl start|stop|restart|reload svc  # Service control
systemctl enable|disable svc             # Boot control
systemctl status svc                     # Show status
systemctl is-active svc                  # Check active
systemctl is-enabled svc                 # Check enabled
systemctl mask|unmask svc                # Prevent/allow start
systemctl daemon-reload                  # Reload units
systemctl get-default                    # Default target
systemctl set-default multi-user.target  # Set default
systemctl isolate rescue.target          # Switch target
journalctl -u svc -f                     # Follow logs
journalctl --since today                 # Today's logs
journalctl -k                            # Kernel logs
journalctl --disk-usage                  # Log disk usage
systemd-analyze blame                     # Boot time analysis
# Timer file: /etc/systemd/system/my.timer
# Service file: /etc/systemd/system/my.service
EOF
}

show_boot() {
	cat <<'EOF'
━━━ Boot Process ━━━
# GRUB2 - Add kernel param (persistent):
grubby --update-kernel=ALL --args='rd.break'
grubby --update-kernel=ALL --remove-args='rd.break'
grubby --info=ALL                        # List kernels
grubby --set-default /boot/vmlinuz-...
grub2-mkconfig -o /boot/grub2/grub.cfg  # Regenerate

# Root password reset:
# 1. GRUB -> edit -> append 'rd.break'
# 2. mount -o remount,rw /sysroot
# 3. chroot /sysroot
# 4. passwd root
# 5. touch /.autorelabel
# 6. exit && exit

# Kernel modules:
lsmod                                    # List loaded
modprobe <module>                        # Load
modprobe -r <module>                     # Remove
modinfo <module>                         # Info

# Initramfs:
dracut --force /boot/initramfs-$(uname -r).img $(uname -r)
EOF
}

show_container() {
	cat <<'EOF'
━━━ Containers (Podman) ━━━
podman pull registry.access.redhat.com/ubi9/ubi
podman images                            # List images
podman run -d --name web -p 8080:80 httpd
podman ps                                # Running containers
podman ps -a                             # All containers
podman exec -it web /bin/bash            # Shell into container
podman logs web                          # Container logs
podman stop|start|restart web            # Control
podman rm -f web                         # Force remove
podman volume create data                # Create volume
podman run -v data:/app/data ...         # Mount volume
podman network create mynet              # Create network
podman run --network mynet ...           # Use network
podman generate systemd --name web --new # Systemd unit

# Rootless: login as user, podman works without sudo
# Build:
podman build -t myimage .
podman run -d --name app -p 8080:80 myimage
EOF
}

case "$TOPIC" in
lvm) show_lvm ;;
user) show_user ;;
network) show_network ;;
selinux) show_selinux ;;
systemd) show_systemd ;;
boot) show_boot ;;
container) show_container ;;
all | *)
	show_lvm
	echo
	show_user
	echo
	show_network
	echo
	show_selinux
	echo
	show_systemd
	echo
	show_boot
	echo
	show_container
	;;
esac
