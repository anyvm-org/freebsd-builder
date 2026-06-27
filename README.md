

[![Build](https://github.com/anyvm-org/freebsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/freebsd-builder/actions/workflows/build.yml)

Latest: v2.2.3


The image builder for `freebsd`


All the supported releases are here:



| Release | x86_64  | aarch64(arm64) | riscv64  | powerpc64 |
|---------|---------|---------|-----------------|-----------|
| 15.1    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 15.0    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 14.4    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 14.3    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 14.2    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 14.1    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 14.0    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 13.5    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 13.4    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |     —[^rv-stub]    |  ✅ (nfs,scp)    |
| 13.3    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 13.2    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (rsync,scp,sshfs,nfs)    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |
| 12.4    |  ✅ (nfs,scp)    |  ✅ (nfs,scp)    |     —[^rv-none]    |     —[^ppc-panic]    |

[^rv-none]: riscv64 first became a FreeBSD release architecture in 13.0, so there is no 12.4 riscv64 image to build.
[^rv-stub]: The upstream 13.4 riscv64 `qcow2.xz` on the FreeBSD archive mirror is a broken 32-byte stub rather than a real disk image, so this target cannot be built.
[^ppc-panic]: FreeBSD 12.x powerpc64 panics in early boot under QEMU pseries -- its PAPR hash-MMU backend hard-requires 16 MiB large pages, which QEMU advertises only when guest RAM is backed by host huge pages. Reworked in FreeBSD 13.0, so 13.2+ powerpc64 build fine; 12.4 (EOL) is dropped.



FreeBSD desktop images (x86_64):

| Release | x86_64  | aarch64(arm64) | riscv64  | powerpc64 |
|---------|---------|---------|-----------------|-----------|
| 15.1-xfce    |  ✅     |  —    |           —    |     —    |
| 15.1-gnome    |  ✅     |  —    |           —    |     —    |
| 15.1-kde6    |  ✅     |  —    |           —    |     —    |
| 15.0-xfce    |  ✅     |  —    |           —    |     —    |
| 15.0-gnome    |  ✅     |  —    |           —    |     —    |
| 15.0-kde6    |  ✅     |  —    |           —    |     —    |


How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/freebsd-16.0.conf
    ```
   
