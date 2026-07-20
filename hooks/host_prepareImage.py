# host_prepareImage.py -- generate a cloud-init NoCloud seed ISO at build
# time for confs that set VM_CLOUDINIT=1 (the FreeBSD BASIC-CLOUDINIT VM
# images, used from 15.1 on). The seed and its inputs are created fresh in
# the build cwd on every run and are never committed to git (.gitignore'd;
# they embed the per-runner host pubkey anyway, so a committed copy would
# be useless).
#
# For confs without VM_CLOUDINIT this hook is a no-op, so every existing
# release keeps its exact behavior.
#
# How it works: the BASIC-CLOUDINIT images ship net/cloud-init enabled.
# On first boot cloud-init scans for a datasource; a CDROM with iso9660
# volume label "cidata" containing user-data + meta-data is the NoCloud
# seed. Our user-data:
#   * creates no default user (users: [])
#   * appends the host id_rsa.pub to /root/.ssh/authorized_keys
#   * opens sshd up exactly like enablessh.txt does for other releases
#     (PermitRootLogin/PermitEmptyPasswords/PasswordAuthentication/
#      AcceptEnv */StrictModes no)
#   * touches /etc/cloud/cloud-init.disabled at the end, so every later
#     boot -- including anyvm runtime boots of the published artifact --
#     skips the datasource search entirely.
# build.py attaches the ISO via VM_SEED_ISO (set below) as a data-only
# CDROM on every QEMU launch.

if not env("VM_CLOUDINIT"):
    log("prepareImage: VM_CLOUDINIT not set; nothing to do")
else:
    log("prepareImage: building cloud-init NoCloud seed ISO")

    _idrsa = os.path.join(HOME, ".ssh", "id_rsa")
    if not os.path.exists(_idrsa):
        run(["ssh-keygen", "-f", _idrsa, "-q", "-N", ""])
    _pub = open(_idrsa + ".pub").read().strip()

    _seed_dir = wf("seed-data")
    os.makedirs(_seed_dir, exist_ok=True)
    with open(os.path.join(_seed_dir, "meta-data"), "w") as f:
        f.write("instance-id: anyvm-%s-%s\n" % (env("VM_OS_NAME"), env("VM_RELEASE")))
        f.write("local-hostname: %s\n" % env("VM_OS_NAME"))
    with open(os.path.join(_seed_dir, "user-data"), "w") as f:
        f.write("#cloud-config\n")
        f.write("users: []\n")
        f.write("disable_root: false\n")
        # The BASIC-CLOUDINIT image's builtin config upgrades the whole
        # pkgbase set on first boot (~27 packages). Under TCG that blows
        # way past VM_LOGIN_MAX_SECONDS, start_and_wait force-kills the VM
        # mid-provisioning, and the half-run cloud-init never bakes our
        # key (seen on 15.1-RC3 aarch64). Disable it explicitly -- we want
        # the image exactly as shipped, deterministic, not silently
        # upgraded at build time.
        f.write("package_update: false\n")
        f.write("package_upgrade: false\n")
        f.write("runcmd:\n")
        f.write("  - mkdir -p /root/.ssh\n")
        f.write("  - chmod 700 /root/.ssh\n")
        # Generate the GUEST's own keypair, exactly like the console-path
        # enablessh.txt does. main() exports its pubkey as the
        # <name>-id_rsa.pub release asset (used so the guest can `ssh host`
        # back over slirp); without this the export is a 0-byte file and
        # the GitHub release upload rejects it ("size must be greater than
        # or equal to 1" -- seen on the v2.1.7 15.1 job).
        f.write("  - rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub\n")
        f.write("  - ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -N \"\"\n")
        f.write("  - echo '%s' >> /root/.ssh/authorized_keys\n" % _pub)
        f.write("  - chmod 600 /root/.ssh/authorized_keys\n")
        f.write("  - printf 'PermitRootLogin yes\\nPermitEmptyPasswords yes\\n"
                "PasswordAuthentication yes\\nAcceptEnv *\\nStrictModes no\\n'"
                " >> /etc/ssh/sshd_config\n")
        f.write("  - sysrc sshd_enable=YES\n")
        # Same sendmail shutdown as enablessh.txt -- keeps the cloudinit
        # artifact behaviorally identical to every other release (no
        # listening MTA, faster boot).
        f.write("  - sysrc sendmail_enable=NONE sendmail_submit_enable=NO "
                "sendmail_outbound_enable=NO sendmail_msp_queue_enable=NO\n")
        f.write("  - service sendmail onestop || true\n")
        f.write("  - service sshd restart || service sshd start\n")
        f.write("  - touch /etc/cloud/cloud-init.disabled\n")
    log("prepareImage: user-data:\n%s"
        % open(os.path.join(_seed_dir, "user-data")).read())

    # Build the iso9660 image with volume id "cidata" (that exact volid is
    # what cloud-init's NoCloud datasource looks for). Prefer genisoimage,
    # fall back to xorriso's mkisofs emulation (preinstalled on the GitHub
    # ubuntu runners and most dev boxes); install genisoimage as a last
    # resort.
    # build.py keeps all generated files under WORKDIR (wf()); the seed ISO is
    # one of them, and it is handed back to build_qemu_args via VM_SEED_ISO.
    _seed_iso = wf("seed.iso")
    try: os.remove(_seed_iso)
    except OSError: pass
    if shutil.which("genisoimage"):
        run(["genisoimage", "-output", _seed_iso, "-volid", "cidata",
             "-joliet", "-rock", _seed_dir])
    elif shutil.which("xorriso"):
        run(["xorriso", "-as", "mkisofs", "-output", _seed_iso,
             "-volid", "cidata", "-joliet", "-rock", _seed_dir])
    else:
        _run_quiet(["sudo", "-E", "apt-get", "install", "-y", "-qq",
                    "genisoimage"], env={**os.environ,
                                         "DEBIAN_FRONTEND": "noninteractive"})
        run(["genisoimage", "-output", _seed_iso, "-volid", "cidata",
             "-joliet", "-rock", _seed_dir])
    if not os.path.exists(_seed_iso):
        log("prepareImage: FAILED to build seed.iso")
        sys.exit(1)
    log("prepareImage: seed.iso ready (%d bytes)" % os.path.getsize(_seed_iso))

    # Hand the seed to build_qemu_args (gated attach on every launch).
    os.environ["VM_SEED_ISO"] = _seed_iso
