#some tasks run in the VM as soon as the vm is up






echo '=================== start ===='





service ntpd enable

service ntpd start

kldload  fusefs




echo "Applying fastest SSH boot optimizations..."

# Optimize loader.conf
cat <<EOF >/boot/loader.conf
autoboot_delay="0"
boot_mute="YES"
loader_logo="NO"
loader_menu_title="NO"

vfs.zfs.vdev.trim_enable=0
vfs.zfs.load="YES"
zfs_load="YES"

hw.hpet.enable=0
EOF

# Enable parallel RC
sysrc rc_parallel="YES"

# Required services
sysrc zfs_enable="YES"
sysrc syslogd_enable="YES"
sysrc cron_enable="YES"

# SSH
sysrc sshd_enable="YES"
sysrc sshd_flags="-o UseDNS=no -o PermitRootLogin=yes"

# Network optimization (use SYNCDHCP; disable background DHCP)
interface=$(ifconfig -l | awk '{print $1}')
sysrc ifconfig_${interface}="SYNCDHCP"
sysrc background_dhcp="NO"

# Disable unnecessary services
sysrc growfs_enable="NO"
sysrc growfs_fstab_enable="NO"
sysrc kldxref_enable="NO"
sysrc zvol_enable="NO"
sysrc zpoolupgrade_enable="NO"
sysrc zpoolreguid_enable="NO"
sysrc devmatch_enable="NO"
sysrc ip6addrctl_enable="NO"
sysrc ntpd_enable="NO"
sysrc mixer_enable="NO"
sysrc rctl_enable="NO"
sysrc virecover_enable="NO"
sysrc motd_enable="NO"
sysrc savecore_enable="NO"
sysrc utx_enable="NO"
sysrc bgfsck_enable="NO"
sysrc dmesg_enable="NO"

echo "Done. Reboot to apply all optimizations."






