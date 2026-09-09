

[![Build](https://github.com/anyvm-org/freebsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/freebsd-builder/actions/workflows/build.yml)

Latest: v2.2.7


The image builder for `freebsd`


All the supported releases are here:



| Release | x86_64 | aarch64(arm64) | riscv64 | powerpc64 |
|---------|---------|---------|---------|---------|
| 15.1 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) |
| 15.0 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) |
| 14.5 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 14.4 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 14.3 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 14.2 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 14.1 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 14.0 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 13.5 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 13.4 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | —[^rv-stub] | ✅ (nfs,scp,tar) |
| 13.3 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 13.2 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) |
| 12.4 | ✅ (nfs,scp,tar) | ✅ (nfs,scp,tar) | —[^rv-none] | —[^ppc-panic] |

<!-- arch-label: aarch64 = aarch64(arm64) -->
<!-- absent: 13.4-riscv64 rv-stub -->
<!-- absent: 12.4-riscv64 rv-none -->
<!-- absent: 12.4-powerpc64 ppc-panic -->
<!-- desktop-header: FreeBSD desktop images (x86_64): -->

<!-- shelved: 16.0 -->
<!-- shelved: 16.0-aarch64 -->
[^rv-none]: riscv64 first became a FreeBSD release architecture in 13.0, so there is no 12.4 riscv64 image to build.
[^rv-stub]: The upstream 13.4 riscv64 `qcow2.xz` on the FreeBSD archive mirror is a broken 32-byte stub rather than a real disk image, so this target cannot be built.
[^ppc-panic]: FreeBSD 12.x powerpc64 panics in early boot under QEMU pseries -- its PAPR hash-MMU backend hard-requires 16 MiB large pages, which QEMU advertises only when guest RAM is backed by host huge pages. Reworked in FreeBSD 13.0, so 13.2+ powerpc64 build fine; 12.4 (EOL) is dropped.

> **Note:** The 15.x riscv64 images install their packages from
> [anyvm-org/freebsd-pkg-repo](https://github.com/anyvm-org/freebsd-pkg-repo),
> because pkg.FreeBSD.org publishes no riscv64 packages at all. That
> repository is the ports tree built with poudriere under qemu-user and
> published as signed GitHub release assets; the image carries its public
> key and one repository block per shard, so `pkg install` works out of the
> box and `rsync`/`sshfs` sync are available. Packages published into
> shards created after an image was built are not in that image's copy of
> the repository list -- refetch `anyvm.conf` from the index release to see
> them. 13.x and 14.x riscv64 have no such repository (it is built for
> `FreeBSD:15:riscv64`) and keep the package-less sync methods.

> **Note:** FreeBSD 16.0/16.0-aarch64 confs are kept on disk but not yet
> opted into the build matrix -- 16.0 is a CURRENT snapshot
> (`16.0-CURRENT`), not a stable release
> (`VM_VHD_LINK=".../snapshots/VM-IMAGES/16.0-CURRENT/..."`), and has never
> had a table row at HEAD (verified against
> `git show HEAD:.github/data/table.md`), so it is shelved rather than
> no-build. Delete the two `shelved:` lines above to enable it once 16.0
> stabilizes.

How the images are built:

Each image is built automatically in the
[anyvm-org/freebsd-builder](https://github.com/anyvm-org/freebsd-builder)
repo's GitHub Actions. Most releases start from the official FreeBSD
VM images (`.qcow2.xz`) published by the FreeBSD project; the builder
boots the image in QEMU, enables ssh, pre-installs the packages listed
in the conf, and exports the disk as a compressed qcow2 image.
Architectures with no official VM image (powerpc64) are instead
installed unattended from the official FreeBSD release installer ISOs.

Upstream media (see https://www.freebsd.org/where/):
current releases from https://download.freebsd.org/releases/VM-IMAGES/
and EOL releases from https://archive.freebsd.org/old-releases/VM-IMAGES/.



FreeBSD desktop images (x86_64):

| Release | x86_64 | aarch64(arm64) | riscv64 | powerpc64 |
|---------|---------|---------|---------|---------|
| 15.1-xfce | ✅ | — | — | — |
| 15.1-kde6 | ✅ | — | — | — |
| 15.1-gnome | ✅ | — | — | — |
| 15.0-xfce | ✅ | — | — | — |
| 15.0-kde6 | ✅ | — | — | — |
| 15.0-gnome | ✅ | — | — | — |



How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/freebsd-16.0.conf
    ```
   
