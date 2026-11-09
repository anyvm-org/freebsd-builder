#some tasks run in the VM as soon as the vm is up






echo '=================== start ===='





service ntpd enable

service ntpd start

kldload  fusefs




echo "Applying fastest SSH boot optimizations..."

# Root filesystem type ("zfs" on the 15.x -zfs images, "ufs" on the -ufs
# variants, 14.x and older, and the powerpc64 ISO installs).
_rootfs=$(mount -p | awk '$2 == "/" { print $3; exit }')
echo "root filesystem: ${_rootfs:-unknown}"

# Optimize loader.conf
cat <<EOF >/boot/loader.conf
autoboot_delay="0"
loader_logo="NO"
loader_menu_title="NO"

hw.hpet.enable=0

# Do not attach the Hyper-V VMBus driver. Under QEMU+WHPX (Windows hosts)
# the guest sees Hyper-V CPUID ("Microsoft Hv"), attaches vmbus0, and stalls
# ~110s in the root-mount hold negotiating with a VMBus provider QEMU never
# supplies (boot 130s -> 18s with this hint). anyvm always runs this image
# under QEMU with virtio devices, never under real Hyper-V, so no loss.
hint.vmbus.0.disabled="1"
EOF

# The loader.conf above REPLACES upstream's, which on a ZFS image is what
# carried zfs_load -- so a ZFS root must get it back or the image no longer
# boots. A UFS root does not load zfs.ko at boot: that matches upstream's
# UFS images, and a ZFS developer can kldload a freshly built zfs.ko
# without unloading the base one first (anyvm-org/freebsd-builder#1).
# zpool/zfs still autoload the module on first use (libzfs kldloads it).
# Fail-safe: anything not positively identified as UFS keeps the ZFS lines.
if [ "${_rootfs}" != "ufs" ]; then
cat <<EOF >>/boot/loader.conf

vfs.zfs.vdev.trim_enable=0
vfs.zfs.load="YES"
zfs_load="YES"
EOF
sysrc zfs_enable="YES"
fi

# UFS root with a pkg-managed base (pkgbase, 15.x): the `pkg upgrade -y`
# at the end of this hook rewrites the whole base when a patch level is
# out, and on UFS the replaced files' freed blocks stay allocated in the
# qcow2 -- the same bloat vm_finalize.sh fixes with `zpool trim` on ZFS
# (vmactions/freebsd-vm#148). UFS cannot TRIM a read-write root after the
# fact (fsck_ffs -E and tunefs both need it read-only or unmounted), so
# this one-shot rc.d script does it at the post-build reboot, while the
# kernel still has / mounted read-only, before rc.d/root remounts it
# read-write. vm_finalize.sh removes the script again, so the published
# image never runs it. A base that is not pkg-managed (14.x and older,
# powerpc64) does not churn like this and keeps its build unchanged.
# `pkg -N` first: on a system without pkg, plain `pkg` would start the
# bootstrap prompt and read this script's own stdin.
if [ "${_rootfs}" = "ufs" ] && pkg -N >/dev/null 2>&1 \
    && pkg which -q /bin/sh >/dev/null 2>&1 </dev/null; then
cat <<'EOF' >/etc/rc.d/anyvm_ufstrim
#!/bin/sh
#
# PROVIDE: anyvm_ufstrim
# REQUIRE: fsck
# BEFORE: root
# KEYWORD: nojail
#
# One-shot, image build only: installed by freebsd-builder's
# hooks/vm_postBuild.sh and removed by its hooks/vm_finalize.sh. TRIMs
# every free block of the UFS root while / is still read-only.

. /etc/rc.subr

name="anyvm_ufstrim"
desc="TRIM free blocks of the read-only UFS root (image build only)"
start_cmd="anyvm_ufstrim_start"
stop_cmd=":"

