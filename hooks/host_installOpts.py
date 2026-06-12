# host_installOpts.py -- drive the FreeBSD ISO install via bsdinstall's
# scripted mode instead of OCR-driving the 25-screen TUI. Used by the
# powerpc64 conf (no upstream cloud image), and any future FreeBSD ISO
# target (e.g. another arch whose VM-IMAGES dir is empty).
#
# Flow:
#   1. wait for "Console type [vt100]:" -> hit enter
#   2. wait for Welcome dialog -> pick "Live System" via accelerator 'L'
#   3. wait for getty login prompt on ttyu0 -> log in as root
#   4. push install_runner.sh through inputFileNC, which:
#        a. writes /tmp/installerconfig (PARTITIONS, DISTRIBUTIONS,
#           post-install rc.conf / sshd_config / root password)
#        b. runs `bsdinstall script /tmp/installerconfig` non-interactively
#        c. shutdown -p so QEMU exits cleanly and the outer build pipeline
#           moves on to the boot-from-disk phase via start_and_wait().
#
# Cloud-image FreeBSD targets never set VM_ISO_LINK, so run_hook("installOpts")
# is never called for them. No gating is needed inside this hook.

log("freebsd installOpts: scripted bsdinstall for %s ISO" % (env("VM_ARCH") or "x86_64"))

# Read the host's id_rsa.pub now (build.py creates it lazily later in
# _gen_enablessh_local, but we need it BEFORE we can write the
# installerconfig that bakes it into the guest). Mirror that bootstrap.
_idrsa = os.path.join(HOME, ".ssh", "id_rsa")
if not os.path.exists(_idrsa):
    run(["ssh-keygen", "-f", _idrsa, "-q", "-N", ""])
_HOST_PUBKEY = open(_idrsa + ".pub").read().rstrip("\n")
log("freebsd installOpts: host pubkey = %s..." % _HOST_PUBKEY[:60])

# Pre-download the distribution set on the HOST so the guest can fetch
# it over SLIRP (http://192.168.122.1:8000/...) without needing DNS.
# build.py's startWeb() already runs python3 -m http.server in cwd; we
# just need the files to be in cwd. Skip files already present so reruns
# don't re-download. Targets are powerpc64 -- update when the conf
# changes arch / release.
#
# The dist directory defaults to "<release>-RELEASE" but is overridable
# via VM_FBSD_DIST_DIR for pre-release images whose distfiles live in a
# differently-suffixed directory (e.g. the 15.1 conf tracks the RC
# image, whose sets are under powerpc/powerpc64/15.1-RC3/, while
# VM_RELEASE stays "15.1" so the artifact names don't carry the RC tag).
_FBSD_REL = env("VM_RELEASE") or "15.0"
_FBSD_ARCH_PATH = "powerpc/powerpc64"
_FBSD_DIST_DIR = env("VM_FBSD_DIST_DIR") or ("%s-RELEASE" % _FBSD_REL)
_FBSD_BASE_URL = ("https://download.freebsd.org/releases/%s/%s"
                  % (_FBSD_ARCH_PATH, _FBSD_DIST_DIR))
for _fn in ("MANIFEST", "kernel.txz", "base.txz"):
    if os.path.exists(_fn) and os.path.getsize(_fn) > 0:
        log("freebsd installOpts: %s already cached (%d bytes)"
            % (_fn, os.path.getsize(_fn)))
        continue
    _url = "%s/%s" % (_FBSD_BASE_URL, _fn)
    log("freebsd installOpts: pre-downloading %s" % _url)
    download(_url, _fn)
log("freebsd installOpts: distfiles cached: %s"
    % ", ".join("%s=%d" % (f, os.path.getsize(f))
                for f in ("MANIFEST", "kernel.txz", "base.txz")
                if os.path.exists(f)))


# Step 1: vt100 confirmation that appears BEFORE bsdinstall.
waitForText("Console type", "120")
time.sleep(2)
inputKeys("enter")

# Step 2: Welcome dialog. The three buttons are [Install] [Shell] [Live System],
# default focus is Install. Accelerator 'L' selects Live System. Send a sleep
# between letter and enter -- bsddialog wants a beat to register the keypress.
waitForText("Welcome to FreeBSD", "120")
time.sleep(2)
inputKeys("string L")
time.sleep(2)
inputKeys("enter")

# Step 3: the Live System path finishes booting and drops to a getty on ttyu0.
# Default login is root with no password. The `login:` prompt is the cue.
waitForText("login:", "600")
time.sleep(3)
inputKeys("string root")
time.sleep(1)
inputKeys("enter")

