#!/bin/sh
# =================================================================
# FreeBSD GNOME Root Auto-Login Setup Script
# Description: Automates Xorg/GNOME installation, scfb driver, 
#              and root auto-login via GDM.
# Usage: sh install_gnome.sh
# =================================================================
set -e
echo "--- 1. Updating pkg and installing GNOME (this may take a while) ---"
pkg update
pkg install -y xorg gnome gdm
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
echo "--- 4. Configuring procfs (Essential for GNOME) ---"
if ! grep -q "/proc" /etc/fstab; then
    echo 'proc /proc procfs rw 0 0' >> /etc/fstab
fi
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
echo "--- 7. Starting services ---"
service dbus restart
rm -f /tmp/.X*-lock
rm -rf /tmp/.X11-unix
service gdm restart
echo "--- Setup Complete! ---"
echo "Root will now auto-login to GNOME. Please wait for the desktop to load."