anyvm_ufstrim_start()
{
	set -- $(mount -p | awk '$2 == "/" { print $1, $3, $4; exit }')
	if [ "$2" != "ufs" ]; then
		return 0
	fi
	case ",$3," in
	*,ro,*) ;;
	*)
		echo "anyvm_ufstrim: / is not read-only, skipping"
		return 0
		;;
	esac
	echo "anyvm_ufstrim: TRIMming free blocks of $1"
	fsck_ffs -E -y "$1"
	_rc=$?
	echo "anyvm_ufstrim: fsck_ffs -E exited $_rc"
	# / is read-only here, so leave the result for vm_finalize.sh to log.
	kenv anyvm_ufstrim="rc=$_rc" >/dev/null 2>&1
	# Same handling as rc.d/fsck: 4 = the mounted root was modified and
	# could not be reloaded, so reboot onto a fresh mount (this script runs
	# again and finds nothing to fix); anything else nonzero aborts the
	# boot, so the build's login wait fails instead of shipping the image.
	case $_rc in
	0)
		;;
	4)
		echo "anyvm_ufstrim: root was modified, rebooting"
		reboot
		stop_boot true
		;;
	*)
		echo "anyvm_ufstrim: fsck_ffs failed, aborting boot"
		stop_boot true
		;;
	esac
}

load_rc_config $name
run_rc_command "$1"
EOF
chmod 555 /etc/rc.d/anyvm_ufstrim
echo "installed /etc/rc.d/anyvm_ufstrim (runs at the post-build reboot)"
fi

# Enable parallel RC
sysrc rc_parallel="YES"

# Required services
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

# gnome: the x11/gnome metaport (gnome / gnome-lite) is still in the ports
# tree, but a /latest package run that fails one of its run dependencies
# ships the branch WITHOUT it, and `pkg install gnome-lite` then dies with
# "No packages available to install matching 'gnome-lite'" (15.0-gnome and
# 15.1-gnome, 2026-09-14; /quarterly still had gnome-lite 47). Probe the
# catalogue we just fetched and fall back to quarterly when the metaport
# is missing -- base + desktop then come from one branch, the same
# ABI-consistent arrangement kde6 uses above. Self-healing: once /latest
# carries the metaport again the probe succeeds and latest is kept.
case "$VM_RELEASE" in
  *gnome*)
    if ! pkg rquery %n gnome-lite 2>/dev/null | grep -qx gnome-lite; then
      echo "gnome: gnome-lite absent from the /latest catalogue; falling back to quarterly"
      sed -i '' 's#/latest#/quarterly#g' /etc/pkg/FreeBSD.conf
      pkg update -f
    fi
    ;;
esac
# After switching the repo from quarterly to latest, bring all already-installed
# packages up to the latest branch so their ABI matches anything we install
# afterwards. Otherwise a stale base library (e.g. glib 2.84) can collide with
# a freshly installed consumer (e.g. gtk4 built against glib 2.86), giving
# undefined-symbol errors at runtime -- which is what crashed gnome-shell into
# the "Oh no! Something has gone wrong" screen at GDM.
pkg upgrade -y

# UFS TRIM pending (see anyvm_ufstrim above): drop the fetched packages now,
# so the post-build reboot trims their blocks too. vm_finalize.sh's
# `pkg clean` runs after that reboot, and on UFS whatever it frees stays
# allocated in the qcow2 -- measured 3.33 GiB allocated against 2.6 GiB
# used on 15.1-ufs-aarch64, the gap being the ~0.55 GiB pkgbase cache.
# The files are removed directly rather than with `pkg clean -ay`: that
# refuses with "No package database installed" until a ports catalogue
# exists, which on riscv64 only happens later (VM_INSTALL_SCRIPT points pkg
# at anyvm-org/freebsd-pkg-repo), and it left 469 MiB behind on 15.1-ufs-
# riscv64. The cache is only a download cache; pkg refetches on demand.
if [ -e /etc/rc.d/anyvm_ufstrim ]; then
  find /var/cache/pkg -name '*.pkg' -exec rm -f {} + || true
  du -sh /var/cache/pkg || true
fi

echo "Done. Reboot to apply all optimizations."






