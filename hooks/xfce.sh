#!/bin/sh
# =================================================================
# FreeBSD XFCE Root Auto-Login Setup Script (Updated)
# Description: Automates Xorg/XFCE installation, scfb driver config, 
#              and root auto-login.
# Usage: sh install_xfce.sh
# =================================================================
set -e
echo "--- 1. Updating pkg and installing packages ---"
pkg update
pkg install -y xorg xfce slim
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
sysrc slim_enable="YES"
echo "--- 4. Configuring procfs (required by XFCE) ---"
if ! grep -q "/proc" /etc/fstab; then
    echo 'proc /proc procfs rw 0 0' >> /etc/fstab
fi
mount -a || true
echo "--- 5. Configuring SLiM for root auto-login ---"
SLIM_CONF="/usr/local/etc/slim.conf"
if [ -f "$SLIM_CONF" ]; then
    # Set default user to root
    sed -i '' 's/^[#]*default_user.*/default_user        root/' "$SLIM_CONF"
    # Enable auto login
    sed -i '' 's/^[#]*auto_login.*/auto_login          yes/' "$SLIM_CONF"
else
    echo "Error: $SLIM_CONF not found!"
    exit 1
fi
echo "--- 6. Creating .xinitrc for root ---"
echo 'exec startxfce4' > /root/.xinitrc
chmod +x /root/.xinitrc
echo "--- 7. Starting services ---"
service dbus restart


rm -f /tmp/.X*-lock
rm -rf /tmp/.X11-unix
service slim restart
echo "--- Setup Complete! ---"
echo "Root will now auto-login to XFCE. Please check your VM console."


