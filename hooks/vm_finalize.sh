

#enable autologin with root in the console

sed -E -i '' 's|ttyv0[[:space:]]+"/usr/libexec/getty Pc"|ttyv0	  "/usr/libexec/getty autologin"|' /etc/ttys



# Image-slimming cleanup. finalize runs AFTER VM_EXTRA_SCRIPT, so the
# gnome/kde6/xfce desktop installs and their package churn are covered too.
#
# FreeBSD 15+ delivers the base system via pkgbase, so the `pkg upgrade -y`
# in postBuild rewrites the whole patched base (kernel + dbg + tests +
# lib32, ~3 GB) whenever a patch level is out (e.g. 15.1-p1 between builder
# v2.2.3 and v2.2.4). On the ZFS images the replaced files' freed blocks
# are neither zeroed nor trimmed, so they stay allocated in the qcow2 and
# the export-time `qemu-img convert -S 4k` sparsify cannot reclaim them --
# that alone nearly doubled the v2.2.4 images (3.4 -> 6.3 GiB,
# vmactions/freebsd-vm#148). Zero-filling free space is NOT a fix on ZFS:
# lz4 compression collapses the zeros without touching the stale blocks.
# TRIM is.

echo "=== finalize: image cleanup ==="

# Drop fetched package archives (/var/cache/pkg): ~0.5 GB after a pkgbase
# upgrade, multiple GB on the desktop variants.
pkg clean -ay || true

# ZFS images (15.0+): TRIM all free space so QEMU (discard=unmap) punches
# the freed blocks out of the qcow2. -w waits for the trim to finish before
# the build shuts the VM down. UFS images (<= 14.x) have no pool, so the
# loop body never runs there. The legacy loader tunable
# vfs.zfs.vdev.trim_enable=0 set in postBuild only affects pre-OpenZFS
# kernels and does not block manual `zpool trim` on 13+.
for _pool in $(zpool list -H -o name 2>/dev/null); do
    echo "Trimming pool ${_pool}..."
    zpool trim -w "${_pool}" || echo "zpool trim ${_pool} failed (non-fatal)"
    zpool status -t "${_pool}" || true
done

df -h || true
echo "=== finalize: image cleanup done ==="

: > ~/.sh_history






