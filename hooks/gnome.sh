#!/bin/sh
# =================================================================
# FreeBSD GNOME Root Auto-Login Setup Script
# Description: Automates Xorg/GNOME installation, scfb driver, 
#              and root auto-login via GDM.
# Usage: sh install_gnome.sh
# =================================================================
set -e
# Arch guard: FreeBSD 15.0 on non-amd64 (aarch64, riscv64) currently lacks a
# working Xorg display driver under QEMU. The kernel's virtio_gpu is a VT
# console driver only -- it does not expose /dev/dri/card0, so the modesetting
# Xorg driver cannot bind, and scfb fails with "scfb_mmap: Invalid argument"
# on first ScreenInit. drm-kmod / xf86-video-fbdev are not in the non-amd64
# pkg repo either. Until FreeBSD ships a DRM virtio-gpu driver, this hook is
# x86_64-only -- fail loudly rather than install hundreds of packages and
# leave the user staring at a dead SLiM.
ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/gnome.sh only supports amd64 (got $ARCH)."
    echo "FreeBSD $ARCH currently lacks a working Xorg / Wayland display"
    echo "driver for QEMU virtio-gpu (no /dev/dri, scfb mmap broken)."
    exit 1
fi
echo "--- 1. Updating pkg and installing GNOME (this may take a while) ---"
pkg update
pkg install -y xorg gnome-lite gdm
echo "--- 2. Configuring Xorg Display Driver (scfb) ---"
mkdir -p /usr/local/etc/X11/xorg.conf.d
printf 'Section "Device"
    Identifier "Card0"
    Driver     "scfb"
    BusID      "PCI:0:2:0"
EndSection
' > /usr/local/etc/X11/xorg.conf.d/driver-scfb.conf
echo "--- 3. Enabling necessary services in /etc/rc.conf ---"
sysrc dbus_enable="YES"
sysrc gdm_enable="YES"
sysrc gnome_enable="YES"
echo "--- 4. Configuring procfs / fdescfs (Essential for GNOME) ---"
grep -q "/proc" /etc/fstab || echo 'proc /proc procfs rw 0 0' >> /etc/fstab
grep -q "/dev/fd" /etc/fstab || echo 'fdesc /dev/fd fdescfs rw 0 0' >> /etc/fstab
mount -a || true
echo "--- 5. Configuring GDM for root auto-login ---"
GDM_CUSTOM_CONF="/usr/local/etc/gdm/custom.conf"
mkdir -p /usr/local/etc/gdm
cat <<EOF > "$GDM_CUSTOM_CONF"
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=root
EOF
echo "--- 6. Allowing Root login for GNOME (PAM configurations) ---"
if [ -f "/usr/local/etc/pam.d/gdm-password" ]; then
    sed -i '' 's/auth.*required.*pam_succeed_if.so user != root quiet_success/# &/' /usr/local/etc/pam.d/gdm-password
fi
echo "--- 7. Disabling GNOME screen lock / idle / autosuspend (system-wide dconf) ---"
# The image is meant for a no-password autologin VM, so root has no password.
# Without these overrides:
#   1. gnome-shell idle timer locks the screen -> gdm-password prompts for a
#      password that does not exist -> user is stuck.
#   2. gnome-settings-daemon power plugin auto-suspends the VM after a few
#      minutes of inactivity -> VM appears frozen in the VNC viewer, and
#      virtio device resume from suspend is not always reliable.
# We disable both via a system-wide dconf override that applies to every
# user (including the autologin root session).
mkdir -p /usr/local/etc/dconf/profile /usr/local/etc/dconf/db/local.d
# Ensure a 'user' profile exists that consults the local system db. If a
# profile already exists (e.g. ibus put one there), only create if missing
# so we do not stomp on it.
if [ ! -f /usr/local/etc/dconf/profile/user ]; then
    cat <<EOF > /usr/local/etc/dconf/profile/user
user-db:user
system-db:local
EOF
fi
cat <<EOF > /usr/local/etc/dconf/db/local.d/00-no-screen-lock
[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/lockdown]
disable-lock-screen=true

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-type='nothing'
sleep-inactive-battery-timeout=0
idle-dim=false
EOF
dconf update
echo "--- 8. Starting services ---"
service dbus restart
rm -f /tmp/.X*-lock
rm -rf /tmp/.X11-unix

nohup service gdm restart > /dev/null 2>&1 &

echo "--- Setup Complete! ---"
echo "Root will now auto-login to GNOME. Please wait for the desktop to load."


