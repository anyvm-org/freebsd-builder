#!/bin/sh
# =================================================================
# FreeBSD KDE Plasma 6 Root Auto-Login Setup Script (Final)
# =================================================================
set -e
echo "--- 1. Installing KDE Plasma 6 ---"
pkg update
pkg install -y xorg plasma6-plasma sddm
echo "--- 2. Configuring Xorg Driver ---"
mkdir -p /usr/local/etc/X11/xorg.conf.d
printf 'Section "Device"
    Identifier "Card0"
    Driver     "scfb"
    BusID      "PCI:0:2:0"
EndSection
' > /usr/local/etc/X11/xorg.conf.d/driver-scfb.conf
echo "--- 3. Enabling Services ---"
sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
echo "--- 4. Configuring File Systems ---"
grep -q "/proc" /etc/fstab || echo 'proc /proc procfs rw 0 0' >> /etc/fstab
grep -q "/dev/fd" /etc/fstab || echo 'fdesc /dev/fd fdescfs rw 0 0' >> /etc/fstab
mount -a || true
echo "--- 5. Configuring SDDM for Root Auto-login ---"
SDDM_CONF="/usr/local/etc/sddm.conf"
cat <<EOF > "$SDDM_CONF"
[Autologin]
User=root
Session=plasma.desktop
Relogin=false
[Users]
MinimumUid=0
MaximumUid=60000
EOF
echo "--- 6. Fixing PAM to allow Root Graphic Login ---"



sed -i '' 's/account[[:space:]]*requisite[[:space:]]*pam_securetty.so/# &/' /etc/pam.d/login
echo "--- 7. Setting Root Password to 'root' ---"
echo 'root' | pw mod user root -h 0
echo "--- 8. Starting KDE ---"
service dbus restart
rm -f /tmp/.X*-lock
rm -rf /tmp/.X11-unix
service sddm restart
echo "--- Setup Complete! Root is logging in... ---"


