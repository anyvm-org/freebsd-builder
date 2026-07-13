#some tasks run in the VM as soon as the vm is up






echo '=================== start ===='





service ntpd enable

service ntpd start

kldload  fusefs




echo "Applying fastest SSH boot optimizations..."

# Optimize loader.conf
cat <<EOF >/boot/loader.conf
autoboot_delay="0"
loader_logo="NO"
loader_menu_title="NO"

vfs.zfs.vdev.trim_enable=0
vfs.zfs.load="YES"
zfs_load="YES"

hw.hpet.enable=0

# Do not attach the Hyper-V VMBus driver. Under QEMU+WHPX (Windows hosts)
# the guest sees Hyper-V CPUID ("Microsoft Hv"), attaches vmbus0, and stalls
# ~110s in the root-mount hold negotiating with a VMBus provider QEMU never
# supplies (boot 130s -> 18s with this hint). anyvm always runs this image
# under QEMU with virtio devices, never under real Hyper-V, so no loss.
hint.vmbus.0.disabled="1"
EOF

# Enable parallel RC
sysrc rc_parallel="YES"

# Required services
sysrc zfs_enable="YES"
sysrc syslogd_enable="YES"
sysrc cron_enable="YES"





# Disable unnecessary services
sysrc growfs_enable="NO"
sysrc growfs_fstab_enable="NO"
sysrc kldxref_enable="NO"
sysrc zvol_enable="NO"
sysrc zpoolupgrade_enable="NO"
sysrc zpoolreguid_enable="NO"

sysrc mixer_enable="NO"
sysrc rctl_enable="NO"
sysrc virecover_enable="NO"
sysrc motd_enable="NO"
sysrc savecore_enable="NO"
sysrc utx_enable="NO"
sysrc bgfsck_enable="NO"
sysrc dmesg_enable="NO"


sysrc ipv6_network_interfaces="none"






echo 'ifconfig_em0="DHCP"' >> /etc/rc.conf
echo 'ifconfig_vtnet0="DHCP"' >> /etc/rc.conf

cat << 'EOF' >> /etc/rc.local
for iface in $(ifconfig -l); do
    if [ "$iface" != "lo0" ]; then
        dhclient $iface >/dev/null 2>&1
    fi
done
EOF
chmod +x /etc/rc.local



# Switch the ports repo from quarterly to latest so the freshly-installed
# desktop packages match the upgraded base ABI (fixes the gnome-shell glib
# 2.84-vs-2.86 mismatch noted below).
#
# EXCEPTION: kde6 stays on quarterly. FreeBSD currently ships the Plasma 6
# metaports (plasma6-plasma / plasma6-plasma-desktop / plasma6-plasma-workspace)
# only in /quarterly -- the /latest build for FreeBSD:15:amd64 was pulled, so
# `pkg install plasma6-plasma` fails there with "No packages available". Keeping
# kde6 all-quarterly (base + plasma both quarterly) is ABI-consistent and has
# the packages. VM_RELEASE arrives via the hook's ssh SendEnv.
case "$VM_RELEASE" in
  *kde6*)
    echo "kde6: keeping pkg repo on quarterly (Plasma 6 metaports absent from /latest)"
    ;;
  *)
    sed -i '' 's#/quarterly#/latest#g' /etc/pkg/FreeBSD.conf
    ;;
esac

rm -rf /var/db/pkg/repos/*
pkg update -f
# After switching the repo from quarterly to latest, bring all already-installed
# packages up to the latest branch so their ABI matches anything we install
# afterwards. Otherwise a stale base library (e.g. glib 2.84) can collide with
# a freshly installed consumer (e.g. gtk4 built against glib 2.86), giving
# undefined-symbol errors at runtime -- which is what crashed gnome-shell into
# the "Oh no! Something has gone wrong" screen at GDM.
pkg upgrade -y


echo "Done. Reboot to apply all optimizations."






