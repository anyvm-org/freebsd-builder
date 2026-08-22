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
