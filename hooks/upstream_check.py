#!/usr/bin/env python3
# Print the newest -RELEASE version of EACH FreeBSD branch that has
# published VM images, ONE PER LINE, e.g. "13.5", "14.5", "15.1".
# Empty output means "nothing detected" and is not an error;
# a non-zero exit means detection itself is broken (network error, HTTP
# error, or a page that no longer matches the expected shape) and must be
# reported by the caller, never swallowed. A failure must NEVER print a
# plausible-but-wrong version -- the version is only printed after every
# step below has succeeded.
#
# Source of truth: https://download.freebsd.org/releases/VM-IMAGES/
# Fetched and confirmed by hand (2026-07-26): the directory is a plain
# Apache/lighttpd-style autoindex, one row per line, e.g.
#   <a href="15.1-RELEASE/" title="15.1-RELEASE">15.1-RELEASE/</a>
# The same listing also holds -ALPHA/-BETA/-RC snapshot directories, e.g.
#   14.4-BETA1/  14.4-BETA2/  14.4-BETA3/  14.4-RC1/  15.0-ALPHA1/
# alongside the real releases (14.3-RELEASE, 14.4-RELEASE, 15.0-RELEASE,
# 15.1-RELEASE at the time of checking). Only directories whose name ends
# in the literal "-RELEASE/" are real releases; anything else (snapshot
# suffix, or the unrelated README.txt entry) must never be picked.
#
# ONE LINE PER BRANCH, not just the newest overall. FreeBSD keeps
# several branches alive at once and publishes maintenance releases
# out of numeric order: 14.5-RELEASE appeared on 2026-09-04, AFTER
# 15.1. While this hook printed only the last-sorted directory it
# reported 15.1 every night, watch.py answered "already covered", and
# 14.5 had to be added by hand -- four confs plus conf/all.release.conf.
#
# The branch also decides the template, which matters here more than
# for most builders: 15.x VM images are named "-zfs.qcow2.xz" and 14.x
# are the plain ".qcow2.xz", so a 14.5 modelled on 15.1 would carry a
# download URL that does not exist.
#
# gendata.newest_per_branch() does the grouping. It is the same function
# watch.py's decide() uses to pick each reported version's template
# conf, so the hook and the engine cannot disagree about what a branch
# is. Reporting a branch this builder does not track costs nothing:
# watch.py refuses any version whose branch has no conf switched on in
# conf/all.release.conf, and says so in the run log.
#
# stdlib only (urllib.request, re, sys, os) -- no external dependencies.

import os
import re
import sys
import urllib.request

URL = "https://download.freebsd.org/releases/VM-IMAGES/"
TIMEOUT = 60
USER_AGENT = "anyvm-org-upstream-watcher/1.0"

# Only a directory whose name ends in the literal "-RELEASE/" counts; the
# capture group is deliberately the same shape as the old shell script's
# sed pattern ([0-9][0-9.]*), so a snapshot suffix (-BETA1, -RC1, -ALPHA1)
# never matches.
PATTERN = re.compile(r'href="(\d[\d.]*)-RELEASE/"')


def resolve_gendata():
    """Return base-builder's gendata module, or fail loudly.

    watch.yml clones base-builder INTO the builder repo root, so at
    detection time it sits at "base-builder/" (relative to this hook's
    cwd, the builder repo root). A local checkout instead has it as a
    sibling, "../base-builder". Try both, in that order.

    There is deliberately NO local fallback copy of natural_key or
    branch_key. Ordering and branch grouping must be the single rule the
    engine uses -- a per-hook duplicate would have to be kept in sync by
    hand across every builder and would drift silently, and a hook that
    ranks or groups versions differently from watch.py is worse than one
    that refuses to run. Both real contexts (CI and a local sibling
    checkout) always provide base-builder, so an ImportError here means
    the environment is wrong: report it as broken detection rather than
    guessing an order.
    """
    for candidate in ("base-builder", os.path.join("..", "base-builder")):
        if not os.path.isdir(candidate):
            continue
        path = os.path.abspath(candidate)
        if path not in sys.path:
            sys.path.insert(0, path)
        try:
            import gendata
            return gendata
        except ImportError:
            continue
    raise ImportError(
        "base-builder/gendata.py not importable from %s; expected it at "
        "./base-builder (CI) or ../base-builder (local checkout)"
        % os.getcwd())


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", "replace")


def main():
    try:
        gendata = resolve_gendata()
    except ImportError as e:
        sys.stderr.write("upstream_check: %s\n" % e)
        return 1
    try:
        html = fetch(URL)
    except Exception as e:
        sys.stderr.write("upstream_check: fetch of %s failed: %s\n"
                         % (URL, e))
        return 1
    versions = PATTERN.findall(html)
    if not versions:
        sys.stderr.write("upstream_check: no -RELEASE directory found in "
                         "%s; page shape may have changed\n" % URL)
        return 1
    for version in gendata.newest_per_branch(set(versions)):
        print(version)
    return 0


if __name__ == "__main__":
    sys.exit(main())
