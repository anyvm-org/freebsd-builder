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
Session=plasmax11.desktop
Relogin=false
[Users]
MinimumUid=0
MaximumUid=60000
EOF
echo "--- 6. Fixing PAM to allow Root Graphic Login ---"
sed -i '' 's/account[[:space:]]*requisite[[:space:]]*pam_securetty.so/# &/' /etc/pam.d/login
echo "--- 7. Disabling Plasma screen lock / auto-suspend (system-wide) ---"
# The image is meant for a no-password autologin VM, so root has no password.
# Without these overrides:
#   1. kscreenlocker locks the desktop after idle / on resume -> SDDM prompts
#      for a password that does not exist -> user is stuck.
#   2. PowerDevil suspends the VM after a few minutes -> VM appears frozen
#      in the VNC viewer and virtio resume is not always reliable.
# Plasma reads these from /usr/local/etc/xdg/ as system-wide defaults; the
# user's ~/.config/* would override but the autologin root has none on a
# fresh image.
mkdir -p /usr/local/etc/xdg
cat <<EOF > /usr/local/etc/xdg/kscreenlockerrc
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF
cat <<EOF > /usr/local/etc/xdg/powermanagementprofilesrc
[AC]
icon=battery-charging

[AC][SuspendSession]
suspendType=0

[AC][DimDisplay]
idleTime=0

[AC][DPMSControl]
idleTime=0
lockBeforeTurnOff=0

[Battery]
icon=battery-060

[Battery][SuspendSession]
suspendType=0

[Battery][DimDisplay]
idleTime=0

[Battery][DPMSControl]
idleTime=0
lockBeforeTurnOff=0

[LowBattery]
icon=battery-low

[LowBattery][SuspendSession]
suspendType=0

[LowBattery][DimDisplay]
idleTime=0

[LowBattery][DPMSControl]
idleTime=0
lockBeforeTurnOff=0
EOF
echo "--- 8. Starting KDE ---"
service dbus restart
rm -f /tmp/.X*-lock
rm -rf /tmp/.X11-unix

nohup service sddm restart > /dev/null 2>&1 &


echo "--- Setup Complete! Root is logging in... ---"


