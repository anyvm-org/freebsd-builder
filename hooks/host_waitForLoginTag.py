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
    # Best effort on purpose -- leave this one non-fatal. It times out in
    # perfectly good builds (every green riscv64 job in run 30265218462 logged
    # "Timeout for text: 7. Boot Options"); the loader menu is often already
    # past by the time we look, and the blind `enter` below is harmless then.
    waitForText("7. Boot Options", "20")
    time.sleep(20)
    inputKeys("enter")

# The login banner IS the gate, so it must be bounded and fatal.
#
# It used to be an unbounded waitForText(VM_LOGIN_TAG): with no second argument
# waitForText polls forever, so a guest that panicked during boot pinned the job
# until the 6 h CI ceiling or a human killed it. Sibling builders have burned
# 2 h, 3.5 h and 5 h 40 m exactly this way (netbsd opts files, midnightbsd
# 3.2.4).
#
# Fatal is safe: across all 51 green jobs of run 30265218462 the login tag never
# once timed out (the only timeouts were the riscv64 loader nudge above). 900 s
# is a crash backstop, not a budget -- it must clear the slowest emulated arch
# (riscv64/powerpc64 under TCG), which is why it is far above any healthy boot.
#
# Why exit rather than return quietly: start_and_wait() treats the mere presence
# of a waitForLoginTag hook as success (`if run_hook(...): return 0`), so it
# applies neither VM_LOGIN_MAX_SECONDS nor its force-kill-and-reboot reroll
# here. Returning after a failed wait would march the pipeline on against a VM
# that never booted.
if waitForText(env("VM_LOGIN_TAG"), "900") != 0:
    log("FATAL: guest never reached the login banner (%s)." % env("VM_LOGIN_TAG"))
    log("       The guest most likely panicked or hung during boot -- check the "
        "screen dump above. Aborting instead of waiting forever.")
    sys.exit(1)
