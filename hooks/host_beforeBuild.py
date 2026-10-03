# host_beforeBuild.py -- pick the FreeBSD mirror for the install media at
# build time instead of trusting the one written into the conf.
#
# Host-side hook, exec()'d into build.py's globals (env/log are build.py
# functions). run_hook("beforeBuild") is the first hook main() calls, well
# before the VM_ISO_LINK / VM_VHD_LINK branch reads its URL from the
# environment, so rewriting os.environ here is enough: no engine change.
#
# Why: FreeBSD serves CURRENT releases from download.freebsd.org/releases
# and moves a release to archive.freebsd.org/old-releases the moment it
# goes EOL. The two are NOT kept in sync, and nothing tells us when the
# move happens -- a conf pinned to download just starts 404ing. That is
# what turned all four 14.3 jobs red on 2026-10-03 (run 37132477737:
# 14.3 left download after 14.5 shipped; every asset was already on
# archive). hooks/host_installOpts.py already probes both mirrors for the
# powerpc64 dist sets for the same reason; this extends the idea to the
# qcow2 / ISO the build starts from, so the NEXT EOL (14.4, then 14.5)
# does not need a hand edit of its confs.
#
# Rules, mirroring _fbsd_url_ok in host_installOpts.py:
#   * only a URL on one of the two known hosts is touched; anything else
#     (a conf already on archive, a non-FreeBSD mirror) is left alone;
#   * only a DECISIVE 404 on the conf's URL triggers the swap, and only if
#     the swapped URL probes 2xx -- a transient error keeps the original
#     URL so download() surfaces the real failure rather than this hook
#     masking it behind a guess;
#   * the probe is a 1-byte ranged GET, retried 3 times on non-404
#     errors, same as the dist-set probe.

import os
import time
import urllib.error
import urllib.request

_FBSD_HOST_PAIRS = (
    ("https://download.freebsd.org/releases/",
     "https://archive.freebsd.org/old-releases/"),
    ("https://archive.freebsd.org/old-releases/",
     "https://download.freebsd.org/releases/"),
)


def _fbsd_probe(url):
    """'ok' (2xx), 'missing' (a definitive 404), or 'error' (anything else
    after 3 attempts)."""
    for _attempt in range(3):
        req = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return "ok" if resp.status < 400 else "error"
        except urllib.error.HTTPError as _e:
            if _e.code == 404:
                return "missing"
            log("freebsd beforeBuild: probe %s HTTP %s (attempt %d)"
                % (url, _e.code, _attempt + 1))
        except Exception as _e:
            log("freebsd beforeBuild: probe %s err %s (attempt %d)"
                % (url, _e, _attempt + 1))
        time.sleep(3)
    return "error"


for _var in ("VM_ISO_LINK", "VM_VHD_LINK"):
    _url = env(_var)
    if not _url:
        continue
    _alt = None
    for _from, _to in _FBSD_HOST_PAIRS:
        if _url.startswith(_from):
            _alt = _to + _url[len(_from):]
            break
    if _alt is None:
        continue
    _state = _fbsd_probe(_url)
    if _state == "ok":
        log("freebsd beforeBuild: %s is live on its configured mirror" % _var)
        continue
    if _state != "missing":
        log("freebsd beforeBuild: %s probe inconclusive; keeping %s"
            % (_var, _url))
        continue
    if _fbsd_probe(_alt) == "ok":
        log("freebsd beforeBuild: %s moved mirrors; using %s" % (_var, _alt))
        os.environ[_var] = _alt
    else:
        log("freebsd beforeBuild: %s is 404 on BOTH mirrors (%s, %s); "
            "leaving the conf URL so download() reports it" % (_var, _url, _alt))
