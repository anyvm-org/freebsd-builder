#!/bin/sh
# Bootstrap pkg for EOL FreeBSD releases from the preserved SGGS package
# repository, then install the package set requested by build.py.
set -eu

: "${ANYVM_PKG_PATH:?VM_PKG_PATH is required}"
: "${ANYVM_PKGS:?VM_PRE_INSTALL_PKGS is required}"

# FreeBSD 10/11's base CA bundles predate the mirror's current certificate
# chain. Disable only the HTTPS peer check for those two preserved repositories;
# pkg still authenticates repository metadata/packages with FreeBSD fingerprints.
case "${ANYVM_PKG_PATH}" in
  *FreeBSD:1[01]:*) export SSL_NO_VERIFY_PEER=yes ;;
esac

cat >/etc/pkg/FreeBSD.conf <<EOF
FreeBSD: {
  url: "${ANYVM_PKG_PATH}",
  mirror_type: "none",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
EOF

env ASSUME_ALWAYS_YES=yes PACKAGESITE="${ANYVM_PKG_PATH}" /usr/sbin/pkg bootstrap -f
ASSUME_ALWAYS_YES=yes IGNORE_OSVERSION=yes /usr/sbin/pkg update -f
# ANYVM_PKGS is a trusted package list from this repository's conf files.
ASSUME_ALWAYS_YES=yes IGNORE_OSVERSION=yes /usr/sbin/pkg install -y ${ANYVM_PKGS}
