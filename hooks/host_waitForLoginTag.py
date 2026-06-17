# Wait for the guest to reach the login prompt after a fresh boot.
#
# Host-side hook: run by base-builder/build.py via exec() in this module's
# globals (it calls the build.py host functions waitForText / inputKeys /
# env, NOT guest shell commands). start_and_wait() invokes run_hook(
# "waitForLoginTag") right after openConsole(); returning here lets
# start_and_wait skip its own default waitForText(VM_LOGIN_TAG) wait.
#
# riscv64 boots through u-boot into the FreeBSD loader menu and needs a nudge
# past it (select "Boot Options", then Enter) before the login prompt appears.
# Every other arch just waits for the login banner. This restores the logic of
# the old hooks/waitForLoginTag.sh, which the vbox.sh -> build.py migration
# left orphaned (a bare-named .sh that run_hook never matched).

if env("VM_ARCH") == "riscv64":
    waitForText("7. Boot Options", "20")
    time.sleep(20)
    inputKeys("enter")

waitForText(env("VM_LOGIN_TAG"))
