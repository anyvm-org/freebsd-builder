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

> **Note:** FreeBSD 16.0/16.0-aarch64 confs are kept on disk but not yet
> opted into the build matrix -- 16.0 is a CURRENT snapshot
> (`16.0-CURRENT`), not a stable release
> (`VM_VHD_LINK=".../snapshots/VM-IMAGES/16.0-CURRENT/..."`), and has never
> had a table row at HEAD (verified against
> `git show HEAD:.github/data/table.md`), so it is shelved rather than
> no-build. Delete the two `shelved:` lines above to enable it once 16.0
> stabilizes.