# Step 4: at the root shell. The login shell goes through /etc/login.conf,
# motd, and -- on some FreeBSD installer roots -- a `resizewin` invocation
# that BLOCKS reading stdin for a few seconds while it waits for a DSR
# (cursor-position report) response. While it blocks, any chars we type
# get fed to resizewin (discarded as malformed CPR) instead of the shell.
#
# We tried waitForText("resizewin: timeout") here but the screen tail
# already contained that string from bsdinstall's earlier startup, so the
# wait returned immediately and we sent the nc command into the void.
# Just sleep generously instead -- 30 s is enough for login to print motd,
# resizewin to time out, and the shell to start reading.
time.sleep(30)

# Then send a sentinel echo and wait for its output. If the sentinel
# echoes back, the shell is definitely ready for the install_runner.
string("echo MARK_SHELL_READY")
enter()
waitForText("MARK_SHELL_READY", "60")
time.sleep(2)

# The FreeBSD Live System boots with vtnet0 link-up but NO IPv4 address --
# bsdinstall normally calls dhclient itself when the user picks DHCP in
# the Network Configuration TUI, but we skipped that by going to Live
# System mode. Without an IPv4, `nc 192.168.122.1 ...` immediately
# returns "No route to host" (silently in the case of -q 0, since sh's
# stdin gets EOF and the pipeline finishes with no output). Run dhclient
# explicitly before inputFileNC.
string("dhclient vtnet0 && echo MARK_NET_OK || echo MARK_NET_FAIL")
enter()
waitForText("MARK_NET_OK", "60")
time.sleep(3)

# Write the installerconfig + runner locally and push via the inputFile NC
# mechanism (host nc -l, guest types `nc host | sh`). The runner sh stays
# attached to nc until EOF, then bsdinstall runs to completion, then poweroff
# brings QEMU down -- main() picks up at _wait_vm_down.
with open("install_runner.sh", "w") as f:
    f.write((
"""#!/bin/sh
# NOT using `set -e` so we see exactly where things fall over.
echo "==== install_runner: starting at $(date) ===="
echo "uname: $(uname -a)"

# IMPORTANT: the FreeBSD 15.0 powerpc64 disc1 ISO does NOT carry the
# binary distribution sets (only MANIFEST in /usr/freebsd-dist), and the
# Live System root is cd9660 read-only so dhclient cannot write
# /etc/resolv.conf -- bsdinstall's distfetch over its canonical mirror
# URL dies with "Transient resolver failure". Work around it by serving
# the .txz set from the host over SLIRP via the http.server that
# build.py's startWeb() already spawned on port 8000. The host
# pre-downloaded base.txz + kernel.txz + MANIFEST into the build cwd
# before this script ran, so http://192.168.122.1:8000/ exposes them
# directly to the guest -- no DNS needed.
DISTSITE="http://192.168.122.1:8000"
echo "MARK_DISTSITE=$DISTSITE"

cat > /tmp/installerconfig <<CFG
PARTITIONS=DEFAULT
DISTRIBUTIONS="kernel.txz base.txz"
BSDINSTALL_DISTSITE=$DISTSITE
nonInteractive=YES

#!/bin/sh
# Configure system and bake host pubkey directly into root's
# authorized_keys -- so the host can ssh in immediately after the
# post-install reboot without ANY console-paste / password handshake.
# We deliberately do NOT set a root password: the host's pubkey is the
# only credential and the build runs with empty-password root.
sysrc hostname="anyvm.org"
sysrc sshd_enable="YES"
sysrc ifconfig_vtnet0="DHCP"
sysrc ifconfig_vtnet0_ipv6="inet6 ifdisabled"
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'PermitEmptyPasswords yes' >> /etc/ssh/sshd_config
echo 'AcceptEnv *' >> /etc/ssh/sshd_config
echo 'StrictModes no' >> /etc/ssh/sshd_config
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys <<'KEYS'
${HOST_PUBKEY}
KEYS
chmod 600 /root/.ssh/authorized_keys
CFG
echo "installerconfig wc: $(wc -c < /tmp/installerconfig)"
echo "---- about to call bsdinstall ----"
export BSDINSTALL_DISTSITE="$DISTSITE"
bsdinstall script /tmp/installerconfig 2>&1
rc=$?
echo "==== bsdinstall script exit $rc ===="
if [ $rc -eq 0 ]; then
    echo "MARK_INSTALL_DONE"
    sync
    sleep 5
    shutdown -p now
else
    echo "INSTALL_FAILED -- bsdinstall returned $rc"
fi
""").replace("${HOST_PUBKEY}", _HOST_PUBKEY))

time.sleep(2)
inputFileNC("install_runner.sh")

# Block here until either install_runner prints its final success marker
# (MARK_INSTALL_DONE -- followed by shutdown -p, so the VM goes down) or
# its failure marker (INSTALL_FAILED -- the script does not power off, so
# we leave the VM up for forensics). Using a generous 2400 s (40 min)
# ceiling because TCG ppc64 has to extract base.txz over slow NAT.
log("freebsd installOpts: install_runner.sh pushed via nc; "
    "waiting for MARK_INSTALL_DONE or INSTALL_FAILED")
waitForText("MARK_INSTALL_DONE", "2400")
