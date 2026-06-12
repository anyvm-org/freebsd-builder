# host_enablessh.py -- enable-ssh stage dispatch for freebsd-builder.
#
# For VM_CLOUDINIT=1 confs (BASIC-CLOUDINIT images, 15.1+) there is
# nothing to do here: the NoCloud seed ISO built by host_prepareImage.py
# already made cloud-init bake the host pubkey into
# /root/.ssh/authorized_keys and open up sshd on first boot. The console
# typing dance would be redundant (and is the most fragile stage we have).
#
# For every other conf this hook replicates main()'s default dispatch
# EXACTLY, so all existing releases keep their proven behavior. (run_hook
# returns True merely because this file exists, which makes main() skip
# its own dispatch -- hence the explicit replication here.)

if env("VM_CLOUDINIT"):
    log("enablessh: cloud-init seed already provisioned root ssh access; "
        "skipping the console enable-ssh stage")
elif env("VM_USE_SSHROOT_BUILD_SSH"):
    _enable_ssh_root_branch(sshport)
else:
    _enable_ssh_console_branch()
